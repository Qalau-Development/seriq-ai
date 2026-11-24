import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seriq_mobile/models/analysis_result.dart';

// loadExample — читает пример ответа API из docs/api-examples
Map<String, dynamic> loadExample(String name) {
  final file = File('../../docs/api-examples/$name');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  test('complete', () {
    final r = AnalysisResult.fromJson(loadExample('analysis-complete.json'));
    expect(r.verdict, 'completed');
    expect(r.isMock, isTrue);
    expect(r.mainCycle!.label, 'complete');
    expect(r.mainCycle!.verdict, 'completed');
    expect(r.angleSeries.values, isNotEmpty);
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
    expect(r.angleSeries.values.contains(null), isTrue);
    expect(r.warnings, contains('arm_not_visible'));
  });
}
