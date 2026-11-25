import 'package:material_ui/material_ui.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/big_button.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/page_shell.dart';

// SystemCard — карточка страницы «Страница не найдена» и «Что-то пошло не так» на фоне из цветных кругов
class SystemCard extends StatelessWidget {
  final String title;
  final String text;
  final List<Widget> actions;

  const SystemCard({
    super.key,
    required this.title,
    required this.text,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          right: -60,
          top: 30,
          child: _Blob(160, AppColors.accentSoft),
        ),
        Positioned(
          left: -70,
          bottom: -90,
          child: _Blob(220, AppColors.brandSoft),
        ),
        Positioned(
          right: 4,
          top: -40,
          child: _Blob(56, AppColors.accent),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 40),
          child: AppCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.title),
                const SizedBox(height: 16),
                Text(
                  text,
                  style: AppText.body.copyWith(
                    color: AppColors.muted,
                    fontSize: 20,
                    height: 30 / 20,
                  ),
                ),
                const SizedBox(height: 24),
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  actions[i],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// _Blob — декоративный круг
class _Blob extends StatelessWidget {
  final double size;
  final Color color;

  const _Blob(this.size, this.color);

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}

// NotFoundScreen — «Страница не найдена»: понятная фраза и кнопка «На главную»
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PageShell(
      tab: AppTab.home,
      children: [
        SystemCard(
          title: tr('not_found_title'),
          text: tr('not_found_text'),
          actions: [
            BigButton(
              label: tr('go_home'),
              icon: Icons.home_outlined,
              onPressed: () => goTab(context, AppTab.home),
            ),
          ],
        ),
      ],
    );
  }
}

// ErrorScreen — «Что-то пошло не так»: без технических подробностей, кнопки «Попробовать снова» и «На главную»
class ErrorScreen extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback onHome;

  const ErrorScreen({super.key, required this.onRetry, required this.onHome});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.page,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.pagePadding),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizes.contentMaxWidth,
              ),
              child: SystemCard(
                title: tr('error_page_title'),
                text: tr('error_page_text'),
                actions: [
                  BigButton(
                    label: tr('try_again'),
                    icon: Icons.replay_rounded,
                    onPressed: onRetry,
                  ),
                  BigButton(
                    label: tr('go_home'),
                    icon: Icons.home_outlined,
                    kind: ButtonKind.secondary,
                    onPressed: onHome,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
