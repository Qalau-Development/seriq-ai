import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seriq_mobile/models/analysis_result.dart';
import 'package:seriq_mobile/models/session.dart';
import 'package:seriq_mobile/services/auth.dart';
import 'package:seriq_mobile/services/history_storage.dart';
import 'package:seriq_mobile/services/server_history.dart';
import 'package:seriq_mobile/services/sync.dart';
import 'package:seriq_mobile/services/sync_runtime.dart';

// attempt — попытка с источником и значением
Attempt attempt(String id, {String source = 'model', String label = 'complete'}) =>
    Attempt(
      analysisId: id,
      at: DateTime.utc(2026, 11, 25, 8, 42),
      verdict: label == 'complete' ? 'completed' : 'check_instructions',
      label: label,
      confidence: 0.87,
      source: source,
      modelVersion: source == 'model' ? 'e02-logreg2-1' : null,
      measure: Measure(
        name: 'elbow_angle',
        unit: 'deg',
        value: 166.2,
        series: Series(fps: 10, values: [62.5, null, 166.2]),
      ),
    );

// session — занятие с попытками, владельцем и отметкой отправки
Session session(
  String id,
  List<Attempt> attempts, {
  String? owner,
  bool? synced,
  String? failed,
}) => Session(
  id: id,
  startedAt: DateTime.utc(2026, 11, 25, 8, 41, 3),
  attempts: attempts,
  owner: owner,
  synced: synced,
  syncFailed: failed,
);

int ids = 0;

// newId — предсказуемые id для проверки разбиения
String newId() => 'new-${++ids}';

