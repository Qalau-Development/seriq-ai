import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seriq_mobile/core/strings.dart';
import 'package:seriq_mobile/features/account/auth_screen.dart';
import 'package:seriq_mobile/features/account/profile_screen.dart';
import 'package:seriq_mobile/models/session.dart';
import 'package:seriq_mobile/services/accounts.dart';
import 'package:seriq_mobile/services/auth.dart';
import 'package:seriq_mobile/services/history_storage.dart';
import 'package:seriq_mobile/services/history_view.dart';
import 'package:seriq_mobile/services/server_history.dart';
import 'package:seriq_mobile/services/sync_runtime.dart';
import 'package:seriq_mobile/widgets/bottom_nav.dart';
import 'package:seriq_mobile/widgets/migrate_prompt.dart';

// Env — подставной сервер аккаунтов и сервисы приложения
class Env {
  final routes = <String, http.Response Function(http.Request)>{};
  final log = <String>[];
  final bodies = <String, Object?>{};
  late final AuthService auth;
  late final HistoryStorage storage;
  late final SyncRuntime sync;
  late final HistoryView view;
  late final AccountsAvailability available;

  Env({bool? accounts = true}) {
    routes['POST /auth/login'] = (_) => loggedIn();
    routes['POST /auth/register'] = (_) => loggedIn(201);
    routes['POST /auth/logout'] = (_) => http.Response('', 204);
    auth = AuthService(
      baseUrl: 'https://example.com/api/v1',
      client: MockClient((req) async {
        final key = '${req.method} ${req.url.path.replaceFirst('/api/v1', '')}';
        log.add(key);
        bodies[key] = req.body.isEmpty ? null : jsonDecode(req.body);
        final r = routes[key];
        return r == null
            ? http.Response('{"status":"error","error":{"code":"not_found"}}', 404)
            : r(req);
      }),
      store: MemoryTokenStore(),
    );
    storage = HistoryStorage();
    final server = ServerHistory(auth);
    sync = SyncRuntime(auth, server, storage);
    available = AccountsAvailability(() async => accounts);
    view = HistoryView(auth, available, storage, server, sync);
  }

  // loggedIn — успешный ответ входа или регистрации
  static http.Response loggedIn([int status = 200]) => http.Response(
    jsonEncode({
      'user': {'id': 'u1', 'login': 'anna_k', 'created_at': '2026-11-25T08:30:12Z'},
      'access_token': 'a1',
      'refresh_token': 'r1',
      'expires_in': 900,
    }),
    status,
  );
}

// err — ответ с ошибкой в формате api.md
http.Response err(String code, int status, {Map<String, String>? headers}) =>
    http.Response(
      jsonEncode({'status': 'error', 'error': {'code': code}}),
      status,
      headers: headers ?? {},
    );

// attempt — настоящее повторение
Attempt attempt(String id, {String source = 'model'}) => Attempt(
  analysisId: id,
  at: DateTime.utc(2026, 11, 25, 8, 42),
  verdict: 'completed',
  label: 'complete',
  confidence: 0.9,
  source: source,
);

// tall — высокий экран, чтобы всё было построено
void tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

// settle — даёт завершиться подставным запросам и вводу-выводу
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
}

