import 'package:material_ui/material_ui.dart';

// BigButton — крупная кнопка на всю ширину для пожилых пользователей
class BigButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool primary;

  const BigButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.primary = true,
  });

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: 28), const SizedBox(width: 12)],
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ],
    );
    return SizedBox(
      width: double.infinity,
      child: primary
          ? FilledButton(onPressed: onPressed, child: child)
          : OutlinedButton(onPressed: onPressed, child: child),
    );
  }
}
