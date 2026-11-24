import 'package:material_ui/material_ui.dart';

import '../core/strings.dart';
import '../core/theme.dart';

// AppTab — разделы нижней панели
enum AppTab { home, history, progress, account }

// _TabInfo — маршрут, подпись и иконки раздела
class _TabInfo {
  final String route;
  final String labelKey;
  final IconData icon;
  final IconData iconSelected;

  const _TabInfo(this.route, this.labelKey, this.icon, this.iconSelected);
}

const _tabs = {
  AppTab.home: _TabInfo('/', 'nav_home', Icons.home_outlined, Icons.home_rounded),
  AppTab.history: _TabInfo(
    '/history',
    'nav_history',
    Icons.history_rounded,
    Icons.history_rounded,
  ),
  AppTab.progress: _TabInfo(
    '/progress',
    'nav_progress',
    Icons.bar_chart_rounded,
    Icons.bar_chart_rounded,
  ),
  AppTab.account: _TabInfo(
    '/login',
    'nav_login',
    Icons.login_rounded,
    Icons.login_rounded,
  ),
};

// activeTabs — какие разделы показывает нижняя панель сейчас
final activeTabs = ValueNotifier<List<AppTab>>([AppTab.home, AppTab.history]);

// goTab — переходит в раздел нижней панели, в стеке остаётся главная
void goTab(BuildContext context, AppTab tab) {
  final route = _tabs[tab]!.route;
  final nav = Navigator.of(context);
  if (route == '/') {
    nav.popUntil((r) => r.isFirst);
  } else {
    nav.pushNamedAndRemoveUntil(route, (r) => r.isFirst);
  }
}

// BottomNav — нижняя панель: 96 px, скруглённый верх, выбранный раздел с заливкой
class BottomNav extends StatelessWidget {
  final AppTab? selected;

  const BottomNav({super.key, this.selected});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: appLang,
      builder: (context, _, _) => ValueListenableBuilder<List<AppTab>>(
        valueListenable: activeTabs,
        builder: (context, tabs, _) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.line)),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Color(0x1A114A7D),
                blurRadius: 24,
                offset: Offset(0, -6),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 10),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppSizes.contentMaxWidth,
                    minHeight: 80,
                  ),
                  child: Row(
                    children: [
                      for (final tab in tabs)
                        Expanded(
                          child: _NavItem(
                            info: _tabs[tab]!,
                            selected: tab == selected,
                            onTap: () => goTab(context, tab),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// _NavItem — один раздел панели: иконка и подпись до двух строк
class _NavItem extends StatelessWidget {
  final _TabInfo info;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.info,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: Material(
          color: selected ? AppColors.brandSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 72),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    selected ? info.iconSelected : info.icon,
                    size: 24,
                    color: selected ? AppColors.brand : AppColors.ink,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tr(info.labelKey),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: TextStyle(
                      fontSize: 16,
                      height: 19 / 16,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      color: selected ? AppColors.brand : AppColors.ink,
                    ),
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
