import 'package:material_ui/material_ui.dart';

import '../core/exercises.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import 'app_card.dart';

// ExerciseFilter — фильтр упражнения: подпись и кнопки «Все» и четыре упражнения; null — все
class ExerciseFilter extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;

  const ExerciseFilter({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('history_filter_label'),
          style: AppText.bodyStrong.copyWith(color: AppColors.muted, height: 26 / 18),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilterChipButton(
              label: tr('history_filter_all'),
              selected: value == null,
              onPressed: () => onChanged(null),
            ),
            for (final e in exercises)
              FilterChipButton(
                label: tr(e.titleKey),
                selected: value == e.id,
                onPressed: () => onChanged(e.id),
              ),
          ],
        ),
      ],
    );
  }
}
