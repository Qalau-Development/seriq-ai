import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:seriq_mobile/core/strings.dart';
import 'package:seriq_mobile/services/accounts.dart';
import 'package:seriq_mobile/services/auth.dart';

// user — пользователь из ответа сервера
const user = {'id': 'u1', 'login': 'anna_k', 'created_at': '2026-11-25T08:30:12Z'};

// tokens — ответ входа или обновления
Map<String, dynamic> tokens(int n, {bool withUser = false}) => {
  if (withUser) 'user': user,
  'access_token': 'access-$n',
  'refresh_token': 'refresh-$n',
  'expires_in': 900,
};

// err — ответ с ошибкой в формате api.md
http.Response err(String code, int status, {Map<String, String>? headers}) =>
    http.Response(
      jsonEncode({'status': 'error', 'error': {'code': code, 'message': code}}),
      status,
      headers: headers ?? {},
    );

// Fake — подставной сервер: журнал запросов и ответы по пути
class Fake {
  final log = <String>[];
  final bodies = <String, Object?>{};
  final headers = <String, String?>{};
  final Map<String, http.Response Function(http.Request)> routes = {};

  // client — клиент, отвечающий по routes
  http.Client get client => MockClient((req) async {
    final key = '${req.method} ${req.url.path.replaceFirst('/api/v1', '')}';
    log.add(key);
    bodies[key] = req.body.isEmpty ? null : jsonDecode(req.body);
    headers[key] = req.headers['Authorization'];
    final r = routes[key];
    return r == null ? err('not_found', 404) : r(req);
  });
}

