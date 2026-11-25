import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seriq_mobile/core/exercises.dart';
import 'package:seriq_mobile/core/strings.dart';
import 'package:seriq_mobile/features/session/session_screen.dart';
import 'package:seriq_mobile/services/api_client.dart';
import 'package:seriq_mobile/services/accounts.dart';
import 'package:seriq_mobile/services/auth.dart';
import 'package:seriq_mobile/services/catalog.dart';
import 'package:seriq_mobile/services/history_storage.dart';
import 'package:seriq_mobile/services/history_view.dart';
import 'package:seriq_mobile/services/server_history.dart';
import 'package:seriq_mobile/services/sync_runtime.dart';
import 'package:seriq_mobile/widgets/attempt_tile.dart';

// example — пример ответа API из docs/api-examples
Map<String, dynamic> example(String name) =>
    jsonDecode(File('../../docs/api-examples/$name').readAsStringSync())
        as Map<String, dynamic>;

// videoFile — временный файл видео с нужным расширением
XFile videoFile(String ext) {
  final dir = Directory.systemTemp.createTempSync('seriq_session');
  final f = File('${dir.path}/video$ext')..writeAsBytesSync([1, 2, 3, 4]);
  return XFile(f.path);
}

// pumpSession — экран занятия с подставным сервером и выбором файла
Future<void> pumpSession(
  WidgetTester tester, {
  required Future<http.Response> Function(http.BaseRequest) server,
  String exercise = 'E02',
  String ext = '.mp4',
  bool tooShort = false,
}) async {
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: SessionScreen(
        exercise: exercise,
        api: ApiClient(
          baseUrl: 'https://example.com/api/v1',
          client: MockClient.streaming((req, body) async {
            await body.drain<void>();
            final r = await server(req);
            return http.StreamedResponse(
              Stream.value(r.bodyBytes),
              r.statusCode,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
        pick: (_) async => videoFile(ext),
        tooShort: (_) async => tooShort,
      ),
    ),
  );
  await tester.pump();
}

// settleIo — даёт завершиться настоящему вводу-выводу файла и ответу подставного сервера
Future<void> settleIo(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 10));
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    appLang.value = 'ru';
    catalog.value = null;
  });

  testWidgets('ожидание: кнопки записи и загрузки, напоминание и форматы', (tester) async {
    await pumpSession(tester, server: (_) async => http.Response('{}', 500));
    expect(find.text('Занятие'), findsOneWidget);
    expect(find.text('Разгибание локтя'), findsOneWidget);
    expect(find.text(Strings.ru['session_hint']!), findsOneWidget);
    expect(find.text(Strings.ru['session_reminder']!), findsOneWidget);
    expect(find.text('Записать с камеры'), findsOneWidget);
    expect(find.text('Загрузить видео'), findsOneWidget);
    expect(find.text(Strings.ru['upload_formats']!), findsOneWidget);
  });

  testWidgets('анализ: через 15 секунд «Сервер занят», затем результат', (tester) async {
    final answer = Completer<http.Response>();
    await pumpSession(tester, server: (_) => answer.future);
    await tester.tap(find.text('Загрузить видео'));
    await tester.pump();
    await settleIo(tester);
    expect(find.text('Анализируем движение…'), findsOneWidget);
    expect(find.text(Strings.ru['analyzing_hint']!), findsOneWidget);
    expect(find.text('Сервер занят, подождите ещё немного.'), findsNothing);

    await tester.pump(const Duration(seconds: 14));
    expect(find.text('Сервер занят, подождите ещё немного.'), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Сервер занят, подождите ещё немного.'), findsOneWidget);

    answer.complete(http.Response(jsonEncode(example('analysis-complete.json')), 200));
    await settleIo(tester);
    await settleIo(tester);
    expect(find.text('Анализируем движение…'), findsNothing);
    expect(find.text(Strings.ru['mock_badge']!), findsOneWidget);
    expect(find.text('Ещё повторение'), findsOneWidget);
    expect(find.text('Повторения этого занятия'), findsOneWidget);
    expect(find.text('Завершить занятие'), findsOneWidget);
  });

  testWidgets('E04: упражнение уходит на сервер, результат по measure, в списке повторение', (tester) async {
    catalog.value = [
      for (final id in ['E01', 'E02', 'E03', 'E04'])
        CatalogEntry(id: id, measureName: 'x', measureUnit: 'deg', ready: true),
    ];
    final json = example('analysis-complete.json')
      ..['exercise'] = 'E04'
      ..['source'] = 'model'
      ..remove('angle_series')
      ..['measure'] = {
        'name': 'hand_openness',
        'unit': 'percent',
        'value': 179.0,
        'series': {'fps': 10, 'values': [100.0, 150.0, 179.0]},
      };
    (json['pose'] as Map<String, dynamic>).remove('elbow');
    String? sent;
    await pumpSession(
      tester,
      exercise: 'E04',
      server: (req) async {
        sent = req.url.toString();
        return http.Response(jsonEncode(json), 200);
      },
    );
    expect(find.text('Раскрытие кисти'), findsOneWidget);
    await tester.tap(find.text('Загрузить видео'));
    await tester.pump();
    await settleIo(tester);
    await settleIo(tester);
    expect(sent, 'https://example.com/api/v1/analysis');
    expect(find.text('Раскрытие кисти выросло на 79%'), findsOneWidget);
    expect(find.text('Выполнено'), findsWidgets);
    expect(find.text('Раскрытие кисти, % от начального'), findsOneWidget);
    expect(find.byType(AttemptTile), findsOneWidget);
    expect(find.text(Strings.ru['mock_badge']!), findsNothing);
  });

  testWidgets('ошибка: рука не найдена — текст, инструкция и «Попробовать снова»', (tester) async {
    await pumpSession(
      tester,
      server: (_) async => http.Response(
        jsonEncode(example('error-no-pose.json')),
        422,
      ),
    );
    await tester.tap(find.text('Загрузить видео'));
    await tester.pump();
    await settleIo(tester);
    await settleIo(tester);
    expect(find.text(Strings.ru['error_no_pose_detected']!), findsOneWidget);
    expect(find.text('Посмотреть инструкцию'), findsOneWidget);
    expect(find.text('Попробовать снова'), findsOneWidget);
    expect(find.byType(AttemptTile), findsNothing);

    await tester.tap(find.text('Попробовать снова'));
    await tester.pump();
    expect(find.text('Записать с камеры'), findsOneWidget);
  });

  testWidgets('неподходящий формат: ошибка без обращения к серверу', (tester) async {
    var called = false;
    await pumpSession(
      tester,
      ext: '.avi',
      server: (_) async {
        called = true;
        return http.Response('{}', 500);
      },
    );
    await tester.tap(find.text('Загрузить видео'));
    await tester.pump();
    await settleIo(tester);
    expect(find.text(Strings.ru['error_unsupported_format']!), findsOneWidget);
    expect(called, isFalse);
  });

  testWidgets('короткое видео: с камеры и из файла разные тексты, на сервер не уходит', (tester) async {
    var called = false;
    await pumpSession(
      tester,
      tooShort: true,
      server: (_) async {
        called = true;
        return http.Response('{}', 500);
      },
    );
    await tester.tap(find.text('Записать с камеры'));
    await tester.pump();
    await settleIo(tester);
    expect(find.text(Strings.ru['error_recording_too_short']!), findsOneWidget);
    expect(find.text('Посмотреть инструкцию'), findsOneWidget);
    await tester.tap(find.text('Попробовать снова'));
    await tester.pump();
    await tester.tap(find.text('Загрузить видео'));
    await tester.pump();
    await settleIo(tester);
    expect(find.text(Strings.ru['error_video_too_short']!), findsOneWidget);
    expect(called, isFalse);
  });

  testWidgets('занятие неготового упражнения: пояснение вместо записи', (tester) async {
    catalog.value = [
      for (final id in ['E01', 'E02', 'E03', 'E04'])
        CatalogEntry(id: id, measureName: 'x', measureUnit: 'deg', ready: id == 'E02'),
    ];
    await pumpSession(tester, exercise: 'E03', server: (_) async => http.Response('{}', 500));
    expect(find.text(Strings.ru['exercise_soon_hint']!), findsOneWidget);
    expect(find.text('Записать с камеры'), findsNothing);
  });

  group('вошедший пользователь', () {
    late List<String> accountLog;
    late HistoryStorage storage;
    late HistoryView previous;

    setUp(() async {
      previous = historyView;
      accountLog = [];
      final accountAuth = AuthService(
        baseUrl: 'https://example.com/api/v1',
        client: MockClient((req) async {
          final key = '${req.method} ${req.url.path.replaceFirst('/api/v1', '')}';
          accountLog.add(key);
          if (key == 'POST /auth/login') {
            return http.Response(
              jsonEncode({
                'user': {'id': 'u1', 'login': 'anna_k', 'created_at': ''},
                'access_token': 'a',
                'refresh_token': 'r',
                'expires_in': 900,
              }),
              200,
            );
          }
          return http.Response('{}', 200);
        }),
        store: MemoryTokenStore(),
      );
      await accountAuth.signIn('login', 'anna_k', 'correct horse battery');
      storage = HistoryStorage();
      final server = ServerHistory(accountAuth);
      final available = AccountsAvailability(() async => true);
      await available.refresh();
      historyView = HistoryView(
        accountAuth,
        available,
        storage,
        server,
        SyncRuntime(accountAuth, server, storage),
      );
    });

    tearDown(() => historyView = previous);

    testWidgets('настоящий результат: занятие становится занятием аккаунта и уходит на сервер', (tester) async {
      final json = example('analysis-complete.json')..['source'] = 'model';
      await pumpSession(tester, server: (_) async => http.Response(jsonEncode(json), 200));
      await tester.tap(find.text('Загрузить видео'));
      await tester.pump();
      await settleIo(tester);
      await settleIo(tester);
      expect(find.text('Ещё повторение'), findsOneWidget);
      final saved = (await tester.runAsync(storage.loadSessions))!;
      expect(saved.single.owner, 'u1');
      expect(saved.single.synced, isTrue);
      expect(accountLog.where((l) => l.startsWith('PUT /sessions/')).length, 1);
    });

    testWidgets('тестовый (mock) результат остаётся гостевым и на сервер не уходит', (tester) async {
      await pumpSession(
        tester,
        server: (_) async => http.Response(jsonEncode(example('analysis-complete.json')), 200),
      );
      await tester.tap(find.text('Загрузить видео'));
      await tester.pump();
      await settleIo(tester);
      await settleIo(tester);
      expect(find.text(Strings.ru['mock_badge']!), findsOneWidget);
      final saved = (await tester.runAsync(storage.loadSessions))!;
      expect(saved.single.owner, isNull);
      expect(accountLog.any((l) => l.startsWith('PUT')), isFalse);
    });
  });
}
