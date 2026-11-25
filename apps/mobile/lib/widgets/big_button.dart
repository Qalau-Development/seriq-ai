import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';

// ButtonKind — вид кнопки: главное действие, второстепенное, опасное, опасное на мягком фоне
enum ButtonKind { primary, secondary, danger, dangerSoft }

// BigButton — кнопка-таблетка на всю ширину по макету: от 56 px, подпись переносится
class BigButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final ButtonKind kind;
  final bool small;

  const BigButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.kind = ButtonKind.primary,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final Color bg;
    final Color fg;
    final Color border;
    switch (kind) {
      case ButtonKind.primary:
        bg = AppColors.accent;
        fg = AppColors.onAccent;
        border = AppColors.accent;
      case ButtonKind.secondary:
        bg = Colors.white;
        fg = AppColors.brand;
        border = AppColors.brand;
      case ButtonKind.danger:
        bg = AppColors.errorInk;
        fg = Colors.white;
        border = AppColors.errorInk;
      case ButtonKind.dangerSoft:
        bg = AppColors.errorSoft;
        fg = AppColors.errorInk;
        border = AppColors.errorLine;
    }
    final height = small ? AppSizes.touch : AppSizes.buttonHeight;
    return SizedBox(
      width: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          boxShadow: enabled && kind == ButtonKind.primary
              ? const [
                  BoxShadow(
                    color: Color(0x47F87C2C),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: enabled ? bg : AppColors.disabled,
          shape: StadiumBorder(
            side: BorderSide(
              color: enabled ? border : AppColors.disabled,
              width: 2,
            ),
          ),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onPressed,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: height - 4),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: small ? 20 : 24,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(
                        icon,
                        size: small ? 20 : 22,
                        color: enabled ? fg : AppColors.disabledInk,
                      ),
                      const SizedBox(width: 12),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: small ? 16 : 18,
                          height: small ? 20 / 16 : 22 / 18,
                          fontWeight: FontWeight.w700,
                          color: enabled ? fg : AppColors.disabledInk,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
