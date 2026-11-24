import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';

// AppCard — белая карточка с рамкой и тенью по макету, радиус 28
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color color;
  final Color borderColor;
  final double borderWidth;
  final bool shadow;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.radius = AppSizes.cardRadius,
    this.color = AppColors.surface,
    this.borderColor = AppColors.line,
    this.borderWidth = 1,
    this.shadow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: shadow ? cardShadow : null,
      ),
      child: child,
    );
  }
}

// MessageKind — вид сообщения: пояснение, предупреждение, ошибка
enum MessageKind { info, warn, error }

// MessageBox — сообщение с иконкой, рамкой и текстом; цвет не единственный признак
class MessageBox extends StatelessWidget {
  final String text;
  final MessageKind kind;
  final IconData? icon;

  const MessageBox({
    super.key,
    required this.text,
    this.kind = MessageKind.info,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color ink;
    final Color line;
    final double width;
    final FontWeight weight;
    final IconData defaultIcon;
    switch (kind) {
      case MessageKind.info:
        bg = AppColors.neutralSoft;
        ink = AppColors.neutralInk;
        line = AppColors.brandSoft2;
        width = 1;
        weight = FontWeight.w500;
        defaultIcon = Icons.info_outline_rounded;
      case MessageKind.warn:
        bg = AppColors.warnSoft;
        ink = AppColors.warnInk;
        line = AppColors.warnLine;
        width = 2;
        weight = FontWeight.w700;
        defaultIcon = Icons.warning_amber_rounded;
      case MessageKind.error:
        bg = AppColors.errorSoft;
        ink = AppColors.errorInk;
        line = AppColors.errorLine;
        width = 2;
        weight = FontWeight.w700;
        defaultIcon = Icons.error_outline_rounded;
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSizes.messageRadius),
        border: Border.all(color: line, width: width),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon ?? defaultIcon, color: ink, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppText.body.copyWith(color: ink, fontWeight: weight),
            ),
          ),
        ],
      ),
    );
  }
}

// FilterChipButton — кнопка-фильтр: выбранная — синяя заливка с галочкой
class FilterChipButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  const FilterChipButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.brand : Colors.white,
        shape: const StadiumBorder(
          side: BorderSide(color: AppColors.brand, width: 2),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSizes.touch),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selected) ...[
                    const Icon(Icons.check_rounded, size: 20, color: Colors.white),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 18,
                      height: 1.2,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      color: selected ? Colors.white : AppColors.brand,
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
