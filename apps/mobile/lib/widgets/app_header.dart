import 'package:material_ui/material_ui.dart';

import '../core/strings.dart';
import '../core/theme.dart';

// AppHeader — верхняя панель: логотип слева, переключатель языка справа
class AppHeader extends StatelessWidget {
  const AppHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.pagePadding),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
            child: const SerIqLogo(),
          ),
          const LangSwitch(),
        ],
      ),
    );
  }
}

// SerIqLogo — логотип SerIQ
class SerIqLogo extends StatelessWidget {
  const SerIqLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'SerIQ',
      child: ExcludeSemantics(
        child: Image.asset('assets/logo.png', height: 36),
      ),
    );
  }
}

// LangSwitch — компактная кнопка с активным языком, список остальных выпадает вниз
class LangSwitch extends StatelessWidget {
  const LangSwitch({super.key});

  static const _labels = {'kk': 'ҚАЗ', 'ru': 'РУС', 'en': 'ENG'};

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: appLang,
      builder: (context, lang, _) => Semantics(
        container: true,
        label: tr('lang_label'),
        child: PopupMenuButton<String>(
          tooltip: '',
          offset: const Offset(0, 44),
          padding: EdgeInsets.zero,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.brand, width: 2),
          ),
          onSelected: (code) => appLang.set(code),
          itemBuilder: (context) => [
            for (final code in appLangs)
              PopupMenuItem<String>(
                value: code,
                height: 40,
                child: Text(
                  _labels[code]!,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: code == lang ? AppColors.brand : AppColors.ink,
                  ),
                ),
              ),
          ],
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.brand, width: 2),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _labels[lang]!,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brand,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.keyboard_arrow_down,
                  size: 18,
                  color: AppColors.brand,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
