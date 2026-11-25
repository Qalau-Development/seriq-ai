import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seriq_mobile/core/lift_stats.dart';
import 'package:seriq_mobile/core/strings.dart';
import 'package:seriq_mobile/models/analysis_result.dart';
import 'package:seriq_mobile/models/session.dart';
import 'package:seriq_mobile/services/history_storage.dart';
import 'package:seriq_mobile/widgets/lift_summary.dart';
import 'package:seriq_mobile/widgets/pose_video.dart';

// e01 — ответ E01 с заданным рядом и источником
AnalysisResult e01({List<double?>? values, String source = 'model', String id = 'cur'}) {
  final json = jsonDecode(File('../../docs/api-examples/analysis-complete.json').readAsStringSync())
      as Map<String, dynamic>;
  final v = values ?? [0.0, 0.1, 0.5, 1.2, 1.8, 2.0, 2.0];
  json['exercise'] = 'E01';
  json['source'] = source;
  json['analysis_id'] = id;
  json.remove('angle_series');
  (json['pose'] as Map<String, dynamic>).remove('elbow');
  json['measure'] = {
    'name': 'lift_height',
    'unit': 'hand_lengths',
    'value': v.whereType<double>().reduce((a, b) => a > b ? a : b),
    'series': {'fps': 10, 'values': v},
  };
  return AnalysisResult.fromJson(json);
}

// attempt — прошлая попытка E01 со значением
Attempt past(String id, double value, DateTime at, {String source = 'model', List<double?>? values}) =>
    Attempt(
      analysisId: id,
      at: at,
      verdict: 'completed',
      label: 'complete',
      confidence: 0.9,
      source: source,
      measure: Measure(
        name: 'lift_height',
        unit: 'hand_lengths',
        value: value,
        series: Series(fps: 10, values: values ?? [0, value / 2, value]),
      ),
    );

void main() {
  setUp(() {
    appLang.value = 'ru';
    SharedPreferences.setMockInitialValues({});
  });

  test('старт подъёма: среднее положение запястья в первых 10% кадров', () {
    final pose = e01().pose!;
    final start = liftStart(pose)!;
    final wrists = pose.frames.whereType<PoseFrame>().map((f) => f.wrist).toList();
    final n = (wrists.length * 0.1).round();
    final first = wrists.take(n < 1 ? 1 : n).toList();
    expect(start.dx, closeTo(first.map((p) => p.dx).reduce((a, b) => a + b) / first.length, 1e-9));
    expect(liftStart(null), isNull);
  });

  test('время подъёма: от 10% до 90% максимума', () {
    final s = Series(fps: 10, values: [0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 10]);
    expect(riseTime(s), 0.8);
    expect(riseTime(Series(fps: 10, values: [1, 1, 1])), isNull);
    expect(riseTime(Series(fps: 10, values: [null, null])), isNull);
    expect(riseTime(null), isNull);
    expect(riseTime(Series(fps: 0, values: [0, 1])), isNull);
  });

  test('сравнение: прошлая попытка, лучший результат, «это лучший»', () {
    final t0 = DateTime.utc(2026, 11, 20);
    final t1 = DateTime.utc(2026, 11, 21);
    final now = DateTime.utc(2026, 11, 25);
    final first = compareWithHistory(LiftAttempt(now, 2.0, 1.0), []);
    expect(first.previous, isNull);
    expect(first.isBest, isFalse);

    final r = compareWithHistory(
      LiftAttempt(now, 2.0, 1.0),
      [LiftAttempt(t0, 1.0, 2.0), LiftAttempt(t1, 1.6, 1.5)],
    );
    expect(r.previous!.valueDelta, 0.4);
    expect(r.previous!.riseDelta, -0.5);
    expect(r.best, 2.0);
    expect(r.isBest, isTrue);

    final worse = compareWithHistory(LiftAttempt(now, 1.2, null), [LiftAttempt(t1, 1.6, 1.5)]);
    expect(worse.previous!.valueDelta, -0.4);
    expect(worse.previous!.riseDelta, isNull);
    expect(worse.best, 1.6);
    expect(worse.isBest, isFalse);

    final later = compareWithHistory(LiftAttempt(t0, 1.0, null), [LiftAttempt(now, 2.0, null)]);
    expect(later.previous, isNull);
  });

  test('число со знаком: плюс, настоящий минус и нуль', () {
    expect(signedValue(0.4), '+0,4');
    expect(signedValue(-0.2), '−0,2');
    expect(signedValue(0), '0,0');
    appLang.value = 'en';
    expect(signedValue(0.4), '+0.4');
  });

  test('история сравнения: только E01 и того же источника, без этой попытки', () {
    final at = DateTime.utc(2026, 11, 20);
    final sessions = [
      Session(id: 'a', exercise: 'E01', startedAt: at, attempts: [past('p1', 1.0, at), past('cur', 9, at), past('m', 5, at, source: 'mock')]),
      Session(id: 'b', exercise: 'E04', startedAt: at, attempts: [past('p2', 3.0, at)]),
    ];
    final h = liftHistory(sessions, e01());
    expect(h.length, 1);
    expect(h.single.value, 1.0);
  });

  testWidgets('блок «Подъём»: время, разница с прошлой попыткой и лучший результат', (tester) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final storage = HistoryStorage();
    final earlier = DateTime.now().toUtc().subtract(const Duration(days: 1));
    await tester.runAsync(() async {
      await storage.saveSession(
        Session(id: 's0', exercise: 'E01', startedAt: earlier, attempts: [past('p1', 1.0, earlier)]),
      );
      await storage.saveSession(
        Session(id: 's1', exercise: 'E01', startedAt: DateTime.now().toUtc(), attempts: [past('cur', 2.0, DateTime.now().toUtc())]),
      );
    });
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: LiftSummary(result: e01())))));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump();
    }
    expect(find.text('Подъём'), findsOneWidget);
    expect(find.textContaining('Подъём занял'), findsOneWidget);
    expect(find.textContaining('К прошлой попытке: +1,0 длины кисти.'), findsOneWidget);
    expect(find.text(Strings.ru['lift_is_best']!), findsOneWidget);
    expect(find.text(Strings.ru['lift_line_hint']!), findsOneWidget);
    expect(find.text(Strings.ru['lift_note']!), findsOneWidget);
  });

  testWidgets('первая попытка: «сравнивать пока не с чем»; для других упражнений блока нет', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: LiftSummary(result: e01())))));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump();
    }
    expect(find.text(Strings.ru['lift_first']!), findsOneWidget);
    expect(find.text(Strings.ru['lift_is_best']!), findsNothing);

    final json = jsonDecode(File('../../docs/api-examples/analysis-complete.json').readAsStringSync()) as Map<String, dynamic>;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: LiftSummary(result: AnalysisResult.fromJson(json)))));
    await tester.pump();
    expect(find.text('Подъём'), findsNothing);
  });

  test('рисование линии подъёма не падает', () {
    final r = e01();
    final recorder = PictureRecorder();
    PosePainter.paintHand(
      Canvas(recorder),
      const Size(300, 200),
      null,
      r.pose!.frames.whereType<PoseFrame>().first.hand,
      liftStart: liftStart(r.pose),
    );
    recorder.endRecording().dispose();
  });
}
