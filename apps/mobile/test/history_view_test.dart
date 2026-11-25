import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seriq_mobile/models/session.dart';
import 'package:seriq_mobile/services/accounts.dart';
import 'package:seriq_mobile/services/auth.dart';
import 'package:seriq_mobile/services/history_storage.dart';
import 'package:seriq_mobile/services/history_view.dart';
import 'package:seriq_mobile/services/server_history.dart';
import 'package:seriq_mobile/services/sync_runtime.dart';

// example — пример ответа из docs/api-examples
String example(String name) =>
    File('../../docs/api-examples/$name').readAsStringSync();

// attempt — настоящее повторение
Attempt attempt(String id, {String source = 'model'}) => Attempt(
  analysisId: id,
  at: DateTime.utc(2026, 11, 25, 8, 42),
  verdict: 'completed',
  label: 'complete',
  confidence: 0.9,
  source: source,
);

// session — занятие с владельцем
Session session(String id, {String? owner, bool? synced, String source = 'model', int day = 25}) =>
    Session(
      id: id,
      startedAt: DateTime.utc(2026, 11, day, 8),
      attempts: [attempt('$id-a', source: source)],
      owner: owner,
      synced: synced,
    );

void main() {
  late bool online;
  late List<String> log;
  late Map<String, http.Response Function(http.Request)> routes;
  late HistoryStorage storage;
  late AuthService auth;
  late AccountsAvailability available;
  late HistoryView view;

  // build — вид истории с подставным сервером; signedIn — выполнен ли вход
  Future<void> build({bool signedIn = true, bool? accounts = true}) async {
    log = [];
    online = true;
    routes = {
      'POST /auth/login': (_) => http.Response(
        jsonEncode({
          'user': {'id': 'u1', 'login': 'anna_k', 'created_at': '2026-11-25T08:30:12Z'},
          'access_token': 'a1',
          'refresh_token': 'r1',
          'expires_in': 900,
        }),
        200,
      ),
      'PUT /sessions/own1': (_) => http.Response('{}', 200),
      'PUT /sessions/own2': (_) => http.Response('{}', 200),
    };
    auth = AuthService(
      baseUrl: 'https://example.com/api/v1',
      client: MockClient((req) async {
        final key = '${req.method} ${req.url.path.replaceFirst('/api/v1', '')}';
        log.add(key);
        if (!online && key != 'POST /auth/login') throw Exception('offline');
        final r = routes[key];
        return r == null
            ? http.Response('{"status":"error","error":{"code":"not_found"}}', 404)
            : r(req);
      }),
      store: MemoryTokenStore(),
    );
    storage = HistoryStorage();
    final server = ServerHistory(auth);
    final sync = SyncRuntime(auth, server, storage);
    available = AccountsAvailability(() async => accounts);
    await available.refresh();
    view = HistoryView(auth, available, storage, server, sync);
    if (signedIn) await auth.signIn('login', 'anna_k', 'correct horse battery');
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('гость: только гостевые занятия, чужие и аккаунтные скрыты, сети нет', () async {
    await build(signedIn: false);
    await storage.saveSession(session('g'));
    await storage.saveSession(session('mine', owner: 'u1', synced: true));
    final r = await view.list();
    expect(r.items!.map((s) => s.id), ['g']);
    expect(log, isEmpty);
    expect((await view.detail('mine')).session, isNull);
    expect((await view.detail('g')).session, isNotNull);
  });

  test('аккаунты выключены на сервере: даже вошедший работает как гость', () async {
    await build(accounts: false);
    await storage.saveSession(session('g'));
    expect(view.mode.kind, AccountModeKind.guest);
    expect((await view.list()).items!.map((s) => s.id), ['g']);
  });

  test('вошедший: список с сервера плюс ещё не отправленные занятия', () async {
    await build();
    routes['GET /sessions'] = (_) => http.Response(example('sessions-list.json'), 200);
    await storage.saveSession(session('g'));
    await storage.saveSession(session('own1', owner: 'u1', synced: false, day: 26));
    routes['PUT /sessions/own1'] = (_) => throw Exception('offline-put');
    final r = await view.list();
    final ids = r.items!.map((s) => s.id).toList();
    expect(ids, contains('own1'));
    expect(ids, isNot(contains('g')));
    expect(r.items!.length, greaterThan(1));
    expect(r.offline, isFalse);
    expect(r.items!.first.id, 'own1');
  });

  test('вошедший без связи: занятия аккаунта с устройства и пометка «нет связи»', () async {
    await build();
    await storage.saveSession(session('own1', owner: 'u1', synced: true));
    await storage.saveSession(session('g'));
    online = false;
    final r = await view.list();
    expect(r.items!.map((s) => s.id), ['own1']);
    expect(r.offline, isTrue);
  });

  test('сводка вошедшего: с сервера, а без него — копия на устройстве', () async {
    await build();
    routes['GET /sessions/s1'] = (_) => http.Response(example('session.json'), 200);
    final remote = await view.detail('s1');
    expect(remote.session, isNotNull);
    expect(remote.offline, isFalse);

    await storage.saveSession(session('own2', owner: 'u1', synced: true));
    online = false;
    final local = await view.detail('own2');
    expect(local.session!.id, 'own2');
    expect(local.offline, isTrue);
    expect((await view.detail('нет')).session, isNull);
  });

  test('счёт вошедшего с сервера; при ошибке — данные устройства и признак failed', () async {
    await build();
    routes['GET /progress/summary'] = (_) => http.Response(example('progress-summary.json'), 200);
    final ok = await view.progress('E02');
    expect(ok.failed, isFalse);
    expect(ok.summary.repetitions, greaterThan(0));

    await storage.saveSession(session('own1', owner: 'u1', synced: true));
    await storage.saveSession(session('g'));
    online = false;
    final bad = await view.progress(null);
    expect(bad.failed, isTrue);
    expect(bad.summary.repetitions, 1);
  });

  test('счёт гостя считается на устройстве и не включает занятия аккаунта', () async {
    await build(signedIn: false);
    await storage.saveSession(session('g'));
    await storage.saveSession(session('mine', owner: 'u1', synced: true));
    final r = await view.progress(null);
    expect(r.failed, isFalse);
    expect(r.summary.repetitions, 1);
    expect(log, isEmpty);
  });

  test('удаление занятия вошедшего: на сервере и на устройстве; очистка — только его занятия', () async {
    await build();
    routes['DELETE /sessions/own1'] = (_) => http.Response('', 204);
    routes['DELETE /sessions'] = (_) => http.Response('', 204);
    await storage.saveSession(session('own1', owner: 'u1', synced: true));
    await storage.saveSession(session('own2', owner: 'u1', synced: true));
    await storage.saveSession(session('g'));
    await view.removeOne('own1');
    expect(log, contains('DELETE /sessions/own1'));
    expect((await storage.loadSessions()).map((s) => s.id).toSet(), {'own2', 'g'});

    await view.removeAll();
    expect(log, contains('DELETE /sessions'));
    expect((await storage.loadSessions()).map((s) => s.id), ['g']);
  });

  test('удаление не удалось на сервере: занятие на устройстве остаётся', () async {
    await build();
    await storage.saveSession(session('own1', owner: 'u1', synced: true));
    online = false;
    await expectLater(view.removeOne('own1'), throwsA(isA<AccountError>()));
    expect((await storage.loadSession('own1')), isNotNull);
  });

  test('очистка гостя убирает только гостевые занятия', () async {
    await build(signedIn: false);
    await storage.saveSession(session('g'));
    await storage.saveSession(session('mine', owner: 'u1', synced: true));
    await view.removeAll();
    expect((await storage.loadSessions()).map((s) => s.id), ['mine']);
    expect(log, isEmpty);
  });
}
