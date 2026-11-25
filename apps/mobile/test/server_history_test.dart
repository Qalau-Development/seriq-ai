import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:seriq_mobile/services/auth.dart';
import 'package:seriq_mobile/services/server_history.dart';

// example — пример ответа из docs/api-examples
String example(String name) =>
    File('../../docs/api-examples/$name').readAsStringSync();

void main() {
  late List<String> log;
  late Map<String, http.Response Function(http.Request)> routes;
  late ServerHistory server;

  setUp(() async {
    log = [];
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
    };
    final auth = AuthService(
      baseUrl: 'https://example.com/api/v1',
      client: MockClient((req) async {
        final key = '${req.method} ${req.url.path.replaceFirst('/api/v1', '')}';
        log.add('$key?${req.url.query}');
        final r = routes[key];
        return r == null
            ? http.Response('{"status":"error","error":{"code":"not_found"}}', 404)
            : r(req);
      }),
      store: MemoryTokenStore(),
    );
    await auth.signIn('login', 'anna_k', 'correct horse battery');
    server = ServerHistory(auth);
  });

  test('список занятий: строки со сводкой, новые первыми, постраничное чтение', () async {
    var page = 0;
    routes['GET /sessions'] = (req) {
      page++;
      if (page == 1) {
        final body = jsonDecode(example('sessions-list.json')) as Map<String, dynamic>;
        body['next_cursor'] = 'abc def';
        return http.Response(jsonEncode(body), 200);
      }
      return http.Response('{"items":[],"next_cursor":null}', 200);
    };
    final items = await server.listSessions();
    expect(items, isNotEmpty);
    expect(items.first.summary.total, greaterThan(0));
    expect(log.where((l) => l.startsWith('GET /sessions')).length, 2);
    expect(log.last, contains('cursor=abc+def'));
    expect(log.firstWhere((l) => l.startsWith('GET /sessions')), contains('limit=100'));
  });

  test('занятие с повторениями; чужое или удалённое — null', () async {
    routes['GET /sessions/s1'] = (_) => http.Response(example('session.json'), 200);
    final s = (await server.getSession('s1'))!;
    expect(s.attempts, isNotEmpty);
    expect(s.synced, isTrue);
    expect(s.attempts.first.measure, isNotNull);
    expect(await server.getSession('нет'), isNull);
  });

  test('удаление занятия: нет на сервере — не ошибка', () async {
    routes['DELETE /sessions/x'] = (_) => http.Response('', 204);
    await server.deleteRemoteSession('x');
    await server.deleteRemoteSession('нет-такого');
    routes['DELETE /sessions/boom'] = (_) => http.Response(
      '{"status":"error","error":{"code":"internal_error"}}',
      500,
    );
    await expectLater(
      server.deleteRemoteSession('boom'),
      throwsA(isA<AccountError>().having((e) => e.code, 'code', 'internal_error')),
    );
  });

  test('очистка истории и счёт с фильтром и сдвигом часового пояса', () async {
    routes['DELETE /sessions'] = (_) => http.Response('', 204);
    await server.clearRemoteHistory();
    expect(log.last, startsWith('DELETE /sessions'));

    routes['GET /progress/summary'] = (_) => http.Response(example('progress-summary.json'), 200);
    final p = await server.fetchProgress('E02', 300);
    expect(p.repetitions, greaterThan(0));
    expect(log.last, contains('utc_offset_minutes=300'));
    expect(log.last, contains('exercise=E02'));
    await server.fetchProgress(null, 0);
    expect(log.last, isNot(contains('exercise=')));
  });
}
