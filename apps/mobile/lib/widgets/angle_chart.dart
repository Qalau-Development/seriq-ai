import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';

import '../core/strings.dart';
import '../models/analysis_result.dart';

// AngleChart — график угла локтя по времени, null — разрыв линии
class AngleChart extends StatelessWidget {
  final AngleSeries series;

  const AngleChart({super.key, required this.series});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fps = series.fps > 0 ? series.fps : 1.0;
    final spots = <FlSpot>[
      for (var i = 0; i < series.values.length; i++)
        series.values[i] == null
            ? FlSpot.nullSpot
            : FlSpot(i / fps, series.values[i]!.clamp(0, 180).toDouble()),
    ];
    final maxX = series.values.length <= 1 ? 1.0 : (series.values.length - 1) / fps;
    const axisStyle = TextStyle(fontSize: 14);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1.5,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: maxX,
              minY: 0,
              maxY: 180,
              lineTouchData: const LineTouchData(enabled: false),
              gridData: FlGridData(
                horizontalInterval: 45,
                verticalInterval: maxX > 10 ? 2 : 1,
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: scheme.outlineVariant),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 45,
                    reservedSize: 44,
                    getTitlesWidget: (v, meta) => SideTitleWidget(
                      meta: meta,
                      child: Text('${v.round()}°', style: axisStyle),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: maxX > 10 ? 2 : 1,
                    reservedSize: 30,
                    getTitlesWidget: (v, meta) => SideTitleWidget(
                      meta: meta,
                      child: Text('${v.round()}', style: axisStyle),
                    ),
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  color: scheme.primary,
                  barWidth: 4,
                  dotData: const FlDotData(show: false),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Center(child: Text(tr('chart_x_label'), style: axisStyle)),
        if (series.values.contains(null)) ...[
          const SizedBox(height: 8),
          Text(tr('chart_gap_hint'), style: const TextStyle(fontSize: 16)),
        ],
      ],
    );
  }
}
