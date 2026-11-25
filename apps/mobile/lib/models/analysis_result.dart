import 'dart:ui' show Offset;

import '../core/exercises.dart';

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

// Series — ряд значений по времени для графика, null — рука не найдена в кадре
class Series {
  final double fps;
  final List<double?> values;

  Series({required this.fps, required this.values});

  Series.fromJson(Map<String, dynamic> j)
    : fps = (j['fps'] as num).toDouble(),
      values = (j['values'] as List)
          .map((v) => v == null ? null : (v as num).toDouble())
          .toList();

  // maxValue — наибольшее значение без пропусков, null если руки не было видно
  double? get maxValue {
    final known = values.whereType<double>();
    return known.isEmpty ? null : known.reduce((a, b) => a > b ? a : b);
  }

  // toJson — ряд для истории, значения округлены до десятых
  Map<String, dynamic> toJson() => {
    'fps': fps,
    'values': values.map(roundTenth).toList(),
  };
}

// roundTenth — значение с одной цифрой после запятой, null остаётся null
double? roundTenth(double? v) => v == null ? null : (v * 10).round() / 10;

// Measure — что измеряем и показываем: имя, единица, значение и ряд для графика
class Measure {
  final String name;
  final String unit;
  final double? value;
  final Series series;

  Measure({
    required this.name,
    required this.unit,
    required this.value,
    required this.series,
  });

  // tryParse — measure из ответа или записи истории; null, если поля нет или оно неполное
  static Measure? tryParse(Object? j) {
    if (j is! Map<String, dynamic>) return null;
    try {
      return Measure(
        name: j['name'] as String,
        unit: j['unit'] as String,
        value: (j['value'] as num?)?.toDouble(),
        series: Series.fromJson(j['series'] as Map<String, dynamic>),
      );
    } catch (_) {
      return null;
    }
  }

  // fromAngleSeries — откат для старого ответа E02 без measure
  factory Measure.fromAngleSeries(Series angles) => Measure(
    name: 'elbow_angle',
    unit: 'deg',
    value: angles.maxValue,
    series: angles,
  );

  // rounded — копия для истории: значение и ряд округлены до десятых
  Measure get rounded => Measure(
    name: name,
    unit: unit,
    value: roundTenth(value),
    series: Series(fps: series.fps, values: series.values.map(roundTenth).toList()),
  );

  // toJson — формат measure из api.md
  Map<String, dynamic> toJson() => {
    'name': name,
    'unit': unit,
    'value': value,
    'series': series.toJson(),
  };
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

// Pose — точки кисти по кадрам и локоть (только у E02) для линии руки поверх видео
class Pose {
  final double fps;
  final Offset? elbow;
  final List<PoseFrame?> frames;

  Pose.fromJson(Map<String, dynamic> j)
    : fps = (j['fps'] as num).toDouble(),
      elbow = j['elbow'] == null ? null : _point(j['elbow']),
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

  // handAt — 21 точка кисти на момент видео: между двумя соседними кадрами ответа точки плавно сдвигаются; null — кисти нет
  List<Offset>? handAt(Duration position) {
    final pos = position.inMicroseconds / 1e6 * fps;
    if (pos < 0) return null;
    final i0 = pos.floor();
    final a = i0 < frames.length ? frames[i0] : null;
    final b = i0 + 1 < frames.length ? frames[i0 + 1] : null;
    if (a != null && b != null && a.hand.length == b.hand.length) {
      final k = pos - i0;
      return [
        for (var n = 0; n < a.hand.length; n++)
          Offset.lerp(a.hand[n], b.hand[n], k)!,
      ];
    }
    final nearIndex = pos.round();
    final near = nearIndex < frames.length ? frames[nearIndex] : null;
    return near?.hand;
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
  final String exercise;
  final String verdict;
  final List<CycleResult> cycles;
  final Series? angleSeries;
  final Measure? measure;
  final List<String> warnings;
  final int processingMs;
  final Pose? pose;

  AnalysisResult._({
    required this.analysisId,
    required this.source,
    required this.modelVersion,
    required this.exercise,
    required this.verdict,
    required this.cycles,
    required this.angleSeries,
    required this.measure,
    required this.warnings,
    required this.processingMs,
    required this.pose,
  });

  // fromJson — разбирает ответ: measure, а без него откат на angle_series (старый ответ E02)
  factory AnalysisResult.fromJson(Map<String, dynamic> j) {
    final angles = j['angle_series'] is Map<String, dynamic>
        ? Series.fromJson(j['angle_series'] as Map<String, dynamic>)
        : null;
    return AnalysisResult._(
      analysisId: j['analysis_id'] as String,
      source: j['source'] as String,
      modelVersion: j['model_version'] as String,
      exercise: parseExercise(j['exercise'] as String?),
      verdict: j['verdict'] as String,
      cycles: (j['cycles'] as List)
          .map((c) => CycleResult.fromJson(c as Map<String, dynamic>))
          .toList(),
      angleSeries: angles,
      measure:
          Measure.tryParse(j['measure']) ??
          (angles == null ? null : Measure.fromAngleSeries(angles)),
      warnings: List<String>.from(j['warnings'] as List),
      processingMs: j['processing_ms'] as int,
      pose: Pose.tryParse(j['pose']),
    );
  }

  bool get isMock => source == 'mock';

  // mainCycle — цикл, по которому показываем результат (в MVP он один)
  CycleResult? get mainCycle => cycles.isEmpty ? null : cycles.first;
}
