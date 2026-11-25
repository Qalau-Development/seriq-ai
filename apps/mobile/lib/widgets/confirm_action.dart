import 'package:material_ui/material_ui.dart';

import '../core/strings.dart';
import '../core/theme.dart';
import 'big_button.dart';

// ConfirmAction — кнопка действия с крупным подтверждением; если действие не удалось, показывает ошибку и оставляет подтверждение открытым
class ConfirmAction extends StatefulWidget {
  final String label;
  final String question;
  final String yes;
  final IconData? icon;
  final Future<void> Function() onConfirm;
  final ButtonKind kind;
  final bool enabled;

  const ConfirmAction({
    super.key,
    required this.label,
    required this.question,
    required this.yes,
    required this.onConfirm,
    this.icon,
    this.kind = ButtonKind.secondary,
    this.enabled = true,
  });

  @override
  State<ConfirmAction> createState() => _ConfirmActionState();
}

class _ConfirmActionState extends State<ConfirmAction> {
  bool _open = false;
  bool _busy = false;
  bool _failed = false;

  // _confirm — выполняет действие и закрывает подтверждение
  Future<void> _confirm() async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await widget.onConfirm();
      if (mounted) setState(() => _open = false);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_open) {
      return BigButton(
        label: widget.label,
        icon: widget.icon,
        kind: widget.kind,
        small: true,
        onPressed: widget.enabled ? () => setState(() => _open = true) : null,
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.errorSoft,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.errorLine, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.question,
            style: AppText.bodyStrong.copyWith(
              color: AppColors.errorInk,
              height: 27 / 18,
            ),
          ),
          if (_failed) ...[
            const SizedBox(height: 12),
            Text(
              tr('delete_failed'),
              style: AppText.bodyStrong.copyWith(color: AppColors.errorInk),
            ),
          ],
          const SizedBox(height: 16),
          BigButton(
            label: widget.yes,
            kind: ButtonKind.danger,
            onPressed: _busy ? null : _confirm,
          ),
          const SizedBox(height: 12),
          BigButton(
            label: tr('clear_history_no'),
            kind: ButtonKind.secondary,
            onPressed: _busy ? null : () => setState(() => _open = false),
          ),
        ],
      ),
    );
  }
}
