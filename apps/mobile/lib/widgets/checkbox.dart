import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';

// AppCheckbox — квадратный переключатель: контур brand, отмеченный залит brand с белой галочкой
class AppCheckbox extends StatelessWidget {
  final bool checked;
  final VoidCallback onTap;
  final String? semanticLabel;

  const AppCheckbox({
    super.key,
    required this.checked,
    required this.onTap,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: checked,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: checked ? AppColors.brand : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.brand, width: 2),
          ),
          child: checked
              ? const Icon(Icons.check_rounded, size: 20, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}
