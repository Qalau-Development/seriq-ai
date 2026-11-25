import 'package:material_ui/material_ui.dart';

import '../../core/exercises.dart';
import '../../core/format.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../models/history_view.dart';
import '../../services/history_view.dart';
import '../../widgets/big_button.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/confirm_action.dart';
import '../../widgets/exercise_filter.dart';
import '../../widgets/page_shell.dart';
import '../../widgets/app_card.dart';
import '../../widgets/session_tile.dart';
import '../../widgets/sync_notice.dart';

// HistoryScreen — прошлые занятия с упражнением, датой и сводкой, фильтр, удаление занятия и очистка истории
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<SessionListItem>? _items;
  bool _offline = false;
  String? _filter;

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
                  onChanged: (v) => setState(() => _filter = v),
                ),
                const SizedBox(height: 20),
                if (shown!.isEmpty)
                  Text(
                    tr('history_filter_empty'),
                    style: AppText.body.copyWith(color: AppColors.muted),
                  ),
                for (final s in shown) ...[
                  SessionTile(
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
                  const SizedBox(height: 10),
                  ConfirmAction(
                    label: tr('delete_session'),
                    question: tr(account ? 'delete_session_confirm_account' : 'delete_session_confirm'),
                    yes: tr('clear_history_yes'),
                    icon: Icons.delete_outline_rounded,
                    onConfirm: () => historyView.removeOne(s.id),
                  ),
                  const SizedBox(height: 20),
                ],
                const SizedBox(height: 4),
                ConfirmAction(
                  label: tr('clear_history'),
                  question: tr(account ? 'clear_history_confirm_account' : 'clear_history_confirm'),
                  yes: tr('clear_history_yes'),
                  icon: Icons.delete_outline_rounded,
                  onConfirm: historyView.removeAll,
                ),
              ],
            ],
          ],
        );
      },
    );
  }
}
