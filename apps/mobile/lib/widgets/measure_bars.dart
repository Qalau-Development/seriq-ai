import 'package:material_ui/material_ui.dart';

import '../core/measure_text.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../models/session.dart';
import 'app_card.dart';
import 'measure_chart.dart';

// ValuePoint — значение одного повторения с его номером
class ValuePoint {
  final int n;
  final double value;

  const ValuePoint(this.n, this.value);
}

// attemptPoints — значения повторений занятия; номер повторения сохраняется, повторения без значения пропускаются
({List<ValuePoint> points, ({String name, String unit})? measure}) attemptPoints(
  List<Attempt> attempts,
) {
  final points = [
    for (var i = 0; i < attempts.length; i++)
      if (attempts[i].measure?.value != null)
        ValuePoint(i + 1, attempts[i].measure!.value!),
  ];
  final first = attempts.map((a) => a.measure).where((m) => m?.value != null).firstOrNull;
  return (
    points: points,
    measure: first == null ? null : (name: first.name, unit: first.unit),
  );
}

// maxVertical — до скольких повторений столбики идут вертикально, дальше горизонтально
const maxVertical = 6;

// MeasureBars — измеренное значение по повторениям: столбец на каждое; до шести вертикально, больше горизонтально, чтобы подпись каждого читалась
class MeasureBars extends StatelessWidget {
  final List<ValuePoint> points;
  final ({String name, String unit})? measure;

  const MeasureBars({super.key, required this.points, required this.measure});

  // _label — значение у столбика: целое, а в длинах кисти с десятыми
  String _label(double v, String unit) =>
      unit == 'hand_lengths' ? num((v * 10).round() / 10 == v.roundToDouble() ? '${v.round()}' : '${(v * 10).round() / 10}') : '${v.round()}';

  @override
  Widget build(BuildContext context) {
    final m = measure;
    if (points.isEmpty || m == null) return const SizedBox.shrink();
    final keys = chartKeys[m.name] ?? chartKeys['elbow_angle']!;
    final fixed = m.name == 'elbow_angle';
    final maxValue = points.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    final step = fixed ? 45.0 : niceStep(maxValue);
    final top = fixed ? 180.0 : (maxValue / step).ceil() * step;
    final vertical = points.length <= maxVertical;
    return AppCard(
      padding: const EdgeInsets.all(20),
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('summary_values_title'), style: AppText.h3),
          const SizedBox(height: 12),
          Text(tr(keys.$1), style: AppText.smallStrong),
          const SizedBox(height: 12),
          if (vertical)
            _Vertical(points: points, top: top, step: step, unit: m.unit, label: _label)
          else
            _Horizontal(points: points, top: top, unit: m.unit, label: _label),
          const SizedBox(height: 12),
          Text(tr('summary_values_hint'), style: AppText.small),
        ],
      ),
    );
  }
}

const _axis = TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w600,
  color: AppColors.muted,
);

// _Vertical — вертикальные столбики с подписью значения сверху и номером повторения снизу
class _Vertical extends StatelessWidget {
  final List<ValuePoint> points;
  final double top;
  final double step;
  final String unit;
  final String Function(double, String) label;

  const _Vertical({
    required this.points,
    required this.top,
    required this.step,
    required this.unit,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    const plotHeight = 200.0;
    final ticks = [for (var v = 0.0; v <= top + 0.001; v += step) v];
    return Column(
      children: [
        SizedBox(
          height: plotHeight + 28,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 44,
                child: Stack(
                  children: [
                    for (final t in ticks)
                      Positioned(
                        right: 8,
                        bottom: 0 + (t / top) * plotHeight - 9,
                        child: Text(label(t, unit), style: _axis),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      left: BorderSide(color: AppColors.lineStrong),
                      bottom: BorderSide(color: AppColors.lineStrong),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (final p in points)
                        Flexible(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  label(p.value, unit),
                                  style: AppText.bodyStrong.copyWith(
                                    fontSize: 16,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  height: (p.value / top).clamp(0.0, 1.0) * plotHeight,
                                  constraints: const BoxConstraints(maxWidth: 64),
                                  decoration: const BoxDecoration(
                                    color: AppColors.brand,
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(6),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            const SizedBox(width: 44),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final p in points)
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('${p.n}', style: _axis),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(tr('attempt_n'), style: _axis),
      ],
    );
  }
}

// _Horizontal — горизонтальные столбики: номер повторения слева, значение справа
class _Horizontal extends StatelessWidget {
  final List<ValuePoint> points;
  final double top;
  final String unit;
  final String Function(double, String) label;

  const _Horizontal({
    required this.points,
    required this.top,
    required this.unit,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(tr('attempt_n'), style: _axis),
        ),
        for (final p in points)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text('${p.n}', textAlign: TextAlign.right, style: _axis),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) => Row(
                      children: [
                        Container(
                          height: 16,
                          width: ((p.value / top).clamp(0.0, 1.0)) * (c.maxWidth - 44),
                          decoration: const BoxDecoration(
                            color: AppColors.brand,
                            borderRadius: BorderRadius.horizontal(
                              right: Radius.circular(6),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          label(p.value, unit),
                          style: AppText.bodyStrong.copyWith(fontSize: 15, height: 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(left: 36, top: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label(0, unit), style: _axis),
              Text(label(top / 2, unit), style: _axis),
              Text(label(top, unit), style: _axis),
            ],
          ),
        ),
      ],
    );
  }
}
