import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:seriq_mobile/core/strings.dart';
import 'package:seriq_mobile/features/result/result_screen.dart';
import 'package:seriq_mobile/models/analysis_result.dart';

// loadResult — результат из примера docs/api-examples
AnalysisResult loadResult(String name) => AnalysisResult.fromJson(
    jsonDecode(File('../../docs/api-examples/$name').readAsStringSync())
        as Map<String, dynamic>);

// pumpResult — показывает экран результата
Future<void> pumpResult(WidgetTester tester, AnalysisResult r) async {
  await tester.pumpWidget(MaterialApp(home: ResultScreen(result: r)));
  await tester.pump();
}

void main() {
  setUp(() => appLang.value = 'ru');

  testWidgets('complete: «Выполнено» и плашка мока', (tester) async {
    await pumpResult(tester, loadResult('analysis-complete.json'));
    expect(find.text('Выполнено'), findsOneWidget);
    expect(find.text('Тестовые данные — не результат модели'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });

  testWidgets('incomplete: нейтральный «Проверьте инструкцию»', (tester) async {
    await pumpResult(tester, loadResult('analysis-incomplete.json'));
    expect(find.text('Проверьте инструкцию'), findsOneWidget);
    expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
    expect(find.text('Выполнено не полностью'), findsOneWidget);
  });

  testWidgets('uncertain: подсказка arm_not_visible', (tester) async {
    await pumpResult(tester, loadResult('analysis-uncertain.json'));
    expect(find.text('Не удалось определить'), findsOneWidget);
    expect(find.text(Strings.ru['warning_arm_not_visible']!), findsOneWidget);
  });

  testWidgets('source model: без плашки «Тестовые данные»', (tester) async {
    final json = jsonDecode(File('../../docs/api-examples/analysis-complete.json')
        .readAsStringSync()) as Map<String, dynamic>;
    json['source'] = 'model';
    await pumpResult(tester, AnalysisResult.fromJson(json));
    expect(find.text('Выполнено'), findsOneWidget);
    expect(find.text('Тестовые данные — не результат модели'), findsNothing);
  });

  testWidgets('казахский язык', (tester) async {
    appLang.value = 'kk';
    await pumpResult(tester, loadResult('analysis-complete.json'));
    expect(find.text('Орындалды'), findsOneWidget);
  });
}