void main() {
  setUp(() {
    ids = 0;
    SharedPreferences.setMockInitialValues({});
  });

  group('чистая логика', () {
    test('тело PUT: формат контракта, mock-повторения не попадают, у старых записей unknown', () {
      final old = Attempt(
        analysisId: 'old',
        at: DateTime.utc(2026, 11, 25, 8, 42),
        verdict: 'completed',
        label: 'complete',
        confidence: 0.8,
        source: 'model',
      );
      final body = toServerBody(session('s', [attempt('a'), attempt('m', source: 'mock'), old]));
      expect(body['exercise'], 'E02');
      expect(body['started_at'], '2026-11-25T08:41:03Z');
      final list = body['attempts'] as List;
      expect(list.length, 2);
      expect(list[0], {
        'analysis_id': 'a',
        'at': '2026-11-25T08:42:00Z',
        'source': 'model',
        'model_version': 'e02-logreg2-1',
        'verdict': 'completed',
        'label': 'complete',
        'confidence': 0.87,
        'measure': {
          'name': 'elbow_angle',
          'unit': 'deg',
          'value': 166.2,
          'series': {'fps': 10.0, 'values': [62.5, null, 166.2]},
        },
      });
      expect((list[1] as Map)['model_version'], 'unknown');
      expect((list[1] as Map).containsKey('measure'), isFalse);
      expect(jsonEncode(body).contains('pose'), isFalse);
      expect(jsonEncode(body).contains('angle_series'), isFalse);
    });

    test('к отправке: свои, не отправленные, не отклонённые, с настоящими повторениями', () {
      final all = [
        session('ok', [attempt('1')], owner: 'u', synced: false),
        session('sent', [attempt('2')], owner: 'u', synced: true),
        session('bad', [attempt('3')], owner: 'u', synced: false, failed: 'invalid_request'),
        session('mock', [attempt('4', source: 'mock')], owner: 'u', synced: false),
        session('other', [attempt('5')], owner: 'v', synced: false),
        session('guest', [attempt('6')]),
        session('new', [attempt('7')], owner: 'u'),
      ];
      expect(pendingSessions(all, 'u').map((s) => s.id), ['ok', 'new']);
    });

    test('отправка: остановка по сети, входу, лимиту и серверу; отклонённые отмечаются', () async {
      final three = [
        session('a', [attempt('1')], owner: 'u'),
        session('b', [attempt('2')], owner: 'u'),
        session('c', [attempt('3')], owner: 'u'),
      ];
      final ok = await flushPending(three, (_) async {});
      expect(ok.sent, ['a', 'b', 'c']);
      expect(ok.stopped, isNull);

      for (final (code, stop) in [
        ('network_error', 'network'),
        ('token_expired', 'auth'),
        ('invalid_token', 'auth'),
        ('refresh_reused', 'auth'),
        ('quota_exceeded', 'quota'),
        ('internal_error', 'server'),
        ('rate_limited', 'server'),
      ]) {
        final r = await flushPending(three, (s) async {
          if (s.id == 'b') throw AccountError(code);
        });
        expect(r.sent, ['a'], reason: code);
        expect(r.stopped, stop, reason: code);
      }

      final rejected = await flushPending(three, (s) async {
        if (s.id == 'b') throw AccountError('id_conflict');
      });
      expect(rejected.sent, ['a', 'c']);
      expect(rejected.dropped.map((d) => (d.id, d.code)), [('b', 'id_conflict')]);
      expect(rejected.stopped, isNull);
    });

    test('перенос: настоящие уходят в аккаунт, mock остаётся гостевым с новым id', () {
      final guests = [
        session('real', [attempt('1'), attempt('2')]),
        session('mix', [attempt('3'), attempt('4', source: 'mock')]),
        session('mock', [attempt('5', source: 'mock')]),
      ];
      expect(migratableCount(guests), 2);
      final plan = planMigration(guests, newId);
      expect(plan.migrate.map((s) => (s.id, s.attempts.length)), [('real', 2), ('mix', 1)]);
      expect(plan.migrate.expand((s) => s.attempts).every(isReal), isTrue);
      expect(plan.keepGuest.map((s) => (s.id, s.attempts.length)), [('new-1', 1), ('mock', 1)]);
      expect(plan.keepGuest.expand((s) => s.attempts).every((a) => !isReal(a)), isTrue);
    });

    test('выход: что остаётся на устройстве', () {
      final all = [
        session('pending', [attempt('1')], owner: 'u', synced: false),
        session('mockOnly', [attempt('2', source: 'mock')], owner: 'u', synced: false),
        session('sentMix', [attempt('3'), attempt('4', source: 'mock')], owner: 'u', synced: true),
        session('sent', [attempt('5')], owner: 'u', synced: true),
        session('other', [attempt('6')], owner: 'v', synced: true),
        session('guest', [attempt('7')]),
      ];
      final out = cleanupOnLogout(all, 'u', newId);
      expect(out.map((s) => s.id), ['pending', 'mockOnly', 'new-1', 'other', 'guest']);
      expect(out[0].owner, 'u');
      expect(out[1].owner, isNull);
      expect(out[1].synced, isNull);
      expect(out[2].attempts.single.source, 'mock');
      expect(out[2].owner, isNull);
    });

    test('отметки владельца и отправки хранятся в записи и читаются обратно', () {
      final s = session('x', [attempt('1')], owner: 'u', synced: false, failed: 'id_conflict');
      final back = Session.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>);
      expect((back.owner, back.synced, back.syncFailed), ('u', false, 'id_conflict'));
      final guest = Session.fromJson(session('g', [attempt('1')]).toJson());
      expect(guest.toJson().containsKey('owner'), isFalse);
      expect(guest.toJson().containsKey('synced'), isFalse);
    });
  });

  group('отправка в аккаунт', () {
    late List<String> log;
    late Map<String, Object?> bodies;
    late Map<String, http.Response Function(http.Request)> routes;
    late MemoryTokenStore store;
    late AuthService auth;
    late HistoryStorage storage;
    late SyncRuntime runtime;

    setUp(() async {
      log = [];
      bodies = {};
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
        'POST /auth/logout': (_) => http.Response('', 204),
        'DELETE /me': (_) => http.Response('', 204),
      };
      store = MemoryTokenStore();
      auth = AuthService(
        baseUrl: 'https://example.com/api/v1',
        client: MockClient((req) async {
          final key = '${req.method} ${req.url.path.replaceFirst('/api/v1', '')}';
          log.add(key);
          bodies[key] = req.body.isEmpty ? null : jsonDecode(req.body);
          final r = routes[key];
          return r == null ? http.Response('{"status":"error","error":{"code":"not_found"}}', 404) : r(req);
        }),
        store: store,
      );
      storage = HistoryStorage();
      runtime = SyncRuntime(auth, ServerHistory(auth), storage, newId: newId);
      await auth.signIn('login', 'anna_k', 'correct horse battery');
    });

    test('занятие уходит PUT /sessions/{id}, помечается отправленным; повторный проход ничего не шлёт', () async {
      routes['PUT /sessions/s1'] = (_) => http.Response('{}', 200);
      await storage.saveSession(session('s1', [attempt('a'), attempt('m', source: 'mock')], owner: 'u1', synced: false));
      await runtime.syncNow();
      expect(log.where((l) => l == 'PUT /sessions/s1').length, 1);
      final sent = bodies['PUT /sessions/s1'] as Map;
      expect((sent['attempts'] as List).length, 1);
      expect(runtime.status.value, SyncState.ok);
      expect((await storage.loadSession('s1'))!.synced, isTrue);

      await runtime.syncNow();
      expect(log.where((l) => l == 'PUT /sessions/s1').length, 1);
    });

    test('занятие из одних mock-повторений на сервер не уходит вовсе', () async {
      await storage.saveSession(session('m1', [attempt('m', source: 'mock')], owner: 'u1', synced: false));
      await runtime.syncNow();
      expect(log.any((l) => l.startsWith('PUT')), isFalse);
    });

    test('нет связи: занятие остаётся неотправленным и уходит при следующем запуске', () async {
      var online = false;
      routes['PUT /sessions/s2'] = (_) => online
          ? http.Response('{}', 200)
          : throw Exception('offline');
      await storage.saveSession(session('s2', [attempt('a')], owner: 'u1', synced: false));
      await runtime.syncNow();
      expect(runtime.status.value, SyncState.offline);
      expect((await storage.loadSession('s2'))!.synced, isFalse);

      online = true;
      await runtime.syncNow();
      expect(runtime.status.value, SyncState.ok);
      expect((await storage.loadSession('s2'))!.synced, isTrue);
    });

    test('quota_exceeded: состояние «предел», занятие остаётся и не отклоняется', () async {
      routes['PUT /sessions/q1'] = (_) => http.Response(
        '{"status":"error","error":{"code":"quota_exceeded"}}',
        413,
      );
      await storage.saveSession(session('q1', [attempt('a')], owner: 'u1', synced: false));
      await runtime.syncNow();
      expect(runtime.status.value, SyncState.quota);
      final s = (await storage.loadSession('q1'))!;
      expect(s.synced, isFalse);
      expect(s.syncFailed, isNull);
    });

    test('сервер отклонил занятие: помечено и больше не повторяется', () async {
      routes['PUT /sessions/r1'] = (_) => http.Response(
        '{"status":"error","error":{"code":"id_conflict"}}',
        409,
      );
      await storage.saveSession(session('r1', [attempt('a')], owner: 'u1', synced: false));
      await runtime.syncNow();
      expect((await storage.loadSession('r1'))!.syncFailed, 'id_conflict');
      final puts = log.where((l) => l == 'PUT /sessions/r1').length;
      await runtime.syncNow();
      expect(log.where((l) => l == 'PUT /sessions/r1').length, puts);
    });

    test('одновременные syncNow не отправляют занятие дважды', () async {
      routes['PUT /sessions/d1'] = (_) => http.Response('{}', 200);
      await storage.saveSession(session('d1', [attempt('a')], owner: 'u1', synced: false));
      await Future.wait([runtime.syncNow(), runtime.syncNow(), runtime.syncNow()]);
      expect(log.where((l) => l == 'PUT /sessions/d1').length, 1);
    });

    test('перенос гостевой истории по согласию: только настоящие, mock остаётся гостевым', () async {
      routes['PUT /sessions/g1'] = (_) => http.Response('{}', 200);
      routes['PUT /sessions/g2'] = (_) => http.Response('{}', 200);
      await storage.saveSession(session('g1', [attempt('a')]));
      await storage.saveSession(session('g2', [attempt('b'), attempt('c', source: 'mock')]));
      await storage.saveSession(session('g3', [attempt('d', source: 'mock')]));
      expect(await runtime.guestMigratableCount(), 2);

      final r = await runtime.migrateGuestSessions();
      expect((r.moved, r.left), (2, 0));
      final all = await storage.loadSessions();
      expect(all.where((s) => s.owner == 'u1').map((s) => s.id).toSet(), {'g1', 'g2'});
      expect(all.where((s) => s.owner == null).map((s) => s.attempts.single.source).toSet(), {'mock'});
      expect(all.where((s) => s.owner == null).length, 2);
      final sent = bodies['PUT /sessions/g2'] as Map;
      expect((sent['attempts'] as List).length, 1);
      expect(((sent['attempts'] as List).single as Map)['source'], 'model');
    });

    test('перенос без связи: занятия остаются за аккаунтом и считаются неотправленными', () async {
      routes['PUT /sessions/g1'] = (_) => throw Exception('offline');
      await storage.saveSession(session('g1', [attempt('a')]));
      final r = await runtime.migrateGuestSessions();
      expect((r.moved, r.left), (0, 1));
      expect((await storage.loadSession('g1'))!.owner, 'u1');
    });

    test('отказ от переноса запоминается для аккаунта', () async {
      expect(await runtime.isMigrationDeclined('u1'), isFalse);
      await runtime.declineMigration('u1');
      expect(await runtime.isMigrationDeclined('u1'), isTrue);
      expect(await runtime.isMigrationDeclined('u2'), isFalse);
    });

    test('выход: неотправленное уходит, копии сохранённого убираются, mock остаётся гостевым', () async {
      routes['PUT /sessions/p1'] = (_) => http.Response('{}', 200);
      await storage.saveSession(session('p1', [attempt('a')], owner: 'u1', synced: false));
      await storage.saveSession(session('s1', [attempt('b'), attempt('c', source: 'mock')], owner: 'u1', synced: true));
      await storage.saveSession(session('guest', [attempt('d')]));
      await runtime.logout();
      expect(log, contains('PUT /sessions/p1'));
      expect(log, contains('POST /auth/logout'));
      expect(auth.value.kind, AuthKind.guest);
      final all = await storage.loadSessions();
      expect(all.where((s) => s.owner == 'u1').length, 0);
      expect(all.any((s) => s.id == 'p1'), isFalse);
      expect(all.any((s) => s.id == 'guest'), isTrue);
      expect(all.where((s) => s.owner == null && s.attempts.any((a) => a.source == 'mock')).length, 1);
    });

    test('выход без связи: неотправленное остаётся за аккаунтом, а не пропадает', () async {
      routes['PUT /sessions/p1'] = (_) => throw Exception('offline');
      await storage.saveSession(session('p1', [attempt('a')], owner: 'u1', synced: false));
      await runtime.logout();
      expect(auth.value.kind, AuthKind.guest);
      expect((await storage.loadSession('p1'))!.owner, 'u1');
    });

    test('удаление аккаунта: копии его занятий убираются с устройства, гостевые остаются', () async {
      await storage.saveSession(session('mine', [attempt('a')], owner: 'u1', synced: true));
      await storage.saveSession(session('guest', [attempt('b')]));
      await runtime.removeAccount('correct horse battery');
      expect((await storage.loadSessions()).map((s) => s.id), ['guest']);
      expect(auth.value.kind, AuthKind.guest);
    });
  });
}
