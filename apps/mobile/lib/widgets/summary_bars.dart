import 'package:material_ui/material_ui.dart';

import '../core/strings.dart';
import '../core/theme.dart';
import '../models/history_view.dart';
import 'app_card.dart';

// SummaryBars — карточка «Результаты повторений»: сколько повторений каждого исхода, полоска и доля (если нужна); exercise = null — для всех упражнений
class SummaryBars extends StatelessWidget {
  final SessionCounts summary;
  final String? exercise;
  final bool showShare;
  final String? title;

  const SummaryBars({
    super.key,
    required this.summary,
    required this.exercise,
    this.showShare = false,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    final rows = [
      (
        tr('label_complete'),
        summary.complete,
        AppColors.accentStrong,
      ),
      (
        exercise == 'E02'
            ? tr('label_incomplete')
            : (exercise == null
                  ? tr('label_incomplete_generic')
                  : tr('verdict_check_instructions')),
        summary.incomplete,
        AppColors.brand,
      ),
      (tr('label_uncertain'), summary.uncertain, AppColors.lineStrong),
    ];
    return AppCard(
      padding: const EdgeInsets.all(20),
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title ?? tr('summary_chart_title'), style: AppText.h3),
          const SizedBox(height: 20),
          for (final (text, value, color) in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(
                          text,
                          style: AppText.body.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '$value',
                        style: const TextStyle(
                          fontSize: 26,
                          height: 1,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      if (showShare && summary.total > 0)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            '· ${(value / summary.total * 100).round()}%',
                            style: AppText.small.copyWith(height: 1),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Container(
                      height: 18,
                      width: double.infinity,
                      color: AppColors.track,
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: summary.total == 0 ? 0 : value / summary.total,
                        child: Container(
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
