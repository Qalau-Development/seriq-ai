import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:seriq_mobile/models/analysis_result.dart';
import 'package:seriq_mobile/widgets/pose_video.dart';

// loadJson — пример ответа API из docs/api-examples
Map<String, dynamic> loadJson(String name) =>
    jsonDecode(File('../../docs/api-examples/$name').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  test('рисование: локоть за краем и пустой кадр не падают', () {
    final r = AnalysisResult.fromJson(loadJson('analysis-complete.json'));
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    PosePainter.paintHand(
      canvas,
      const Size(300, 200),
      const Offset(-0.4, 1.3),
      r.pose!.frames[0]!.hand,
    );
    PosePainter.paintHand(canvas, const Size(300, 200), r.pose!.elbow, null,
        missingText: 'нет кисти');
    PosePainter.paintHand(
        canvas, const Size(300, 200), null, r.pose!.frames[0]!.hand);
    recorder.endRecording().dispose();
  });

  test('handAt: точки плавно сдвигаются между кадрами, нет кадра — нет кисти', () {
    final pose = AnalysisResult.fromJson(loadJson('analysis-uncertain.json')).pose!;
    final a = pose.frames[1]!.hand;
    final b = pose.frames[2]!.hand;
    final mid = pose.handAt(Duration(microseconds: (1.5 / pose.fps * 1e6).round()))!;
    expect(mid[0].dx, closeTo((a[0].dx + b[0].dx) / 2, 1e-6));
    expect(mid[8].dy, closeTo((a[8].dy + b[8].dy) / 2, 1e-6));
    expect(pose.handAt(const Duration(hours: 1)), isNull);
    expect(pose.handAt(const Duration(milliseconds: -5)), isNull);
  });
}
