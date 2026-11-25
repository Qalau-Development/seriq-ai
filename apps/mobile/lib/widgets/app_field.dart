import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';

// AppField — поле ввода по макету: подпись сверху, высота 56, рамка 2 px, пояснение снизу
class AppField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;
  final bool obscure;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final Key? fieldKey;
  final FocusNode? focusNode;

  const AppField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.fieldKey,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.bodyStrong),
        const SizedBox(height: 8),
        SizedBox(
          height: AppSizes.buttonHeight,
          child: TextField(
            key: fieldKey,
            controller: controller,
            focusNode: focusNode,
            obscureText: obscure,
            keyboardType: keyboardType,
            autofillHints: autofillHints,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.none,
            textInputAction: textInputAction,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            inputFormatters: [LengthLimitingTextInputFormatter(128)],
            style: AppText.body.copyWith(height: 1),
            decoration: const InputDecoration(),
          ),
        ),
        if (hint != null) ...[
          const SizedBox(height: 8),
          Text(hint!, style: AppText.small),
        ],
      ],
    );
  }
}
