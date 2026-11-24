import 'package:material_ui/material_ui.dart';

import '../core/strings.dart';

// VerdictCard — крупный итог повторения по метке и одна строка пояснения
class VerdictCard extends StatelessWidget {
  final String label;
  final double? maxAngle;

  const VerdictCard({super.key, required this.label, this.maxAngle});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final known = const {'complete', 'incomplete', 'uncertain'}.contains(label)
        ? label
        : 'uncertain';
    final done = known == 'complete';
    final color = done ? scheme.primary : scheme.onSurfaceVariant;
    final max = maxAngle;
    final line = max != null
        ? tr('result_line_$known').replaceAll('{max}', '${max.round()}')
        : tr('result_hint_$known');
    final text = line.isEmpty ? null : line;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              done ? Icons.check_circle_rounded : Icons.repeat_rounded,
              size: 96,
              color: color,
            ),
            const SizedBox(height: 12),
            Text(
              tr('result_title_$known'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: done ? scheme.primary : scheme.onSurface,
              ),
            ),
            if (text != null) ...[
              const SizedBox(height: 12),
              Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
