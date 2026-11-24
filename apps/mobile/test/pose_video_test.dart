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
    PosePainter.paintFrame(
      canvas,
      const Size(300, 200),
      const Offset(-0.4, 1.3),
      r.pose!.frames[0],
    );
    PosePainter.paintFrame(canvas, const Size(300, 200), r.pose!.elbow, null);
    recorder.endRecording().dispose();
  });
}
