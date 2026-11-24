import 'package:material_ui/material_ui.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/big_button.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/page_shell.dart';

// HomeScreen — главный экран: приветствие, упражнение и история
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: appLang,
      builder: (context, lang, _) => PageShell(
        tab: AppTab.home,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.brand,
              borderRadius: BorderRadius.circular(AppSizes.cardRadius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SerIQ',
                  style: TextStyle(
                    fontSize: 44,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.88,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  tr('app_tagline'),
                  style: AppText.body.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(tr('exercises_title'), style: AppText.title),
          const SizedBox(height: 8),
          Text(tr('exercises_hint'), style: AppText.small),
          const SizedBox(height: 20),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('exercise_e02_title'), style: AppText.h2),
                const SizedBox(height: 8),
                Text(tr('exercise_e02_desc'), style: AppText.body),
                const SizedBox(height: 16),
                MessageBox(
                  text: tr('exercise_e02_measures'),
                  icon: Icons.straighten_rounded,
                ),
                const SizedBox(height: 16),
                BigButton(
                  label: tr('start_session'),
                  icon: Icons.play_arrow_outlined,
                  onPressed: () => Navigator.pushNamed(context, '/exercise'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          BigButton(
            label: tr('nav_history'),
            icon: Icons.history_rounded,
            kind: ButtonKind.secondary,
            onPressed: () => goTab(context, AppTab.history),
          ),
        ],
      ),
    );
  }
}
