import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';

// SessionTile — плитка занятия: упражнение, дата, сколько выполнено и стрелка перехода
class SessionTile extends StatelessWidget {
  final String exercise;
  final String date;
  final String done;
  final VoidCallback onTap;
  final String semanticLabel;
  final bool white;

  const SessionTile({
    super.key,
    required this.exercise,
    required this.date,
    required this.done,
    required this.onTap,
    this.semanticLabel = '',
    this.white = true,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel.isEmpty ? null : '$semanticLabel: $exercise, $date, $done',
      excludeSemantics: semanticLabel.isNotEmpty,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.tileRadius),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 112),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: white ? Colors.white : AppColors.tile,
            borderRadius: BorderRadius.circular(AppSizes.tileRadius),
            border: Border.all(color: AppColors.line, width: 2),
            boxShadow: white ? cardShadow : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise,
                      style: AppText.smallStrong.copyWith(
                        color: AppColors.link,
                        height: 22 / 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(date, style: AppText.bodyStrong),
                    const SizedBox(height: 3),
                    Text(done, style: AppText.small.copyWith(height: 22 / 16)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: white ? AppColors.brandSoft : Colors.white,
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.brand,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
