import 'package:material_ui/material_ui.dart';

import '../../core/exercises.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/big_button.dart';

// ExerciseCard — карточка упражнения в библиотеке: название, описание, что измеряем и кнопка или «Скоро»
class ExerciseCard extends StatelessWidget {
  final ExerciseDef def;
  final String state;
  final VoidCallback onStart;

  const ExerciseCard({
    super.key,
    required this.def,
    required this.state,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final lessReliable =
        lessReliableExercises.contains(def.id) &&
        Strings.ru.containsKey('exercise_less_reliable');
    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(def.titleKey), style: AppText.h2.copyWith(height: 29 / 24)),
          if (lessReliable) ...[
            const SizedBox(height: 10),
            const _LessReliableChip(),
          ],
          const SizedBox(height: 12),
          Text(tr(def.descKey), style: AppText.body),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.tile,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              tr(def.measuresKey),
              style: AppText.small.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 16),
          if (state == 'ready')
            Semantics(
              label: '${tr('start_session')}: ${tr(def.titleKey)}',
              excludeSemantics: true,
              button: true,
              child: BigButton(
                label: tr('start_session'),
                icon: Icons.play_arrow_outlined,
                onPressed: onStart,
              ),
            )
          else if (state == 'soon')
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 56),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.neutralSoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                tr('exercise_soon'),
                style: const TextStyle(
                  fontSize: 18,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  color: AppColors.neutralInk,
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 56),
              alignment: Alignment.center,
              child: Text(
                tr('loading'),
                style: AppText.bodyStrong.copyWith(color: AppColors.muted),
              ),
            ),
        ],
      ),
    );
  }
}

// _LessReliableChip — жёлтая пометка «Менее надёжно» у упражнения
class _LessReliableChip extends StatelessWidget {
  const _LessReliableChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.warnSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.warnLine, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: AppColors.warnInk,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              tr('exercise_less_reliable'),
              style: const TextStyle(
                fontSize: 14,
                height: 20 / 14,
                fontWeight: FontWeight.w700,
                color: AppColors.warnInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
