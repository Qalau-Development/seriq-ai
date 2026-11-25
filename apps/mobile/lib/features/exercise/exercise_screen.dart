import 'package:material_ui/material_ui.dart';

import '../../core/exercises.dart';
import '../../core/routes.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/voice_items.dart';
import '../../services/catalog.dart';
import '../../widgets/app_card.dart';
import '../../widgets/big_button.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/instruction_clips_view.dart';
import '../../widgets/page_shell.dart';
import '../../widgets/speak_button.dart';

// ExerciseScreen — примеры съёмки, шаги, советы и переход к записи
class ExerciseScreen extends StatefulWidget {
  final String id;
  final bool fromSession;

  const ExerciseScreen({
    super.key,
    this.id = defaultExercise,
    this.fromSession = false,
  });

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen> {
  ExerciseDef get _def => exerciseDef(widget.id);

  @override
  void initState() {
    super.initState();
    if (catalog.value == null) refreshCatalog();
  }

  // _ready — переходит к занятию или возвращает в него
  void _ready() {
    if (widget.fromSession) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(
        context,
        '/session',
        arguments: ExerciseArgs(widget.id),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: appLang,
      builder: (context, lang, _) => ValueListenableBuilder(
        valueListenable: catalog,
        builder: (context, entries, _) {
          final def = _def;
          final state = exerciseAvailability(entries, def.id);
          return PageShell(
            tab: AppTab.home,
            children: [
              Text(
                '${tr(def.titleKey)}: ${tr('instruction_title').toLowerCase()}',
                style: AppText.title,
              ),
              const SizedBox(height: 20),
              SpeakButton(items: instructionItems(def)),
              const SizedBox(height: 20),
              InstructionClipsView(exerciseId: def.id),
              const SizedBox(height: 24),
              for (var i = 0; i < def.stepKeys.length; i++) ...[
                _StepTile(number: i + 1, text: tr(def.stepKeys[i])),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 10),
              _TipsCard(keys: def.tipKeys),
              const SizedBox(height: 20),
              if (state == 'ready')
                BigButton(
                  label: tr('ready'),
                  icon: Icons.play_arrow_outlined,
                  onPressed: _ready,
                )
              else if (state == 'soon') ...[
                MessageBox(text: tr('exercise_soon_hint')),
                const SizedBox(height: 12),
                BigButton(
                  label: tr('back_to_exercises'),
                  kind: ButtonKind.secondary,
                  onPressed: () => goTab(context, AppTab.home),
                ),
              ] else
                Text(tr('loading'), style: AppText.small),
            ],
          );
        },
      ),
    );
  }

}

// _StepTile — шаг инструкции: оранжевый кружок с тёмной цифрой и текст на белой плитке
class _StepTile extends StatelessWidget {
  final int number;
  final String text;

  const _StepTile({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.tileRadius),
        border: Border.all(color: AppColors.line),
        boxShadow: cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent,
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                fontSize: 22,
                height: 1,
                fontWeight: FontWeight.w800,
                color: AppColors.onAccent,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(text, style: AppText.body),
            ),
          ),
        ],
      ),
    );
  }
}

// _TipsCard — карточка «Как снимать»: иконка камеры, заголовок и советы с оранжевыми точками
class _TipsCard extends StatelessWidget {
  final List<String> keys;

  const _TipsCard({required this.keys});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.brandSoft,
                ),
                child: const Icon(
                  Icons.photo_camera_outlined,
                  color: AppColors.brand,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(tr('tips_title'), style: AppText.h2)),
            ],
          ),
          const SizedBox(height: 20),
          for (final key in keys)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 9),
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accentStrong,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Text(tr(key), style: AppText.body)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
