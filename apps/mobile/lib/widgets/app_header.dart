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

// SerIqLogo — логотип SQ и надпись SerIQ
class SerIqLogo extends StatelessWidget {
  const SerIqLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'SerIQ',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/logo.png', height: 36),
            const SizedBox(width: 10),
            const Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Ser',
                    style: TextStyle(color: AppColors.brand),
                  ),
                  TextSpan(
                    text: 'IQ',
                    style: TextStyle(color: AppColors.accentStrong),
                  ),
                ],
              ),
              style: TextStyle(
                fontSize: 26,
                height: 1,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.52,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// LangSwitch — три сегмента ҚАЗ, РУС, ENG, выбранный залит синим
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
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.brand, width: 2),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final code in appLangs)
                Padding(
                  padding: EdgeInsets.only(left: code == appLangs.first ? 0 : 2),
                  child: Semantics(
                    button: true,
                    selected: code == lang,
                    child: Material(
                      color: code == lang ? AppColors.brand : Colors.transparent,
                      shape: const StadiumBorder(),
                      child: InkWell(
                        customBorder: const StadiumBorder(),
                        onTap: () => appLang.set(code),
                        child: Container(
                          constraints: const BoxConstraints(
                            minHeight: AppSizes.touch - 4,
                            minWidth: 48,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          alignment: Alignment.center,
                          child: Text(
                            _labels[code]!,
                            style: TextStyle(
                              fontSize: 17,
                              height: 1,
                              fontWeight: FontWeight.w700,
                              color: code == lang
                                  ? Colors.white
                                  : AppColors.brand,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
