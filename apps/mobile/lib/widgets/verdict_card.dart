import 'package:material_ui/material_ui.dart';

import '../core/measure_text.dart';
import '../core/theme.dart';
import '../models/analysis_result.dart';
import 'attempt_tile.dart';

// VerdictCard — крупный итог повторения по метке и измеренное значение
class VerdictCard extends StatelessWidget {
  final AnalysisResult result;

  const VerdictCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final raw = result.mainCycle?.label ?? 'uncertain';
    final label = const {'complete', 'incomplete', 'uncertain'}.contains(raw)
        ? raw
        : 'uncertain';
    final done = label == 'complete';
    final lines = resultLines(result, label);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: done ? AppColors.accentSoft : AppColors.neutralSoft,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        border: Border.all(
          color: done ? AppColors.accentLine : AppColors.brandSoft2,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ResultMark(label: label, size: 64),
          const SizedBox(height: 12),
          Text(
            resultTitle(label, result.exercise),
            style: AppText.title.copyWith(
              color: done ? AppColors.ink : AppColors.neutralInk,
            ),
          ),
          if (lines.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              lines.first,
              style: AppText.bodyStrong.copyWith(fontSize: 20, height: 30 / 20),
            ),
            for (final l in lines.skip(1)) ...[
              const SizedBox(height: 8),
              Text(
                l,
                style: AppText.body.copyWith(color: AppColors.neutralInk),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
