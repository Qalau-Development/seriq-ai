import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seriq_mobile/app.dart';
import 'package:seriq_mobile/core/strings.dart';
import 'package:seriq_mobile/features/progress/progress_screen.dart';
import 'package:seriq_mobile/models/analysis_result.dart';
import 'package:seriq_mobile/models/progress.dart';
import 'package:seriq_mobile/models/session.dart';
import 'package:seriq_mobile/services/history_storage.dart';
import 'package:seriq_mobile/widgets/measure_bars.dart';

// at — момент попытки
DateTime at(int day, [int hour = 10, int minute = 0]) =>
    DateTime.utc(2026, 11, day, hour, minute);

// attempt — попытка с меткой, временем и значением
Attempt attempt(String id, String label, DateTime t, {double? value}) => Attempt(
  analysisId: id,
  at: t,
  verdict: label == 'complete' ? 'completed' : 'check_instructions',
  label: label,
  confidence: 0.9,
  source: 'model',
  measure: value == null
      ? null
      : Measure(
          name: 'hand_openness',
          unit: 'percent',
          value: value,
          series: Series(fps: 10, values: [value]),
        ),
);

// sessions — занятия для проверки счёта
List<Session> sessions() => [
  Session(
    id: 'a',
    exercise: 'E04',
    startedAt: at(24),
    attempts: [
      attempt('1', 'complete', at(24), value: 179),
      attempt('2', 'incomplete', at(24, 10, 5), value: 150),
    ],
  ),
  Session(
    id: 'b',
    exercise: 'E02',
    startedAt: at(25),
    attempts: [attempt('3', 'uncertain', at(25))],
  ),
  Session(id: 'empty', startedAt: at(25, 12)),
];

final now = DateTime.utc(2026, 11, 25, 12);

