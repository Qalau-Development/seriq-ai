import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seriq_mobile/app.dart';
import 'package:seriq_mobile/core/format.dart';
import 'package:seriq_mobile/core/strings.dart';
import 'package:seriq_mobile/features/history/history_screen.dart';
import 'package:seriq_mobile/features/summary/summary_screen.dart';
import 'package:seriq_mobile/models/analysis_result.dart';
import 'package:seriq_mobile/models/session.dart';
import 'package:seriq_mobile/services/history_storage.dart';

// attempt — попытка с меткой и значением для теста
Attempt attempt(
  String id,
  String label, {
  int minute = 1,
  double? value,
  String source = 'mock',
}) => Attempt(
  analysisId: id,
  at: DateTime.utc(2026, 11, 24, 10, minute),
  verdict: label == 'complete' ? 'completed' : 'check_instructions',
  label: label,
  confidence: label == 'uncertain' ? 0.55 : 0.9,
  source: source,
  measure: value == null
      ? null
      : Measure(
          name: 'hand_openness',
          unit: 'percent',
          value: value,
          series: Series(fps: 10, values: [100, value]),
        ),
);

// session — занятие E02 из двух попыток
Session session([String id = 's1', int day = 24]) => Session(
  id: id,
  startedAt: DateTime.utc(2026, 11, day, 10),
  attempts: [attempt('$id-a', 'complete'), attempt('$id-b', 'uncertain', minute: 2)],
);

// e04 — занятие E04 из трёх попыток со значениями
Session e04() => Session(
  id: 'e04',
  exercise: 'E04',
  startedAt: DateTime.utc(2026, 11, 25, 10),
  attempts: [
    attempt('x1', 'complete', value: 179, source: 'model'),
    attempt('x2', 'incomplete', minute: 2, value: 150, source: 'model'),
    attempt('x3', 'complete', minute: 3, value: 170, source: 'model'),
  ],
);

// tall — высокий экран, чтобы всё было построено
void tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 9000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

// settle — даёт завершиться чтению и записи хранилища
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump();
  }
}

