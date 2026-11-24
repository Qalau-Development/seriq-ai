import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:seriq_mobile/core/strings.dart';
import 'package:seriq_mobile/features/result/result_screen.dart';
import 'package:seriq_mobile/models/analysis_result.dart';

// loadJson — пример ответа API из docs/api-examples
Map<String, dynamic> loadJson(String name) =>
    jsonDecode(File('../../docs/api-examples/$name').readAsStringSync())
        as Map<String, dynamic>;

// loadResult — результат из примера docs/api-examples
AnalysisResult loadResult(String name) =>
    AnalysisResult.fromJson(loadJson(name));

// pumpResult — показывает экран результата на высоком экране, чтобы всё было видно
Future<void> pumpResult(WidgetTester tester, AnalysisResult r) async {
  tester.view.physicalSize = const Size(1080, 5000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: ResultScreen(result: r)));
  await tester.pump();
}

void main() {
  setUp(() => appLang.value = 'ru');

  testWidgets('complete: «Выполнено», угол из графика, плашка мока',
      (tester) async {
    final r = loadResult('analysis-complete.json');
    await pumpResult(tester, r);
    final max = r.angleSeries.maxValue!.round();
    expect(find.text('Выполнено'), findsOneWidget);
    expect(find.text('Рука разогнулась до $max° — полностью.'), findsOneWidget);
    expect(find.text('Тестовые данные — не результат модели'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.text('Уверенность оценки: высокая'), findsOneWidget);
  });

  testWidgets('incomplete: нейтральный заголовок и «из 180°»', (tester) async {
    final r = loadResult('analysis-incomplete.json');
    await pumpResult(tester, r);
    final max = r.angleSeries.maxValue!.round();
    expect(find.text('Рука разогнута не до конца'), findsOneWidget);
    expect(
        find.text(
            'Рука разогнулась до $max° из 180°. Посмотрите инструкцию и попробуйте ещё раз.'),
        findsOneWidget);
    expect(find.byIcon(Icons.repeat_rounded), findsOneWidget);
    expect(find.text('Проверьте инструкцию'), findsNothing);
  });

  testWidgets('uncertain: «Не удалось оценить», подсказки и разрывы',
      (tester) async {
    await pumpResult(tester, loadResult('analysis-uncertain.json'));
    expect(find.text('Не удалось оценить повторение'), findsOneWidget);
    expect(find.text(Strings.ru['result_text_uncertain']!), findsOneWidget);
    expect(find.text(Strings.ru['warning_arm_not_visible']!), findsOneWidget);
    expect(find.text(Strings.ru['chart_gap_hint']!), findsOneWidget);
    expect(find.text('Уверенность оценки: низкая'), findsOneWidget);
  });

  testWidgets('процент уверенности и постоянная подпись под графиком не показываются',
      (tester) async {
    await pumpResult(tester, loadResult('analysis-complete.json'));
    expect(find.textContaining('%'), findsNothing);
    expect(find.textContaining('Серым'), findsNothing);
    expect(find.text('Как двигалась рука'), findsOneWidget);
    expect(find.text('Угол локтя, ° (180° — прямая рука)'), findsOneWidget);
    expect(find.text(Strings.ru['chart_gap_hint']!), findsNothing);
  });

  testWidgets('source model: без плашки «Тестовые данные»', (tester) async {
    final json = loadJson('analysis-complete.json')..['source'] = 'model';
    await pumpResult(tester, AnalysisResult.fromJson(json));
    expect(find.text('Выполнено'), findsOneWidget);
    expect(find.text('Тестовые данные — не результат модели'), findsNothing);
  });

  testWidgets('казахский язык', (tester) async {
    appLang.value = 'kk';
    await pumpResult(tester, loadResult('analysis-incomplete.json'));
    expect(find.text('Қол соңына дейін жазылмады'), findsOneWidget);
  });
}
