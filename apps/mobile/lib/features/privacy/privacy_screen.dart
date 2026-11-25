import 'package:material_ui/material_ui.dart';

import '../../core/privacy.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/big_button.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/page_shell.dart';

// PrivacyScreen — «Данные и приватность»: что хранится у гостя и у вошедшего, что не хранится, как удалить данные
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PageShell(
      tab: AppTab.home,
      children: [
        Text(tr('privacy_title'), style: AppText.title),
        const SizedBox(height: 24),
        for (final s in privacySections) ...[
          AppCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr(s.titleKey), style: AppText.h2),
                for (final k in s.textKeys) ...[
                  const SizedBox(height: 10),
                  Text(
                    tr(k),
                    style: AppText.body.copyWith(height: 29 / 18),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        BigButton(
          label: tr('go_home'),
          kind: ButtonKind.secondary,
          onPressed: () => goTab(context, AppTab.home),
        ),
      ],
    );
  }
}
