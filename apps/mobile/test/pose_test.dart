import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:seriq_mobile/models/analysis_result.dart';

// loadJson — пример ответа API из docs/api-examples
Map<String, dynamic> loadJson(String name) =>
    jsonDecode(File('../../docs/api-examples/$name').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  for (final name in [
    'analysis-complete.json',
    'analysis-incomplete.json',
    'analysis-uncertain.json',
  ]) {
    test('pose из $name', () {
      final r = AnalysisResult.fromJson(loadJson(name));
      final pose = r.pose!;
      expect(pose.frames.length, r.angleSeries.values.length);
      expect(pose.fps, r.angleSeries.fps);
      final f = pose.frames.firstWhere((f) => f != null)!;
      expect(f.hand.length, 21);
      expect(f.wrist, f.hand.first);
    });
  }

  test('frameAt: кадр i для t = i / fps, null и вне видео — нет кадра', () {
    final r = AnalysisResult.fromJson(loadJson('analysis-uncertain.json'));
    final pose = r.pose!;
    final iNull = pose.frames.indexOf(null);
    expect(iNull, greaterThanOrEqualTo(0));
    expect(
      pose.frameAt(Duration(milliseconds: (iNull * 1000 / pose.fps).round())),
      isNull,
    );
    expect(
      pose.frameAt(const Duration(milliseconds: 150)),
      same(pose.frames[1]),
    );
    expect(pose.frameAt(const Duration(hours: 1)), isNull);
    expect(pose.frameAt(const Duration(milliseconds: -1)), isNull);
  });

  test('без pose или с битым pose — как раньше', () {
    final noPose = loadJson('analysis-complete.json')..remove('pose');
    expect(AnalysisResult.fromJson(noPose).pose, isNull);
    final broken = loadJson('analysis-complete.json')..['pose'] = {'fps': 10};
    expect(AnalysisResult.fromJson(broken).pose, isNull);
  });
}