void main() {
  setUp(() {
    appLang.value = 'ru';
    SharedPreferences.setMockInitialValues({});
  });

  test('счёт по всем упражнениям: занятия, исходы, доли, дни, без значений', () {
    final p = computeProgress(sessions(), null, 0, now);
    expect(p.sessions, 2);
    expect(p.repetitions, 3);
    expect(p.labels, {'complete': 1, 'incomplete': 1, 'uncertain': 1});
    expect(p.shares!['complete'], 0.3333);
    expect(p.activity.map((a) => (a.date, a.sessions, a.repetitions)), [
      ('2026-11-24', 1, 2),
      ('2026-11-25', 1, 1),
    ]);
    expect(p.measure, isNull);
    expect(p.points, isEmpty);
  });

  test('счёт по упражнению: измеренные значения по времени', () {
    final p = computeProgress(sessions(), 'E04', 0, now);
    expect(p.sessions, 1);
    expect(p.repetitions, 2);
    expect(p.measure, (name: 'hand_openness', unit: 'percent'));
    expect(p.points.map((e) => e.value), [179, 150]);
    expect(p.points.map((e) => e.label), ['complete', 'incomplete']);
  });

  test('пустая история: нули и доли null', () {
    final p = computeProgress([], null, 0, now);
    expect(p.repetitions, 0);
    expect(p.shares, isNull);
    expect(p.activity, isEmpty);
  });

  test('границы дней берутся в часовом поясе: UTC+5 переносит позднюю попытку на следующий день', () {
    final s = [
      Session(
        id: 'z',
        startedAt: at(24, 20),
        attempts: [attempt('9', 'complete', at(24, 20))],
      ),
    ];
    expect(computeProgress(s, null, 0, now).activity.single.date, '2026-11-24');
    expect(computeProgress(s, null, 300, now).activity.single.date, '2026-11-25');
  });

  test('в активности только последние 90 дней, в значениях не больше 100', () {
    final old = Session(
      id: 'old',
      startedAt: DateTime.utc(2026, 6, 1),
      attempts: [attempt('o', 'complete', DateTime.utc(2026, 6, 1))],
    );
    final many = Session(
      id: 'many',
      exercise: 'E04',
      startedAt: at(20),
      attempts: [
        for (var i = 0; i < 130; i++)
          attempt('m$i', 'complete', at(20, 8, 0).add(Duration(minutes: i)), value: i.toDouble()),
      ],
    );
    final p = computeProgress([old, many], 'E04', 0, now);
    expect(p.activity.map((a) => a.date), ['2026-11-20']);
    expect(p.points.length, 100);
    expect(p.points.first.value, 30);
    expect(p.points.last.value, 129);
    expect(computeProgress([old], null, 0, now).repetitions, 1);
    expect(computeProgress([old], null, 0, now).activity, isEmpty);
  });

  test('ответ сервера разбирается так же, как счёт на устройстве', () {
    final json = jsonDecode(
      File('../../docs/api-examples/progress-summary.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final p = ProgressSummary.fromJson(json);
    expect(p.repetitions, json['repetitions']);
    expect(p.labels['complete'], (json['labels'] as Map)['complete']);
    expect(p.measure, isNotNull);
    expect(p.points, isNotEmpty);
    expect(p.points.first.at.isUtc, isTrue);
    final empty = ProgressSummary.fromJson({'sessions': 0, 'repetitions': 0});
    expect(empty.labels, {'complete': 0, 'incomplete': 0, 'uncertain': 0});
    expect(empty.points, isEmpty);
    expect(empty.measure, isNull);
  });

  test('recentDays: 28 дней подряд до сегодняшнего включительно', () {
    final d = recentDays(28, 0, now);
    expect(d.length, 28);
    expect(d.last, '2026-11-25');
    expect(d.first, '2026-10-29');
  });

  test('значения по повторениям: до шести вертикально, остальные в строки', () {
    final a = [
      attempt('1', 'complete', at(24), value: 120),
      attempt('2', 'complete', at(24, 11), value: null),
      attempt('3', 'complete', at(24, 12), value: 140),
    ];
    final r = attemptPoints(a);
    expect(r.points.map((p) => (p.n, p.value)), [(1, 120.0), (3, 140.0)]);
    expect(r.measure, (name: 'hand_openness', unit: 'percent'));
  });

  testWidgets('экран: пусто — пояснение и кнопка, заметка «не медицинская оценка» есть всегда', (tester) async {
    tester.view.physicalSize = const Size(1080, 9000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: ProgressScreen()));
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump();
    }
    expect(find.text('Мой прогресс'), findsWidgets);
    expect(find.text(Strings.ru['progress_empty']!), findsOneWidget);
    expect(find.text(Strings.ru['progress_disclaimer']!), findsOneWidget);
    expect(find.text('Начать занятие'), findsOneWidget);
  });

  testWidgets('экран: счёт, доли, календарь и значения выбранного упражнения', (tester) async {
    tester.view.physicalSize = const Size(1080, 9000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final storage = HistoryStorage();
    final base = DateTime.now().toUtc();
    await tester.runAsync(() async {
      await storage.saveSession(
        Session(
          id: 'p1',
          exercise: 'E04',
          startedAt: base,
          attempts: [
            attempt('p1a', 'complete', base, value: 179),
            attempt('p1b', 'complete', base.add(const Duration(minutes: 1)), value: 150),
            attempt('p1c', 'incomplete', base.add(const Duration(minutes: 2)), value: 120),
          ],
        ),
      );
    });
    await tester.pumpWidget(const MaterialApp(home: ProgressScreen()));
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump();
    }
    expect(find.text('Сделано повторений: 3'), findsOneWidget);
    expect(find.text('Занятий'), findsOneWidget);
    expect(find.text('Повторений'), findsOneWidget);
    expect(find.text('Как закончились повторения'), findsOneWidget);
    expect(find.text('· 67%'), findsOneWidget);
    expect(find.text('Не до конца'), findsOneWidget);
    expect(find.text('Дни с занятиями'), findsOneWidget);
    expect(find.text(Strings.ru['progress_choose_exercise']!), findsOneWidget);
    expect(find.text('Измеренное по повторениям'), findsNothing);

    await tester.tap(find.text('Раскрытие кисти'));
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump();
    }
    expect(find.text('Измеренное по повторениям'), findsOneWidget);
    expect(find.text('Проверьте инструкцию'), findsOneWidget);
    expect(find.text(Strings.ru['progress_choose_exercise']!), findsNothing);
  });

  testWidgets('нижняя панель ведёт в «Мой прогресс»', (tester) async {
    await tester.pumpWidget(const SeriqApp());
    await tester.pump();
    await tester.tap(find.text('Мой прогресс').last);
    await tester.pumpAndSettle();
    expect(find.text(Strings.ru['progress_disclaimer']!), findsWidgets);
  });
}
