import 'package:material_ui/material_ui.dart';

import '../../core/exercises.dart';
import '../../core/routes.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../services/api_client.dart';
import '../../services/catalog.dart';
import '../../widgets/big_button.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/page_shell.dart';
import 'exercise_card.dart';

// HomeScreen — главная: приветствие и библиотека из четырёх упражнений
class HomeScreen extends StatefulWidget {
  final ApiClient? api;

  const HomeScreen({super.key, this.api});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    refreshCatalog(widget.api);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: appLang,
      builder: (context, lang, _) => ValueListenableBuilder(
        valueListenable: catalog,
        builder: (context, entries, _) => PageShell(
          tab: AppTab.home,
          children: [
            const _Hero(),
            const SizedBox(height: 32),
            Text(tr('exercises_title'), style: AppText.title),
            const SizedBox(height: 8),
            Text(tr('exercises_hint'), style: AppText.small),
            const SizedBox(height: 20),
            for (final def in exercises) ...[
              ExerciseCard(
                def: def,
                state: exerciseAvailability(entries, def.id),
                onStart: () => Navigator.pushNamed(
                  context,
                  '/exercise',
                  arguments: ExerciseArgs(def.id),
                ),
              ),
              const SizedBox(height: 20),
            ],
            BigButton(
              label: tr('nav_history'),
              icon: Icons.history_rounded,
              kind: ButtonKind.secondary,
              onPressed: () => goTab(context, AppTab.history),
            ),
          ],
        ),
      ),
    );
  }
}

// _Hero — синяя карточка с названием SerIQ и описанием
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: Container(
        width: double.infinity,
        color: AppColors.brand,
        child: Stack(
          children: [
            Positioned(
              top: -50,
              right: -40,
              child: _Circle(150, color: AppColors.secondary),
            ),
            Positioned(
              bottom: -120,
              right: -70,
              child: _Circle(220, color: AppColors.link),
            ),
            Positioned(
              top: 34,
              right: 66,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.brandSoft2, width: 12),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SerIQ',
                    style: TextStyle(
                      fontSize: 56,
                      height: 60 / 56,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.12,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tr('app_tagline'),
                    style: const TextStyle(
                      fontSize: 20,
                      height: 30 / 20,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// _Circle — декоративный круг на синей карточке
class _Circle extends StatelessWidget {
  final double size;
  final Color color;

  const _Circle(this.size, {required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
