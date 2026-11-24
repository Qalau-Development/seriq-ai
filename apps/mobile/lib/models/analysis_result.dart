import 'dart:ui' show Offset;

// CycleResult — результат одного цикла упражнения
class CycleResult {
  final int index;
  final double startS;
  final double endS;
  final String label;
  final double confidence;
  final String verdict;

  CycleResult.fromJson(Map<String, dynamic> j)
    : index = j['index'] as int,
      startS = (j['start_s'] as num).toDouble(),
      endS = (j['end_s'] as num).toDouble(),
      label = j['label'] as String,
      confidence = (j['confidence'] as num).toDouble(),
      verdict = j['verdict'] as String;
}

// AngleSeries — угол локтя по времени для графика
class AngleSeries {
  final double fps;
  final List<double?> values;

  AngleSeries.fromJson(Map<String, dynamic> j)
    : fps = (j['fps'] as num).toDouble(),
      values = (j['values'] as List)
          .map((v) => v == null ? null : (v as num).toDouble())
          .toList();

  // maxValue — наибольший угол без пропусков, null если руки не было видно
  double? get maxValue {
    final known = values.whereType<double>();
    return known.isEmpty ? null : known.reduce((a, b) => a > b ? a : b);
  }
}

// _point — точка [x, y] в долях ширины и высоты кадра
Offset _point(Object? p) {
  final xy = p as List;
  return Offset((xy[0] as num).toDouble(), (xy[1] as num).toDouble());
}

// PoseFrame — запястье и 21 точка кисти в одном кадре
class PoseFrame {
  final double t;
  final Offset wrist;
  final List<Offset> hand;

  PoseFrame.fromJson(Map<String, dynamic> j)
    : t = (j['t'] as num).toDouble(),
      wrist = _point(j['wrist']),
      hand = (j['hand'] as List).map(_point).toList();
}

// Pose — локоть и точки кисти по кадрам для линии руки поверх видео
class Pose {
  final double fps;
  final Offset elbow;
  final List<PoseFrame?> frames;

  Pose.fromJson(Map<String, dynamic> j)
    : fps = (j['fps'] as num).toDouble(),
      elbow = _point(j['elbow']),
      frames = (j['frames'] as List)
          .map(
            (f) => f == null
                ? null
                : PoseFrame.fromJson(f as Map<String, dynamic>),
          )
          .toList();

  // tryParse — pose из ответа или null, если поля нет или оно неполное
  static Pose? tryParse(Object? j) {
    if (j is! Map<String, dynamic>) return null;
    try {
      final pose = Pose.fromJson(j);
      return pose.fps > 0 && pose.frames.isNotEmpty ? pose : null;
    } catch (_) {
      return null;
    }
  }

  // frameAt — кадр для момента видео: индекс i, где t = i / fps
  PoseFrame? frameAt(Duration position) {
    final i = (position.inMicroseconds / 1e6 * fps).floor();
    if (i < 0 || i >= frames.length) return null;
    return frames[i];
  }
}

// AnalysisResult — полный ответ POST /analysis
class AnalysisResult {
  final String analysisId;
  final String source;
  final String modelVersion;
  final String verdict;
  final List<CycleResult> cycles;
  final AngleSeries angleSeries;
  final List<String> warnings;
  final int processingMs;
  final Pose? pose;

  AnalysisResult.fromJson(Map<String, dynamic> j)
    : analysisId = j['analysis_id'] as String,
      source = j['source'] as String,
      modelVersion = j['model_version'] as String,
      verdict = j['verdict'] as String,
      cycles = (j['cycles'] as List)
          .map((c) => CycleResult.fromJson(c as Map<String, dynamic>))
          .toList(),
      angleSeries = AngleSeries.fromJson(
        j['angle_series'] as Map<String, dynamic>,
      ),
      warnings = List<String>.from(j['warnings'] as List),
      processingMs = j['processing_ms'] as int,
      pose = Pose.tryParse(j['pose']);

  bool get isMock => source == 'mock';

  // mainCycle — цикл, по которому показываем результат (в MVP он один)
  CycleResult? get mainCycle => cycles.isEmpty ? null : cycles.first;
}