void main() {
  late Fake fake;
  late MemoryTokenStore store;
  late DateTime now;
  late AuthService auth;

  setUp(() {
    appLang.value = 'ru';
    fake = Fake();
    store = MemoryTokenStore();
    now = DateTime.utc(2026, 11, 25, 9);
    auth = AuthService(
      baseUrl: 'https://example.com/api/v1',
      client: fake.client,
      store: store,
      now: () => now,
    );
  });

  test('вход: токены в хранилище, пользователь в состоянии, без заголовка X-SerIQ-Client', () async {
    fake.routes['POST /auth/login'] = (_) => http.Response(jsonEncode(tokens(1, withUser: true)), 200);
    final u = await auth.signIn('login', 'anna_k', 'correct horse battery');
    expect(u.login, 'anna_k');
    expect(auth.value.kind, AuthKind.signedIn);
    expect(auth.user!.id, 'u1');
    expect(store.values[AuthService.refreshKey], 'refresh-1');
    expect(fake.bodies['POST /auth/login'], {'login': 'anna_k', 'password': 'correct horse battery'});
  });

  test('регистрация: ответ 201', () async {
    fake.routes['POST /auth/register'] = (_) => http.Response(jsonEncode(tokens(1, withUser: true)), 201);
    await auth.signIn('register', 'anna_k', 'correct horse battery');
    expect(auth.value.kind, AuthKind.signedIn);
  });

  test('ошибки входа: код, статус и Retry-After', () async {
    fake.routes['POST /auth/login'] = (_) => err('invalid_credentials', 401);
    await expectLater(
      auth.signIn('login', 'anna_k', 'x'),
      throwsA(isA<AccountError>().having((e) => e.code, 'code', 'invalid_credentials')),
    );
    expect(auth.value.kind, AuthKind.guest);

    fake.routes['POST /auth/login'] = (_) => err('rate_limited', 429, headers: {'retry-after': '120'});
    await expectLater(
      auth.signIn('login', 'anna_k', 'x'),
      throwsA(isA<AccountError>()
          .having((e) => e.code, 'code', 'rate_limited')
          .having((e) => e.retryAfter, 'retryAfter', 120)),
    );
    fake.routes['POST /auth/register'] = (_) => err('login_taken', 409);
    await expectLater(
      auth.signIn('register', 'anna_k', 'x'),
      throwsA(isA<AccountError>().having((e) => e.code, 'code', 'login_taken')),
    );
  });

  test('нет связи — network_error', () async {
    final a = AuthService(
      baseUrl: 'https://example.com/api/v1',
      client: MockClient((_) async => throw Exception('offline')),
      store: store,
    );
    await expectLater(
      a.signIn('login', 'a', 'b'),
      throwsA(isA<AccountError>().having((e) => e.code, 'code', 'network_error')),
    );
  });

  test('время ожидания словами: секунды и минуты', () {
    expect(waitText(30), '30 с');
    expect(waitText(120), '2 мин');
    expect(waitText(61), '2 мин');
    expect(waitText(null), '1 мин');
    expect(trFill('error_rate_limited', {'time': waitText(900)}), 'Слишком много попыток. Попробуйте снова через 15 мин.');
  });

  test('запрос с Bearer; токен обновляется заранее, когда access истёк, и новый refresh сохраняется', () async {
    fake.routes['POST /auth/login'] = (_) => http.Response(jsonEncode(tokens(1, withUser: true)), 200);
    var n = 1;
    fake.routes['POST /auth/refresh'] = (_) => http.Response(jsonEncode(tokens(++n)), 200);
    fake.routes['GET /me'] = (_) => http.Response(jsonEncode(user), 200);
    await auth.signIn('login', 'anna_k', 'correct horse battery');

    await auth.authorized('GET', '/me');
    expect(fake.headers['GET /me'], 'Bearer access-1');
    expect(fake.log.where((l) => l == 'POST /auth/refresh'), isEmpty);

    now = now.add(const Duration(minutes: 15));
    await auth.authorized('GET', '/me');
    expect(fake.bodies['POST /auth/refresh'], {'refresh_token': 'refresh-1'});
    expect(fake.headers['GET /me'], 'Bearer access-2');
    expect(store.values[AuthService.refreshKey], 'refresh-2');
  });

  test('token_expired: один повтор после обновления', () async {
    fake.routes['POST /auth/login'] = (_) => http.Response(jsonEncode(tokens(1, withUser: true)), 200);
    fake.routes['POST /auth/refresh'] = (_) => http.Response(jsonEncode(tokens(2)), 200);
    var calls = 0;
    fake.routes['GET /sessions'] = (req) {
      calls++;
      return calls == 1 ? err('token_expired', 401) : http.Response('{"items":[]}', 200);
    };
    await auth.signIn('login', 'anna_k', 'correct horse battery');
    final res = await auth.authorized('GET', '/sessions');
    expect(res.statusCode, 200);
    expect(calls, 2);
    expect(fake.headers['GET /sessions'], 'Bearer access-2');
  });

  test('второй token_expired подряд — ошибка, не бесконечный повтор', () async {
    fake.routes['POST /auth/login'] = (_) => http.Response(jsonEncode(tokens(1, withUser: true)), 200);
    fake.routes['POST /auth/refresh'] = (_) => http.Response(jsonEncode(tokens(2)), 200);
    fake.routes['GET /sessions'] = (_) => err('token_expired', 401);
    await auth.signIn('login', 'anna_k', 'correct horse battery');
    await expectLater(
      auth.authorized('GET', '/sessions'),
      throwsA(isA<AccountError>().having((e) => e.code, 'code', 'token_expired')),
    );
    expect(fake.log.where((l) => l == 'GET /sessions').length, 2);
  });

  for (final code in ['invalid_token', 'refresh_reused']) {
    test('$code при обновлении: «войдите снова», токены забыты', () async {
      fake.routes['POST /auth/login'] = (_) => http.Response(jsonEncode(tokens(1, withUser: true)), 200);
      fake.routes['POST /auth/refresh'] = (_) => err(code, 401);
      await auth.signIn('login', 'anna_k', 'correct horse battery');
      now = now.add(const Duration(minutes: 20));
      await expectLater(
        auth.authorized('GET', '/me'),
        throwsA(isA<AccountError>().having((e) => e.code, 'code', code)),
      );
      expect(auth.value.kind, AuthKind.expired);
      expect(store.values.containsKey(AuthService.refreshKey), isFalse);
      expect(auth.user, isNull);
      expect(Strings.ru['error_$code'], 'Нужно войти снова.');
    });
  }

  test('одновременные запросы делают одно обновление', () async {
    fake.routes['POST /auth/login'] = (_) => http.Response(jsonEncode(tokens(1, withUser: true)), 200);
    fake.routes['POST /auth/refresh'] = (_) => http.Response(jsonEncode(tokens(2)), 200);
    fake.routes['GET /me'] = (_) => http.Response(jsonEncode(user), 200);
    await auth.signIn('login', 'anna_k', 'correct horse battery');
    now = now.add(const Duration(minutes: 20));
    await Future.wait([
      auth.authorized('GET', '/me'),
      auth.authorized('GET', '/me'),
      auth.authorized('GET', '/me'),
    ]);
    expect(fake.log.where((l) => l == 'POST /auth/refresh').length, 1);
  });

  test('выход: сервер отзывает цепочку, токены забыты', () async {
    fake.routes['POST /auth/login'] = (_) => http.Response(jsonEncode(tokens(1, withUser: true)), 200);
    fake.routes['POST /auth/logout'] = (_) => http.Response('', 204);
    await auth.signIn('login', 'anna_k', 'correct horse battery');
    await auth.signOut();
    expect(fake.bodies['POST /auth/logout'], {'refresh_token': 'refresh-1'});
    expect(auth.value.kind, AuthKind.guest);
    expect(store.values, isEmpty);
  });

  test('выход без связи всё равно выходит на устройстве', () async {
    fake.routes['POST /auth/login'] = (_) => http.Response(jsonEncode(tokens(1, withUser: true)), 200);
    await auth.signIn('login', 'anna_k', 'correct horse battery');
    final offline = AuthService(
      baseUrl: 'https://example.com/api/v1',
      client: MockClient((_) async => throw Exception('offline')),
      store: store,
    );
    await offline.signOut();
    expect(offline.value.kind, AuthKind.guest);
    expect(store.values, isEmpty);
  });

  test('удаление аккаунта: пароль в теле, затем гость', () async {
    fake.routes['POST /auth/login'] = (_) => http.Response(jsonEncode(tokens(1, withUser: true)), 200);
    fake.routes['DELETE /me'] = (_) => http.Response('', 204);
    await auth.signIn('login', 'anna_k', 'correct horse battery');
    await auth.deleteAccount('correct horse battery');
    expect(fake.bodies['DELETE /me'], {'password': 'correct horse battery'});
    expect(fake.headers['DELETE /me'], 'Bearer access-1');
    expect(auth.value.kind, AuthKind.guest);
    expect(store.values, isEmpty);
  });

  test('удаление аккаунта: неверный пароль — 403 invalid_credentials, вход остаётся', () async {
    fake.routes['POST /auth/login'] = (_) => http.Response(jsonEncode(tokens(1, withUser: true)), 200);
    fake.routes['DELETE /me'] = (_) => err('invalid_credentials', 403);
    await auth.signIn('login', 'anna_k', 'correct horse battery');
    await expectLater(
      auth.deleteAccount('нет'),
      throwsA(isA<AccountError>().having((e) => e.code, 'code', 'invalid_credentials')),
    );
    expect(auth.value.kind, AuthKind.signedIn);
  });

  test('запуск: вход восстанавливается по токену из хранилища', () async {
    store.values[AuthService.refreshKey] = 'refresh-1';
    fake.routes['POST /auth/refresh'] = (_) => http.Response(jsonEncode(tokens(2)), 200);
    fake.routes['GET /me'] = (_) => http.Response(jsonEncode(user), 200);
    await auth.restore();
    expect(auth.value.kind, AuthKind.signedIn);
    expect(auth.user!.login, 'anna_k');
    expect(store.values[AuthService.refreshKey], 'refresh-2');
  });

  test('запуск без токена: гость, запросов нет', () async {
    await auth.restore();
    expect(auth.value.kind, AuthKind.guest);
    expect(fake.log, isEmpty);
  });

  test('запуск без связи: остаётся вход с сохранённым пользователем', () async {
    store.values[AuthService.refreshKey] = 'refresh-1';
    store.values[AuthService.userKey] = jsonEncode(user);
    final offline = AuthService(
      baseUrl: 'https://example.com/api/v1',
      client: MockClient((_) async => throw Exception('offline')),
      store: store,
    );
    await offline.restore();
    expect(offline.value.kind, AuthKind.signedIn);
    expect(offline.user!.login, 'anna_k');
    expect(store.values[AuthService.refreshKey], 'refresh-1');
  });

  test('запуск: токен отозван — вход истёк', () async {
    store.values[AuthService.refreshKey] = 'refresh-1';
    fake.routes['POST /auth/refresh'] = (_) => err('invalid_token', 401);
    await auth.restore();
    expect(auth.value.kind, AuthKind.expired);
    expect(store.values, isEmpty);
  });

  test('логин и пароль: правила из api.md', () {
    expect(validLogin('anna_k'), isTrue);
    expect(validLogin('ab'), isFalse);
    expect(validLogin('a' * 33), isFalse);
    expect(validLogin('анна'), isFalse);
    expect(validLogin('a b c'), isFalse);
    expect(validLogin('a@b.kz'), isFalse);
    expect(validPassword('correct horse', 'anna_k'), isTrue);
    expect(validPassword('short', 'anna_k'), isFalse);
    expect(validPassword('x' * 129, 'anna_k'), isFalse);
    expect(validPassword('my-ANNA_K-password', 'anna_k'), isFalse);
  });

  group('доступность аккаунтов по /health', () {
    test('есть поле database — аккаунты есть, значение не важно', () {
      expect(hasDatabase({'status': 'ok', 'database': 'ok'}), isTrue);
      expect(hasDatabase({'status': 'ok', 'database': 'unavailable'}), isTrue);
      expect(hasDatabase({'status': 'ok', 'mode': 'model'}), isFalse);
      expect(hasDatabase('ok'), isFalse);
      expect(hasDatabase(null), isFalse);
    });

    test('checkAccounts: ответ сервера, ошибка и обрыв связи', () async {
      http.Client c(http.Response Function() r) => MockClient((_) async => r());
      expect(await checkAccounts(client: c(() => http.Response('{"database":"ok"}', 200))), isTrue);
      expect(await checkAccounts(client: c(() => http.Response('{"status":"ok"}', 200))), isFalse);
      expect(await checkAccounts(client: c(() => http.Response('{"database":"ok"}', 500))), isFalse);
      expect(await checkAccounts(client: c(() => http.Response('не json', 200))), isFalse);
      expect(await checkAccounts(client: MockClient((_) async => throw Exception('offline'))), isFalse);
    });

    test('AccountsAvailability: значение обновляется после проверки', () async {
      var answer = false;
      final a = AccountsAvailability(() async => answer);
      expect(a.value, isNull);
      await a.refresh();
      expect(a.value, isFalse);
      answer = true;
      await a.refresh();
      expect(a.value, isTrue);
    });
  });
}