void main() {
  setUp(() {
    appLang.value = 'ru';
    SharedPreferences.setMockInitialValues({});
  });

  group('вход и регистрация', () {
    // pumpAuth — экран входа или регистрации с подставными сервисами
    Future<Env> pumpAuth(WidgetTester tester, {bool register = false, bool? accounts = true}) async {
      tall(tester);
      final env = Env(accounts: accounts);
      await env.available.refresh();
      await tester.pumpWidget(
        MaterialApp(
          home: AuthScreen(register: register, service: env.auth, availability: env.available),
        ),
      );
      await tester.pump();
      return env;
    }

    testWidgets('без database в /health форма не показывается, вместо неё пояснение', (tester) async {
      await pumpAuth(tester, accounts: false);
      expect(find.text(Strings.ru['auth_unavailable']!), findsOneWidget);
      expect(find.byKey(const Key('login')), findsNothing);
    });

    testWidgets('вход: кнопка неактивна, пока поля пусты; запрос уходит с логином и паролем', (tester) async {
      final env = await pumpAuth(tester);
      expect(find.text('Вход'), findsOneWidget);
      expect(find.text(Strings.ru['auth_remember_warning']!), findsNothing);
      await tester.tap(find.text('Войти').first);
      await tester.pump();
      expect(env.log, isEmpty);

      await tester.enterText(find.byKey(const Key('login')), 'anna_k');
      await tester.enterText(find.byKey(const Key('password')), 'correct horse battery');
      await tester.pump();
      await tester.tap(find.text('Войти').first);
      await settle(tester);
      expect(env.bodies['POST /auth/login'], {'login': 'anna_k', 'password': 'correct horse battery'});
      expect(env.auth.value.kind, AuthKind.signedIn);
    });

    testWidgets('регистрация: крупное предупреждение, подсказки и «Показать пароль»', (tester) async {
      await pumpAuth(tester, register: true);
      expect(find.text('Регистрация'), findsOneWidget);
      expect(find.text('Запомните пароль. Восстановить его нельзя: если забудете, придётся создать новый аккаунт.'), findsOneWidget);
      expect(find.text(Strings.ru['auth_login_rules']!), findsOneWidget);
      expect(find.text(Strings.ru['auth_password_rules']!), findsOneWidget);
      expect(find.text('Создать аккаунт'), findsOneWidget);

      TextField field(String key) => tester.widget<TextField>(find.byKey(Key(key)));
      expect(field('password').obscureText, isTrue);
      await tester.tap(find.text('Показать пароль'));
      await tester.pump();
      expect(field('password').obscureText, isFalse);
      expect(find.text('Скрыть пароль'), findsOneWidget);
    });

    testWidgets('регистрация: неверный логин и слабый пароль не уходят на сервер', (tester) async {
      final env = await pumpAuth(tester, register: true);
      await tester.enterText(find.byKey(const Key('login')), 'ab');
      await tester.enterText(find.byKey(const Key('password')), 'correct horse battery');
      await tester.pump();
      await tester.tap(find.text('Создать аккаунт'));
      await tester.pump();
      expect(find.text(Strings.ru['error_invalid_login']!), findsNWidgets(2));

      await tester.enterText(find.byKey(const Key('login')), 'anna_k');
      await tester.enterText(find.byKey(const Key('password')), 'short');
      await tester.pump();
      await tester.tap(find.text('Создать аккаунт'));
      await tester.pump();
      expect(find.text(Strings.ru['error_weak_password']!), findsWidgets);

      await tester.enterText(find.byKey(const Key('password')), 'my-anna_k-password');
      await tester.pump();
      await tester.tap(find.text('Создать аккаунт'));
      await tester.pump();
      expect(find.text(Strings.ru['error_weak_password']!), findsOneWidget);
      expect(env.log, isEmpty);
    });

    testWidgets('регистрация: логин занят, ошибка входа и ожидание из Retry-After', (tester) async {
      final env = await pumpAuth(tester, register: true);
      await tester.enterText(find.byKey(const Key('login')), 'anna_k');
      await tester.enterText(find.byKey(const Key('password')), 'correct horse battery');
      await tester.pump();

      env.routes['POST /auth/register'] = (_) => err('login_taken', 409);
      await tester.tap(find.text('Создать аккаунт'));
      await settle(tester);
      expect(find.text('Такой логин уже занят. Выберите другой.'), findsOneWidget);

      env.routes['POST /auth/register'] = (_) => err('rate_limited', 429, headers: {'retry-after': '600'});
      await tester.tap(find.text('Создать аккаунт'));
      await settle(tester);
      expect(find.text('Слишком много попыток. Попробуйте снова через 10 мин.'), findsOneWidget);
      expect(env.auth.value.kind, AuthKind.guest);
    });

    testWidgets('вход: неверные данные показываются понятным текстом, без «логин не найден»', (tester) async {
      final env = await pumpAuth(tester);
      env.routes['POST /auth/login'] = (_) => err('invalid_credentials', 401);
      await tester.enterText(find.byKey(const Key('login')), 'anna_k');
      await tester.enterText(find.byKey(const Key('password')), 'wrong password');
      await tester.pump();
      await tester.tap(find.text('Войти').first);
      await settle(tester);
      expect(find.text('Неверный логин или пароль.'), findsOneWidget);
    });

    testWidgets('вход на английском и казахском: тексты из словарей сайта', (tester) async {
      appLang.value = 'en';
      await pumpAuth(tester, register: true);
      expect(find.text(Strings.en['auth_remember_warning']!), findsOneWidget);
      expect(find.text(Strings.en['auth_register_submit']!), findsOneWidget);
    });

    testWidgets('вход истёк: над формой «Вход истёк. Войдите снова…»', (tester) async {
      final env = await pumpAuth(tester);
      env.auth.value = const AuthState(AuthKind.expired);
      await tester.pump();
      expect(find.text(Strings.ru['session_expired']!), findsOneWidget);
    });
  });

  group('профиль', () {
    // pumpProfile — профиль вошедшего пользователя
    Future<Env> pumpProfile(WidgetTester tester, {bool signedIn = true}) async {
      tall(tester);
      final env = Env();
      await env.available.refresh();
      if (signedIn) await env.auth.signIn('login', 'anna_k', 'correct horse battery');
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileScreen(service: env.auth, availability: env.available, sync: env.sync),
        ),
      );
      await tester.pump();
      return env;
    }

    testWidgets('логин, пояснение о хранимом и ссылка на приватность', (tester) async {
      await pumpProfile(tester);
      expect(find.text('Профиль'), findsWidgets);
      expect(find.text('anna_k'), findsOneWidget);
      expect(find.text(Strings.ru['profile_stored_note']!), findsOneWidget);
      expect(find.text('Данные и приватность'), findsWidgets);
    });

    testWidgets('не вошёл: пояснение и кнопка «Войти»', (tester) async {
      await pumpProfile(tester, signedIn: false);
      expect(find.text(Strings.ru['profile_not_logged']!), findsOneWidget);
      expect(find.text('Войти'), findsWidgets);
    });

    testWidgets('выход: сервер отзывает токен, вход сбрасывается', (tester) async {
      final env = await pumpProfile(tester);
      await tester.tap(find.text('Выйти'));
      await settle(tester);
      expect(env.log, contains('POST /auth/logout'));
      expect(env.auth.value.kind, AuthKind.guest);
    });

    testWidgets('удаление аккаунта: подтверждение паролем, неверный пароль — ошибка', (tester) async {
      final env = await pumpProfile(tester);
      await tester.tap(find.text('Удалить аккаунт и данные'));
      await tester.pump();
      expect(find.text(Strings.ru['profile_delete_warning']!), findsOneWidget);
      final yes = find.text('Да, удалить аккаунт');
      expect(tester.widget<Text>(yes).data, isNotNull);

      env.routes['DELETE /me'] = (_) => err('invalid_credentials', 403);
      await tester.enterText(find.byKey(const Key('delete-password')), 'wrong');
      await tester.pump();
      await tester.tap(yes);
      await settle(tester);
      expect(find.text('Неверный логин или пароль.'), findsOneWidget);
      expect(env.auth.value.kind, AuthKind.signedIn);

      env.routes['DELETE /me'] = (_) => http.Response('', 204);
      await tester.enterText(find.byKey(const Key('delete-password')), 'correct horse battery');
      await tester.pump();
      await tester.tap(yes);
      await settle(tester);
      expect(env.bodies['DELETE /me'], {'password': 'correct horse battery'});
      expect(env.auth.value.kind, AuthKind.guest);
    });

    testWidgets('отмена удаления прячет форму', (tester) async {
      await pumpProfile(tester);
      await tester.tap(find.text('Удалить аккаунт и данные'));
      await tester.pump();
      await tester.tap(find.text('Отмена'));
      await tester.pump();
      expect(find.text(Strings.ru['profile_delete_warning']!), findsNothing);
    });
  });

  group('перенос гостевой истории', () {
    // pumpPrompt — баннер переноса для вошедшего с гостевой историей
    Future<Env> pumpPrompt(WidgetTester tester, List<Session> guests) async {
      tall(tester);
      final env = Env();
      await env.available.refresh();
      await env.auth.signIn('login', 'anna_k', 'correct horse battery');
      for (final s in guests) {
        await env.storage.saveSession(s);
      }
      env.routes['PUT /sessions/g1'] = (_) => http.Response('{}', 200);
      env.routes['PUT /sessions/g2'] = (_) => http.Response('{}', 200);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: MigratePrompt(view: env.view)))));
      await settle(tester);
      return env;
    }

    // guest — гостевое занятие
    Session guest(String id, {String source = 'model'}) => Session(
      id: id,
      startedAt: DateTime.utc(2026, 11, 24, 8),
      attempts: [attempt('$id-a', source: source)],
    );

    testWidgets('вопрос и число занятий; mock не считается', (tester) async {
      await pumpPrompt(tester, [guest('g1'), guest('g2'), guest('m', source: 'mock')]);
      expect(find.text(Strings.ru['migrate_question']!), findsOneWidget);
      expect(find.text(Strings.ru['migrate_note']!), findsOneWidget);
      expect(find.text('Занятий для переноса: 2.'), findsOneWidget);
    });

    testWidgets('«Перенести»: итог и отправка настоящих повторений', (tester) async {
      final env = await pumpPrompt(tester, [guest('g1'), guest('g2')]);
      await tester.tap(find.text('Перенести'));
      await settle(tester);
      expect(find.text('Перенесено занятий: 2.'), findsOneWidget);
      expect(env.log.where((l) => l.startsWith('PUT /sessions')).length, 2);
      await tester.tap(find.text('OK'));
      await tester.pump();
      expect(find.text('Перенесено занятий: 2.'), findsNothing);
    });

    testWidgets('«Не переносить»: баннер исчезает и не возвращается для этого аккаунта', (tester) async {
      final env = await pumpPrompt(tester, [guest('g1')]);
      await tester.tap(find.text('Не переносить'));
      await settle(tester);
      expect(find.text(Strings.ru['migrate_question']!), findsNothing);
      expect(await env.sync.isMigrationDeclined('u1'), isTrue);
      expect(env.log.where((l) => l.startsWith('PUT')), isEmpty);
    });

    testWidgets('нет настоящей гостевой истории или гость: баннера нет', (tester) async {
      await pumpPrompt(tester, [guest('m', source: 'mock')]);
      expect(find.text(Strings.ru['migrate_question']!), findsNothing);

      tall(tester);
      final env = Env();
      await env.available.refresh();
      await env.storage.saveSession(guest('g1'));
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: MigratePrompt(view: env.view))));
      await settle(tester);
      expect(find.text(Strings.ru['migrate_question']!), findsNothing);
    });
  });

  group('нижняя панель', () {
    // pumpNav — нижняя панель при заданных доступности аккаунтов и входе
    Future<void> pumpNav(WidgetTester tester, {bool? accounts, bool signedIn = false}) async {
      final env = Env(accounts: accounts);
      await env.available.refresh();
      expect(activeTabs().length, 3, reason: 'панель до подключения сервиса');
      if (signedIn) await env.auth.signIn('login', 'anna_k', 'correct horse battery');
    }

    test('панель без аккаунтов — три раздела', () async {
      expect(accountsOn(false, false), isFalse);
      expect(accountsOn(true, false), isTrue);
    });

    testWidgets('«Войти» у гостя при включённых аккаунтах, «Профиль» у вошедшего, без database ничего', (tester) async {
      await pumpNav(tester);
      accountsAvailable.value = true;
      auth.value = AuthState.guest;
      await tester.pumpWidget(const MaterialApp(home: Scaffold(bottomNavigationBar: BottomNav())));
      await tester.pump();
      expect(find.text('Главная'), findsOneWidget);
      expect(find.text('История'), findsOneWidget);
      expect(find.text('Мой прогресс'), findsOneWidget);
      expect(find.text('Войти'), findsOneWidget);

      auth.value = const AuthState(AuthKind.signedIn, AuthUser('u1', 'anna_k', ''));
      await tester.pump();
      expect(find.text('Профиль'), findsOneWidget);
      expect(find.text('Войти'), findsNothing);

      auth.value = const AuthState(AuthKind.restoring);
      await tester.pump();
      expect(find.text('Профиль'), findsNothing);
      expect(find.text('Войти'), findsNothing);

      auth.value = AuthState.guest;
      accountsAvailable.value = false;
      await tester.pump();
      expect(find.text('Войти'), findsNothing);
      expect(find.text('Мой прогресс'), findsOneWidget);
      accountsAvailable.value = null;
    });
  });
}
