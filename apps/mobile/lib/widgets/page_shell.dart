import 'package:material_ui/material_ui.dart';

import '../core/strings.dart';
import '../core/theme.dart';
import 'app_header.dart';
import 'bottom_nav.dart';

// PageShell — страница с шапкой, прокручиваемым содержимым до 720 px, подвалом и нижней панелью
class PageShell extends StatelessWidget {
  final List<Widget> children;
  final AppTab? tab;
  final bool footer;

  const PageShell({
    super.key,
    required this.children,
    this.tab,
    this.footer = true,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: appLang,
      builder: (context, _, _) => Scaffold(
        backgroundColor: AppColors.page,
        body: Column(
          children: [
            const ColoredBox(
              color: Colors.white,
              child: SafeArea(bottom: false, child: AppHeader()),
            ),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: AppSizes.contentMaxWidth,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSizes.pagePadding,
                            24,
                            AppSizes.pagePadding,
                            24,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: children,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (footer)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: const AppFooter(),
                      ),
                    ),
                ],
              ),
            ),
            BottomNav(selected: tab),
          ],
        ),
      ),
    );
  }
}

// AppFooter — ссылки подвала и пометка, что SerIQ не медицинское изделие
class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        8,
        AppSizes.pagePadding,
        20,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSizes.contentMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FooterLink(
                label: tr('footer_instructions'),
                onTap: () => goTab(context, AppTab.home),
              ),
              FooterLink(
                label: tr('nav_history'),
                onTap: () => goTab(context, AppTab.history),
              ),
              const SizedBox(height: 8),
              Text(tr('disclaimer'), style: AppText.small),
            ],
          ),
        ),
      ),
    );
  }
}

// FooterLink — ссылка подвала с подчёркиванием, цель касания 48 px
class FooterLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const FooterLink({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: AppSizes.touch),
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.brand,
            decoration: TextDecoration.underline,
            decorationColor: AppColors.brand,
          ),
        ),
      ),
    );
  }
}
