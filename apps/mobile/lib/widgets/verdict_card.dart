import 'package:material_ui/material_ui.dart';

import '../core/strings.dart';

// VerdictCard — «Выполнено» или «Проверьте инструкцию» с уверенностью
class VerdictCard extends StatelessWidget {
  final String verdict;
  final String label;
  final double confidence;

  const VerdictCard({
    super.key,
    required this.verdict,
    required this.label,
    required this.confidence,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final done = verdict == 'completed';
    final color = done ? scheme.primary : scheme.onSurfaceVariant;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              done ? Icons.check_circle_rounded : Icons.info_outline_rounded,
              size: 96,
              color: color,
            ),
            const SizedBox(height: 12),
            Text(
              tr('verdict_$verdict'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: done ? scheme.primary : scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tr('label_$label'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20),
            ),
            if (!done) ...[
              const SizedBox(height: 12),
              Text(
                tr('verdict_check_instructions_hint'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
              ),
            ],
            const SizedBox(height: 16),
            Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: '${tr('confidence_title')}: ${trConfidence(confidence)}',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w600),
                ),
                TextSpan(
                  text: '  ${(confidence * 100).round()}%',
                  style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant),
                ),
              ]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
