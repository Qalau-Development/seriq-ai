import 'package:material_ui/material_ui.dart';

import '../../core/exercises.dart';
import '../../core/format.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../models/history_view.dart';
import '../../services/history_view.dart';
import '../../widgets/big_button.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/checkbox.dart';
import '../../widgets/confirm_action.dart';
import '../../widgets/exercise_filter.dart';
import '../../widgets/page_shell.dart';
import '../../widgets/app_card.dart';
import '../../widgets/session_tile.dart';
import '../../widgets/sync_notice.dart';

// HistoryScreen — прошлые занятия с упражнением, датой и сводкой, фильтр, выбор нескольких и удаление
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<SessionListItem>? _items;
  bool _offline = false;
  String? _filter;
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    historyView.changes.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    historyView.changes.removeListener(_load);
    super.dispose();
  }

  // _load — читает историю с устройства
  Future<void> _load() async {
    final r = await historyView.list();
    if (mounted) {
      setState(() {
        _items = r.items;
        _offline = r.offline;
      });
    }
  }

  // _toggleOne — добавляет или убирает одно занятие из выбранных
  void _toggleOne(String id) {
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  // _toggleAll — выбирает все показанные занятия или снимает выбор
  void _toggleAll(List<SessionListItem> shown, bool allSelected) {
    setState(() {
      _selected.clear();
      if (!allSelected) _selected.addAll(shown.map((s) => s.id));
    });
  }

  // _removeSelected — удаляет выбранные занятия по одному
  Future<void> _removeSelected() async {
    for (final id in _selected.toList()) {
      await historyView.removeOne(id);
      _selected.remove(id);
    }
    if (mounted) setState(() {});
  }

  // _removeAll — очищает всю историю и выбор
  Future<void> _removeAll() async {
    await historyView.removeAll();
    if (mounted) setState(_selected.clear);
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final account = historyView.mode.kind == AccountModeKind.account;
    return ValueListenableBuilder<String>(
      valueListenable: appLang,
      builder: (context, lang, _) {
        final shown = items
            ?.where((s) => _filter == null || s.exercise == _filter)
            .toList();
        final allSelected =
            shown != null &&
            shown.isNotEmpty &&
            shown.every((s) => _selected.contains(s.id));
        return PageShell(
          tab: AppTab.history,
          children: [
            Text(tr('history_title'), style: AppText.title),
            const SizedBox(height: 8),
            if (items == null)
              Text(tr('loading'), style: AppText.body)
            else ...[
              Text(
                items.isEmpty
                    ? tr(account ? 'history_empty_account' : 'history_empty')
                    : tr(account ? 'history_account_note' : 'history_local_note'),
                style: AppText.body.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 20),
              if (_offline) ...[
                MessageBox(text: tr('history_offline_note')),
                const SizedBox(height: 16),
              ],
              const SyncNotice(),
              if (items.isEmpty)
                BigButton(
                  label: tr('start_session'),
                  icon: Icons.play_arrow_outlined,
                  onPressed: () => goTab(context, AppTab.home),
                )
              else ...[
                ExerciseFilter(
                  value: _filter,
                  onChanged: (v) => setState(() {
                    _filter = v;
                    _selected.clear();
                  }),
                ),
                const SizedBox(height: 20),
                if (shown!.isEmpty)
                  Text(
                    tr('history_filter_empty'),
                    style: AppText.body.copyWith(color: AppColors.muted),
                  ),
                if (shown.isNotEmpty) ...[
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            AppCheckbox(
                              checked: allSelected,
                              semanticLabel: tr('history_select_all'),
                              onTap: () => _toggleAll(shown, allSelected),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                tr('history_select_all'),
                                style: AppText.bodyStrong,
                              ),
                            ),
                            if (_selected.isNotEmpty)
                              Text(
                                trFill('history_selected_count', {
                                  'count': _selected.length,
                                }),
                                style: AppText.smallStrong,
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ConfirmAction(
                          label: tr('delete_selected'),
                          question: tr(
                            account
                                ? 'delete_selected_confirm_account'
                                : 'delete_selected_confirm',
                          ),
                          yes: tr('clear_history_yes'),
                          icon: Icons.delete_outline_rounded,
                          kind: ButtonKind.dangerSoft,
                          enabled: _selected.isNotEmpty,
                          onConfirm: _removeSelected,
                        ),
                        const SizedBox(height: 12),
                        ConfirmAction(
                          label: tr('clear_history'),
                          question: tr(
                            account
                                ? 'clear_history_confirm_account'
                                : 'clear_history_confirm',
                          ),
                          yes: tr('clear_history_yes'),
                          icon: Icons.delete_outline_rounded,
                          onConfirm: _removeAll,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                for (final s in shown) ...[
                  Row(
                    children: [
                      AppCheckbox(
                        checked: _selected.contains(s.id),
                        semanticLabel:
                            '${tr(exerciseDef(s.exercise).titleKey)}, ${formatDateTime(s.startedAt)}',
                        onTap: () => _toggleOne(s.id),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SessionTile(
                          semanticLabel: tr('open_summary'),
                          exercise: tr(exerciseDef(s.exercise).titleKey),
                          date: formatDateTime(s.startedAt),
                          done: trFill('history_completed_count', {
                            'done': s.summary.complete,
                            'total': s.summary.total,
                          }),
                          onTap: () => Navigator.pushNamed(
                            context,
                            '/summary',
                            arguments: s.id,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ],
          ],
        );
      },
    );
  }
}
