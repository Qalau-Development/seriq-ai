import 'package:material_ui/material_ui.dart';

import '../core/strings.dart';
import '../core/theme.dart';
import '../services/history_view.dart';
import 'big_button.dart';

// MigratePrompt — после входа: если на устройстве есть гостевая история, спрашивает, перенести ли её в аккаунт; заодно отправляет неотправленное
class MigratePrompt extends StatefulWidget {
  final HistoryView? view;

  const MigratePrompt({super.key, this.view});

  @override
  State<MigratePrompt> createState() => _MigratePromptState();
}

class _MigratePromptState extends State<MigratePrompt> {
  int _count = 0;
  bool _working = false;
  ({int moved, int left})? _done;
  String? _lastUser;

  HistoryView get _view => widget.view ?? historyView;

  @override
  void initState() {
    super.initState();
    _view.changes.addListener(_refresh);
    _refresh();
  }

  @override
  void dispose() {
    _view.changes.removeListener(_refresh);
    super.dispose();
  }

  // _refresh — считает, сколько гостевых занятий можно перенести; для вошедшего заодно отправляет неотправленное
  Future<void> _refresh() async {
    final mode = _view.mode;
    final user = mode.userId;
    if (mode.kind != AccountModeKind.account || user == null) {
      _lastUser = null;
      if (mounted && _count != 0) setState(() => _count = 0);
      return;
    }
    if (_lastUser != user) {
      _lastUser = user;
      _view.sync.syncNow();
    }
    final declined = await _view.sync.isMigrationDeclined(user);
    final n = declined ? 0 : await _view.sync.guestMigratableCount();
    if (mounted && n != _count) setState(() => _count = n);
  }

  // _accept — переносит гостевые занятия в аккаунт и показывает итог
  Future<void> _accept() async {
    setState(() => _working = true);
    final result = await _view.sync.migrateGuestSessions();
    if (mounted) {
      setState(() {
        _working = false;
        _done = result;
        _count = 0;
      });
    }
  }

  // _decline — запоминает отказ от переноса
  Future<void> _decline() async {
    final user = _view.mode.userId;
    if (user != null) await _view.sync.declineMigration(user);
    if (mounted) setState(() => _count = 0);
  }

  @override
  Widget build(BuildContext context) {
    final done = _done;
    if (done != null) {
      return _Banner(
        text: [
          Text(
            trFill('migrate_done', {'n': done.moved}),
            style: AppText.h2.copyWith(fontSize: 22, height: 29 / 22),
          ),
          if (done.left > 0)
            Text(
              trFill('migrate_left', {'n': done.left}),
              style: AppText.body,
            ),
        ],
        actions: [
          BigButton(
            label: 'OK',
            kind: ButtonKind.secondary,
            onPressed: () => setState(() => _done = null),
          ),
        ],
      );
    }
    if (_count == 0) return const SizedBox.shrink();
    return _Banner(
      text: [
        Text(
          tr('migrate_question'),
          style: AppText.h2.copyWith(fontSize: 22, height: 29 / 22),
        ),
        Text(tr('migrate_note'), style: AppText.body),
        Text(trFill('migrate_count', {'n': _count}), style: AppText.bodyStrong),
      ],
      actions: [
        BigButton(
          label: tr(_working ? 'migrate_working' : 'migrate_yes'),
          onPressed: _working ? null : _accept,
        ),
        BigButton(
          label: tr('migrate_no'),
          kind: ButtonKind.secondary,
          onPressed: _working ? null : _decline,
        ),
      ],
    );
  }
}

// _Banner — заметный блок над содержимым: иконка, тексты и кнопки в столбик
class _Banner extends StatelessWidget {
  final List<Widget> text;
  final List<Widget> actions;

  const _Banner({required this.text, required this.actions});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.neutralSoft,
          borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          border: Border.all(color: AppColors.brandSoft2, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.brand,
              ),
              child: const Icon(Icons.cloud_upload_outlined, color: Colors.white),
            ),
            const SizedBox(height: 14),
            for (var i = 0; i < text.length; i++) ...[
              if (i > 0) const SizedBox(height: 6),
              text[i],
            ],
            const SizedBox(height: 16),
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              actions[i],
            ],
          ],
        ),
      ),
    );
  }
}
