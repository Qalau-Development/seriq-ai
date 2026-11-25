import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seriq_mobile/models/analysis_result.dart';

// loadExample — читает пример ответа API из docs/api-examples
Map<String, dynamic> loadExample(String name) {
  final file = File('../../docs/api-examples/$name');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

// forExercise — ответ для другого упражнения по контракту: свой measure, pose без elbow, без angle_series
Map<String, dynamic> forExercise(
  String exercise,
  String name,
  String unit,
  double value,
) {
  final json = loadExample('analysis-complete.json');
  json['exercise'] = exercise;
  json.remove('angle_series');
  (json['pose'] as Map<String, dynamic>).remove('elbow');
  json['measure'] = {
    'name': name,
    'unit': unit,
    'value': value,
    'series': {
      'fps': 10,
      'values': [100.0, 101.3, null, 118.9, value],
    },
  };
  return json;
}

void main() {
  test('complete: measure E02 повторяет angle_series', () {
    final r = AnalysisResult.fromJson(loadExample('analysis-complete.json'));
    expect(r.verdict, 'completed');
    expect(r.isMock, isTrue);
    expect(r.exercise, 'E02');
    expect(r.mainCycle!.label, 'complete');
    expect(r.mainCycle!.verdict, 'completed');
    expect(r.measure!.name, 'elbow_angle');
    expect(r.measure!.unit, 'deg');
    expect(r.measure!.value, r.angleSeries!.maxValue);
    expect(r.measure!.series.values, r.angleSeries!.values);
    expect(r.warnings, isEmpty);
  });

  test('incomplete', () {
    final r = AnalysisResult.fromJson(loadExample('analysis-incomplete.json'));
    expect(r.verdict, 'check_instructions');
    expect(r.mainCycle!.label, 'incomplete');
  });

  test('uncertain с пропусками и предупреждением', () {
    final r = AnalysisResult.fromJson(loadExample('analysis-uncertain.json'));
    expect(r.verdict, 'check_instructions');
    expect(r.mainCycle!.label, 'uncertain');
    expect(r.measure!.series.values.contains(null), isTrue);
    expect(r.warnings, contains('arm_not_visible'));
  });

  group('measure для E01–E04', () {
    final cases = {
      'E01': ('lift_height', 'hand_lengths', 1.4),
      'E02': ('elbow_angle', 'deg', 166.2),
      'E03': ('wrist_lift', 'deg', 38.0),
      'E04': ('hand_openness', 'percent', 138.5),
    };
    for (final e in cases.entries) {
      test(e.key, () {
        final (name, unit, value) = e.value;
        final r = AnalysisResult.fromJson(forExercise(e.key, name, unit, value));
        expect(r.exercise, e.key);
        expect(r.measure!.name, name);
        expect(r.measure!.unit, unit);
        expect(r.measure!.value, value);
        expect(r.measure!.series.fps, 10);
        expect(r.measure!.series.values, [100.0, 101.3, null, 118.9, value]);
        expect(r.angleSeries, isNull);
        expect(r.pose!.elbow, isNull);
      });
    }
  });

  test('без measure откат на angle_series (старый ответ E02)', () {
    final json = loadExample('analysis-complete.json')..remove('measure');
    final r = AnalysisResult.fromJson(json);
    expect(r.measure!.name, 'elbow_angle');
    expect(r.measure!.unit, 'deg');
    expect(r.measure!.value, r.angleSeries!.maxValue);
    expect(r.measure!.series.values, r.angleSeries!.values);
  });

  test('без measure и без angle_series измеренного значения нет', () {
    final json = loadExample('analysis-complete.json')
      ..remove('measure')
      ..remove('angle_series');
    expect(AnalysisResult.fromJson(json).measure, isNull);
  });

  test('measure.value = null: сигнал слишком короткий', () {
    final json = forExercise('E04', 'hand_openness', 'percent', 100)
      ..['measure'] = {
        'name': 'hand_openness',
        'unit': 'percent',
        'value': null,
        'series': {'fps': 10, 'values': [null, null]},
      };
    final r = AnalysisResult.fromJson(json);
    expect(r.measure!.value, isNull);
    expect(r.measure!.series.maxValue, isNull);
  });

  test('ответ без поля exercise — E02, неизвестные поля игнорируются', () {
    final json = loadExample('analysis-complete.json')
      ..remove('exercise')
      ..['new_field'] = {'a': 1};
    expect(AnalysisResult.fromJson(json).exercise, 'E02');
  });

  test('значения для истории округляются до десятых', () {
    final m = Measure.tryParse({
      'name': 'lift_height',
      'unit': 'hand_lengths',
      'value': 1.2345,
      'series': {'fps': 10, 'values': [0.04, null, 1.2345]},
    })!;
    final json = m.rounded.toJson();
    expect(json['value'], 1.2);
    expect((json['series'] as Map)['values'], [0.0, null, 1.2]);
  });
}
