import 'package:material_ui/material_ui.dart';

import '../core/measure_text.dart';
import '../core/strings.dart';
import '../core/theme.dart';

// ResultMark — круглая отметка результата: «выполнено» оранжевая с галочкой, остальные синие
class ResultMark extends StatelessWidget {
  final String label;
  final double size;

  const ResultMark({super.key, required this.label, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final done = label == 'complete';
    final IconData icon = switch (label) {
      'complete' => Icons.check_rounded,
      'incomplete' => Icons.replay_rounded,
      _ => Icons.question_mark_rounded,
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? AppColors.accent : AppColors.brand,
      ),
      child: Icon(
        icon,
        size: size * 0.55,
        color: done ? AppColors.onAccent : Colors.white,
      ),
    );
  }
}

// AttemptTile — плитка повторения: номер и время, итог, уверенность оценки
class AttemptTile extends StatelessWidget {
  final int number;
  final String time;
  final String label;
  final String exercise;
  final double confidence;

  const AttemptTile({
    super.key,
    required this.number,
    required this.time,
    required this.label,
    required this.exercise,
    required this.confidence,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.tileRadius),
        border: Border.all(color: AppColors.line),
        boxShadow: cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ResultMark(label: label),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${tr('attempt_n')} $number · $time',
                  style: AppText.smallStrong.copyWith(height: 22 / 16),
                ),
                const SizedBox(height: 2),
                Text(resultTitle(label, exercise), style: AppText.bodyStrong),
                const SizedBox(height: 2),
                Text(
                  '${tr('confidence_title')}: ${trConfidence(confidence)}',
                  style: AppText.small,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
