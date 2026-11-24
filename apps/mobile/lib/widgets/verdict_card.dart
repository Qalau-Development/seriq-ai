import 'package:material_ui/material_ui.dart';

import '../core/strings.dart';
import '../core/theme.dart';
import 'attempt_tile.dart';

// VerdictCard — крупный итог повторения по метке и одна строка пояснения
class VerdictCard extends StatelessWidget {
  final String label;
  final double? maxAngle;

  const VerdictCard({super.key, required this.label, this.maxAngle});

  @override
  Widget build(BuildContext context) {
    final known = const {'complete', 'incomplete', 'uncertain'}.contains(label)
        ? label
        : 'uncertain';
    final done = known == 'complete';
    final max = maxAngle;
    final line = max != null
        ? tr('result_line_$known').replaceAll('{max}', '${max.round()}')
        : tr('result_hint_$known');
    final text = line.isEmpty ? null : line;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: done ? AppColors.accentSoft : AppColors.neutralSoft,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        border: Border.all(
          color: done ? AppColors.accent : AppColors.brandSoft2,
          width: done ? 1.5 : 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ResultMark(label: known, size: 52),
          const SizedBox(height: 16),
          Text(tr('result_title_$known'), style: AppText.title),
          if (text != null) ...[
            const SizedBox(height: 12),
            Text(text, style: AppText.bodyStrong),
          ],
        ],
      ),
    );
  }
}
