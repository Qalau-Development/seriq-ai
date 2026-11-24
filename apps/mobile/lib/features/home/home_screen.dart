import 'package:material_ui/material_ui.dart';

import '../../core/strings.dart';
import '../../widgets/big_button.dart';

// HomeScreen — главный экран: упражнение, начало занятия, история, язык
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: appLang,
      builder: (context, lang, _) {
        final scheme = Theme.of(context).colorScheme;
        final text = Theme.of(context).textTheme;
        return Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('SerIQ',
                          style: TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.w800,
                              color: scheme.primary)),
                    ),
                    SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(value: 'kk', label: Text(tr('lang_kk'))),
                        ButtonSegment(value: 'ru', label: Text(tr('lang_ru'))),
                      ],
                      selected: {lang},
                      onSelectionChanged: (s) => appLang.set(s.first),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(tr('app_tagline')),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Icon(Icons.back_hand_outlined,
                            size: 56, color: scheme.primary),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(tr('exercise_e02_title'),
                                  style: text.headlineSmall),
                              const SizedBox(height: 6),
                              Text(tr('exercise_e02_desc')),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                BigButton(
                  label: tr('start_session'),
                  icon: Icons.play_arrow_rounded,
                  onPressed: () => Navigator.pushNamed(context, '/exercise'),
                ),
                const SizedBox(height: 12),
                BigButton(
                  label: tr('nav_history'),
                  icon: Icons.history_rounded,
                  primary: false,
                  onPressed: () => Navigator.pushNamed(context, '/history'),
                ),
                const SizedBox(height: 32),
                Text(tr('disclaimer'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 15, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        );
      },
    );
  }
}