void main() {
  setUp(() {
    appLang.value = 'ru';
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('пустая история: пояснение и кнопка начала занятия', (tester) async {
    tall(tester);
    await tester.pumpWidget(const MaterialApp(home: HistoryScreen()));
    await settle(tester);
    expect(find.text(Strings.ru['history_empty']!), findsOneWidget);
    expect(find.text('Начать занятие'), findsOneWidget);
    expect(find.text('Очистить всю историю'), findsNothing);
  });

  testWidgets('история: упражнение, дата, сводка, фильтр по упражнению', (tester) async {
    tall(tester);
    final storage = HistoryStorage();
    await tester.runAsync(() async {
      await storage.saveSession(session());
      await storage.saveSession(e04());
    });
    await tester.pumpWidget(const MaterialApp(home: HistoryScreen()));
    await settle(tester);
    expect(find.text(Strings.ru['history_local_note']!), findsOneWidget);
    expect(find.text('Выполнено 1 из 2'), findsOneWidget);
    expect(find.text('Выполнено 2 из 3'), findsOneWidget);
    expect(find.text(formatDateTime(DateTime.utc(2026, 11, 24, 10))), findsOneWidget);

    await tester.tap(find.text('Разгибание локтя').first);
    await tester.pump();
    expect(find.text('Выполнено 1 из 2'), findsOneWidget);
    expect(find.text('Выполнено 2 из 3'), findsNothing);

    await tester.tap(find.text('Подъём предмета'));
    await tester.pump();
    expect(find.text(Strings.ru['history_filter_empty']!), findsOneWidget);

    await tester.tap(find.text('Все'));
    await tester.pump();
    expect(find.text('Выполнено 2 из 3'), findsOneWidget);
  });

  testWidgets('удаление одного занятия с подтверждением и очистка всей истории', (tester) async {
    tall(tester);
    final storage = HistoryStorage();
    await tester.runAsync(() async {
      await storage.saveSession(session());
      await storage.saveSession(e04());
    });
    await tester.pumpWidget(const MaterialApp(home: HistoryScreen()));
    await settle(tester);

    await tester.tap(find.text('Удалить занятие').first);
    await tester.pump();
    expect(find.text(Strings.ru['delete_session_confirm']!), findsOneWidget);
    await tester.tap(find.text('Отмена'));
    await tester.pump();
    expect(find.text('Выполнено 2 из 3'), findsOneWidget);

    await tester.tap(find.text('Удалить занятие').first);
    await tester.pump();
    await tester.tap(find.text('Да, удалить'));
    await settle(tester);
    expect(find.text('Выполнено 2 из 3'), findsNothing);
    expect(find.text('Выполнено 1 из 2'), findsOneWidget);
    expect((await tester.runAsync(storage.loadSessions))!.length, 1);

    await tester.tap(find.text('Очистить всю историю'));
    await tester.pump();
    expect(find.text(Strings.ru['clear_history_confirm']!), findsOneWidget);
    await tester.tap(find.text('Да, удалить'));
    await settle(tester);
    expect(find.text(Strings.ru['history_empty']!), findsOneWidget);
    expect((await tester.runAsync(storage.loadSessions))!, isEmpty);
  });

  testWidgets('сводка: всего, исходы, значения, повторения и плашка мока', (tester) async {
    tall(tester);
    await tester.runAsync(() => HistoryStorage().saveSession(session()));
    await tester.pumpWidget(const MaterialApp(home: SummaryScreen(id: 's1')));
    await settle(tester);
    expect(find.text('Итоги занятия'), findsOneWidget);
    expect(find.text('Всего повторений'), findsOneWidget);
    expect(find.text('2'), findsWidgets);
    expect(find.text(Strings.ru['summary_has_mock']!), findsOneWidget);
    expect(find.text('Повторение 1 · ${formatTime(DateTime.utc(2026, 11, 24, 10, 1))}'), findsOneWidget);
    expect(find.text('Измеренное по повторениям'), findsNothing);
  });

  testWidgets('сводка E04: значения по повторениям, нейтральные подписи исходов', (tester) async {
    tall(tester);
    await tester.runAsync(() => HistoryStorage().saveSession(e04()));
    await tester.pumpWidget(const MaterialApp(home: SummaryScreen(id: 'e04')));
    await settle(tester);
    expect(find.text('Измеренное по повторениям'), findsOneWidget);
    expect(find.text('Раскрытие кисти, % от начального'), findsOneWidget);
    expect(find.text('179'), findsOneWidget);
    expect(find.text('150'), findsWidgets);
    expect(find.text(Strings.ru['summary_has_mock']!), findsNothing);
    expect(find.text('Проверьте инструкцию'), findsWidgets);
  });

  testWidgets('сводка не найдена: пояснение и кнопка «История»', (tester) async {
    tall(tester);
    await tester.pumpWidget(const MaterialApp(home: SummaryScreen(id: 'нет')));
    await settle(tester);
    expect(find.text(Strings.ru['summary_not_found']!), findsOneWidget);
    expect(find.text('История'), findsWidgets);
  });

  testWidgets('удаление занятия из сводки возвращает в историю', (tester) async {
    tall(tester);
    await tester.runAsync(() => HistoryStorage().saveSession(session()));
    await tester.pumpWidget(const SeriqApp());
    await tester.pump();
    await tester.tap(find.text('История').last);
    await settle(tester);
    await tester.tap(find.textContaining('Выполнено 1 из 2').last);
    await settle(tester);
    expect(find.text('Итоги занятия'), findsOneWidget);
    await tester.tap(find.text('Удалить занятие').last);
    await tester.pump();
    await tester.tap(find.text('Да, удалить').last);
    await settle(tester);
    await tester.pumpAndSettle();
    expect(find.text('История занятий'), findsOneWidget);
    expect(find.text(Strings.ru['history_empty']!), findsOneWidget);
  });
}
