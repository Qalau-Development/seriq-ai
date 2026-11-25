import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seriq_mobile/core/measure_text.dart';
import 'package:seriq_mobile/core/strings.dart';
import 'package:seriq_mobile/models/analysis_result.dart';

// result — ответ для упражнения с заданными measure и меткой цикла
AnalysisResult result(
  String exercise,
  String name,
  String unit,
  double? value, {
  String label = 'complete',
}) {
  final json =
      jsonDecode(File('../../docs/api-examples/analysis-complete.json').readAsStringSync())
          as Map<String, dynamic>;
  json['exercise'] = exercise;
  json['measure'] = {
    'name': name,
    'unit': unit,
    'value': value,
    'series': {'fps': 10, 'values': [value]},
  };
  (json['cycles'] as List).first['label'] = label;
  return AnalysisResult.fromJson(json);
}

void main() {
  setUp(() => appLang.value = 'ru');

  test('E04: раскрытие выросло на N% или от начального', () {
    expect(
      resultLines(result('E04', 'hand_openness', 'percent', 138.5), 'complete'),
      ['Раскрытие кисти выросло на 39%'],
    );
    expect(
      resultLines(result('E04', 'hand_openness', 'percent', 90), 'complete'),
      ['Раскрытие кисти: 90% от начального'],
    );
  });

  test('E03: кисть повернулась на N°', () {
    expect(
      resultLines(result('E03', 'wrist_lift', 'deg', 37.6), 'complete'),
      ['Кисть повернулась на 38°'],
    );
  });

  test('E01: длины кисти с запятой, а в английском с точкой', () {
    final r = result('E01', 'lift_height', 'hand_lengths', 1.44);
    expect(resultLines(r, 'complete'), ['Кисть поднялась на 1,4 длины кисти']);
    appLang.value = 'en';
    expect(resultLines(r, 'complete'), [
      Strings.en['result_measure_lift_height']!.replaceAll('{n}', '1.4'),
    ]);
  });

  test('не до конца и не удалось оценить: значение и подсказка', () {
    final r = result('E04', 'hand_openness', 'percent', 120, label: 'incomplete');
    expect(resultLines(r, 'incomplete'), [
      'Раскрытие кисти выросло на 20%',
      'Посмотрите инструкцию и попробуйте ещё раз.',
    ]);
    final u = result('E03', 'wrist_lift', 'deg', 10, label: 'uncertain');
    expect(resultLines(u, 'uncertain'), [
      'Кисть повернулась на 10°',
      Strings.ru['result_hint_uncertain_other']!,
    ]);
  });

  test('нет значения: только подсказка, у выполненного — ничего', () {
    final n = result('E04', 'hand_openness', 'percent', null, label: 'uncertain');
    expect(resultLines(n, 'uncertain'), [Strings.ru['result_hint_uncertain_other']!]);
    final done = result('E04', 'hand_openness', 'percent', null);
    expect(resultLines(done, 'complete'), isEmpty);
  });

  test('E02: строка с углом и без него', () {
    final r = result('E02', 'elbow_angle', 'deg', 166.2);
    expect(resultLines(r, 'complete'), ['Рука разогнулась до 166° (прямая рука — 180°).']);
    expect(resultLines(r, 'incomplete'), [
      'Рука разогнулась до 166° из 180°. Посмотрите инструкцию и попробуйте ещё раз.',
    ]);
    final none = result('E02', 'elbow_angle', 'deg', null);
    expect(resultLines(none, 'incomplete'), ['Посмотрите инструкцию и попробуйте ещё раз.']);
  });

  test('заголовок: у E02 свой, у остальных «Выполнено» или «Проверьте инструкцию»', () {
    expect(resultTitle('incomplete', 'E02'), 'Рука разогнута не до конца');
    expect(resultTitle('uncertain', 'E02'), 'Не удалось оценить повторение');
    expect(resultTitle('complete', 'E04'), 'Выполнено');
    expect(resultTitle('incomplete', 'E04'), 'Проверьте инструкцию');
    expect(resultTitle('uncertain', 'E01'), 'Проверьте инструкцию');
  });

  test('значения графика с единицей', () {
    expect(formatChartValue(138.4, 'percent'), '138%');
    expect(formatChartValue(37.6, 'deg'), '38°');
    expect(formatChartValue(1.25, 'hand_lengths'), '1,3 длины кисти');
  });
}
