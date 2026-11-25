import 'dart:math' as math;
import 'dart:ui' show Offset;

import '../models/analysis_result.dart';

const _startShare = 0.1;
const _riseFrom = 0.1;
const _riseTo = 0.9;

// LiftAttempt — попытка E01 для сравнения: время, высота и время подъёма
class LiftAttempt {
  final DateTime at;
  final double? value;
  final double? riseS;

  const LiftAttempt(this.at, this.value, this.riseS);
}

// LiftComparison — разница с прошлой попыткой, лучший результат и признак «это лучший»
class LiftComparison {
  final ({double? valueDelta, double? riseDelta})? previous;
  final double? best;
  final bool isBest;

  const LiftComparison(this.previous, this.best, this.isBest);
}

// round1 — округление до 0,1, как значения в ответе API
double round1(double v) => (v * 10).round() / 10;

// liftStart — точка старта подъёма: среднее положение запястья в первых 10% кадров с кистью, как в движке E01
Offset? liftStart(Pose? pose) {
  final wrists = (pose?.frames ?? const <PoseFrame?>[])
      .whereType<PoseFrame>()
      .map((f) => f.wrist)
      .toList();
  if (wrists.isEmpty) return null;
  final first = wrists.take(math.max(1, (wrists.length * _startShare).round())).toList();
  return Offset(
    first.fold(0.0, (s, p) => s + p.dx) / first.length,
    first.fold(0.0, (s, p) => s + p.dy) / first.length,
  );
}

// riseTime — секунды подъёма: от 10% до 90% максимума ряда; null, если подъёма нет или ряд пуст
double? riseTime(Series? series) {
  final values = series?.values ?? const <double?>[];
  final known = values.whereType<double>().toList();
  if (known.isEmpty || series == null || series.fps <= 0) return null;
  final base = known.first;
  final peak = known.reduce(math.max);
  final range = peak - base;
  if (range <= 0) return null;
  final from = values.indexWhere((v) => v != null && v - base >= _riseFrom * range);
  final to = values.indexWhere((v) => v != null && v - base >= _riseTo * range);
  if (from < 0 || to < from) return null;
  return round1((to - from) / series.fps);
}

// compareWithHistory — сравнение с прошлой попыткой того же упражнения и лучший результат по измеренному значению
LiftComparison compareWithHistory(LiftAttempt current, List<LiftAttempt> history) {
  final earlier = history
      .where((a) => a.at.isBefore(current.at) && a.value != null)
      .toList()
    ..sort((a, b) => b.at.compareTo(a.at));
  final prev = earlier.firstOrNull;
  final values = [
    ...earlier.map((a) => a.value!),
    if (current.value != null) current.value!,
  ];
  final best = values.isEmpty ? null : values.reduce(math.max);
  final cv = current.value;
  return LiftComparison(
    prev == null
        ? null
        : (
            valueDelta: cv != null ? round1(cv - prev.value!) : null,
            riseDelta: current.riseS != null && prev.riseS != null
                ? round1(current.riseS! - prev.riseS!)
                : null,
          ),
    best,
    cv != null &&
        earlier.isNotEmpty &&
        cv == best &&
        earlier.every((a) => a.value! < cv),
  );
}
