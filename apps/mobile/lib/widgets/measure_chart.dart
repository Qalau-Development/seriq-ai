import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';

import '../core/measure_text.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../models/analysis_result.dart';

// niceStep — шаг оси из ряда 1, 2, 5, 10 · 10^n, чтобы в диапазоне поместилось около четырёх делений
double niceStep(double range) {
  if (range <= 0) return 1;
  final raw = range / 4;
  final pow10 = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  final f = raw / pow10;
  final nice = f <= 1 ? 1 : (f <= 2 ? 2 : (f <= 5 ? 5 : 10));
  return nice * pow10;
}

// MeasureChart — график измеряемого значения по времени; у E02 шкала 0–180°, null — разрыв линии, интервал повторения выделен, только если он короче записи
class MeasureChart extends StatelessWidget {
  final Measure measure;
  final CycleResult? cycle;

  const MeasureChart({super.key, required this.measure, this.cycle});

  @override
  Widget build(BuildContext context) {
    final series = measure.series;
    final keys = chartKeys[measure.name] ?? chartKeys['elbow_angle']!;
    final fixedScale = measure.name == 'elbow_angle';
    final fps = series.fps > 0 ? series.fps : 1.0;
    final values = series.values;
    final spots = <FlSpot>[
      for (var i = 0; i < values.length; i++)
        values[i] == null
            ? FlSpot.nullSpot
            : FlSpot(
                i / fps,
                fixedScale ? values[i]!.clamp(0, 180).toDouble() : values[i]!,
              ),
    ];
    final maxX = values.length <= 1 ? 1.0 : (values.length - 1) / fps;
    final known = values.whereType<double>().toList();
    double minY = 0;
    double maxY = 180;
    double stepY = 45;
    if (!fixedScale) {
      final lo = known.isEmpty ? 0.0 : known.reduce(math.min);
      final hi = known.isEmpty ? 1.0 : known.reduce(math.max);
      stepY = niceStep(hi - math.min(lo, 0));
      minY = math.min(0, (lo / stepY).floor() * stepY);
      maxY = (hi / stepY).ceil() * stepY;
      if (maxY <= minY) maxY = minY + stepY;
    }
    const axisStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: AppColors.muted,
    );
    final hasGaps = values.contains(null);
    final c = cycle;
    final cycleEnd = c == null ? 0.0 : math.min(c.endS, maxX);
    final showCycle = c != null && (c.startS > 0.5 || cycleEnd < maxX - 0.5);
    final xStep = maxX > 10 ? 2.0 : 1.0;
    final hints = [
      if (showCycle) tr('chart_cycle_hint'),
      if (hasGaps) tr('chart_gap_hint'),
    ].join(' ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr(keys.$1), style: AppText.smallStrong),
        const SizedBox(height: 12),
        AspectRatio(
          aspectRatio: 1.5,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: maxX,
              minY: minY,
              maxY: maxY,
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (touched) => [
                    for (final t in touched)
                      LineTooltipItem(
                        '${tr(keys.$2)}: ${formatChartValue(t.y, measure.unit)}\n'
                        '${formatSeconds(t.x)} ${tr('chart_seconds')}',
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: stepY,
                getDrawingHorizontalLine: (_) =>
                    const FlLine(color: AppColors.line, strokeWidth: 1),
              ),
              borderData: FlBorderData(
                show: true,
                border: const Border(
                  left: BorderSide(color: AppColors.lineStrong),
                  bottom: BorderSide(color: AppColors.lineStrong),
                ),
              ),
              rangeAnnotations: RangeAnnotations(
                verticalRangeAnnotations: [
                  if (showCycle)
                    VerticalRangeAnnotation(
                      x1: c.startS,
                      x2: cycleEnd,
                      color: AppColors.accentSoft,
                    ),
                ],
              ),
              extraLinesData: ExtraLinesData(
                verticalLines: [
                  if (showCycle)
                    for (final x in [c.startS, cycleEnd])
                      VerticalLine(
                        x: x,
                        color: AppColors.accentStrong,
                        strokeWidth: 2,
                        dashArray: const [5, 4],
                      ),
                ],
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: stepY,
                    reservedSize: 48,
                    getTitlesWidget: (v, meta) => SideTitleWidget(
                      meta: meta,
                      child: Text(
                        formatSeconds(v),
                        style: axisStyle,
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: xStep,
                    reservedSize: 30,
                    getTitlesWidget: (v, meta) => (v - v.round()).abs() > 0.01
                        ? const SizedBox.shrink()
                        : SideTitleWidget(
                            meta: meta,
                            child: Text('${v.round()}', style: axisStyle),
                          ),
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  color: AppColors.brand,
                  barWidth: 3,
                  isCurved: true,
                  preventCurveOverShooting: true,
                  dotData: const FlDotData(show: false),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Center(child: Text(tr('chart_x_label'), style: axisStyle)),
        if (hints.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(hints, style: AppText.small),
        ],
      ],
    );
  }
}
