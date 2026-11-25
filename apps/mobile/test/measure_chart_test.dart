import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:seriq_mobile/core/strings.dart';
import 'package:seriq_mobile/models/analysis_result.dart';
import 'package:seriq_mobile/widgets/measure_chart.dart';

// measure — измеряемое значение с рядом для графика
Measure measure(String name, String unit, List<double?> values) => Measure(
  name: name,
  unit: unit,
  value: values.whereType<double>().fold<double?>(null, (a, b) => a == null || b > a ? b : a),
  series: Series(fps: 10, values: values),
);

// cycle — цикл с границами в секундах
CycleResult cycle(double start, double end) => CycleResult.fromJson({
  'index': 1,
  'start_s': start,
  'end_s': end,
  'label': 'complete',
  'confidence': 0.9,
  'verdict': 'completed',
});

// pump — график в узкой колонке, как на телефоне
Future<void> pump(WidgetTester tester, Measure m, [CycleResult? c]) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(width: 360, child: MeasureChart(measure: m, cycle: c)),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() => appLang.value = 'ru');

  testWidgets('E02: шкала 0–180 через 45, подписи времени не повторяются', (tester) async {
    final m = measure('elbow_angle', 'deg', List.generate(25, (i) => 90 + i.toDouble()));
    await pump(tester, m);
    expect(find.text('Угол локтя, ° (180° — прямая рука)'), findsOneWidget);
    for (final s in ['45', '90', '135', '180', '1', '2']) {
      expect(find.text(s), findsOneWidget, reason: s);
    }
    expect(find.text('0'), findsNWidgets(2));
    expect(find.text('Время, с'), findsOneWidget);
  });

  testWidgets('E04: подпись оси и шкала по значениям', (tester) async {
    final m = measure('hand_openness', 'percent', [100, 110, 130, 150, 179]);
    await pump(tester, m);
    expect(find.text('Раскрытие кисти, % от начального'), findsOneWidget);
    expect(find.text('Угол локтя, ° (180° — прямая рука)'), findsNothing);
  });

  testWidgets('E01: длины кисти, шкала с десятыми', (tester) async {
    final m = measure('lift_height', 'hand_lengths', [0, 0.2, 0.9, 1.4, 1.1]);
    await pump(tester, m);
    expect(find.text('Подъём кисти, длины кисти'), findsOneWidget);
  });

  testWidgets('подсказки: разрывы и выделенное повторение', (tester) async {
    final gaps = measure('wrist_lift', 'deg', List.generate(30, (i) => i == 10 ? null : i.toDouble()));
    await pump(tester, gaps, cycle(0.2, 2.9));
    expect(find.textContaining(Strings.ru['chart_gap_hint']!), findsOneWidget);
    expect(find.textContaining(Strings.ru['chart_cycle_hint']!), findsNothing);

    await pump(tester, gaps, cycle(0.9, 2.0));
    expect(find.textContaining(Strings.ru['chart_cycle_hint']!), findsOneWidget);
  });

  testWidgets('английский: подпись оси из словаря сайта', (tester) async {
    appLang.value = 'en';
    final m = measure('wrist_lift', 'deg', [0, 10, 30]);
    await pump(tester, m);
    expect(find.text(Strings.en['chart_y_label_wrist_lift']!), findsOneWidget);
  });

  test('niceStep: шаг из ряда 1, 2, 5', () {
    expect(niceStep(180), 50);
    expect(niceStep(1.4), 0.5);
    expect(niceStep(40), 10);
    expect(niceStep(0), 1);
  });
}
