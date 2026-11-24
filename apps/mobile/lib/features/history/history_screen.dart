import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../models/session.dart';
import '../../services/history_storage.dart';
import '../../widgets/big_button.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/page_shell.dart';

// HistoryScreen — прошлые занятия, сохранённые на устройстве
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _storage = HistoryStorage();
  List<Session>? _sessions;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // _load — читает историю с устройства
  Future<void> _load() async {
    final sessions = await _storage.loadSessions();
    if (mounted) setState(() => _sessions = sessions);
  }

  // _clear — спрашивает подтверждение и удаляет историю
  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(tr('clear_history_confirm'), style: AppText.body),
        actionsAlignment: MainAxisAlignment.center,
        actionsOverflowDirection: VerticalDirection.down,
        actions: [
          BigButton(
            label: tr('clear_history_yes'),
            kind: ButtonKind.danger,
            onPressed: () => Navigator.pop(context, true),
          ),
          BigButton(
            label: tr('clear_history_no'),
            kind: ButtonKind.secondary,
            onPressed: () => Navigator.pop(context, false),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _storage.clearAll();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessions = _sessions;
    final date = DateFormat('dd.MM.yyyy, HH:mm');
    return PageShell(
      tab: AppTab.history,
      children: [
        Text(tr('history_title'), style: AppText.title),
        const SizedBox(height: 8),
        if (sessions == null)
          Text(tr('loading'), style: AppText.body)
        else ...[
          Text(
            tr(sessions.isEmpty ? 'history_empty' : 'history_local_note'),
            style: AppText.small,
          ),
          const SizedBox(height: 16),
          for (final s in sessions) ...[
            InkWell(
              borderRadius: BorderRadius.circular(AppSizes.tileRadius),
              onTap: () =>
                  Navigator.pushNamed(context, '/summary', arguments: s),
              child: Container(
                constraints: const BoxConstraints(minHeight: 112),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppSizes.tileRadius),
                  border: Border.all(color: AppColors.line, width: 2),
                  boxShadow: cardShadow,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr('exercise_e02_title'),
                            style: AppText.smallStrong.copyWith(
                              color: AppColors.link,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            date.format(s.startedAt.toLocal()),
                            style: AppText.bodyStrong,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            trFill('history_completed_count', {
                              'done': s.completeCount,
                              'total': s.total,
                            }),
                            style: AppText.small,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.brandSoft,
                      ),
                      child: const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.brand,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (sessions.isNotEmpty) ...[
            const SizedBox(height: 12),
            BigButton(
              label: tr('clear_history'),
              icon: Icons.delete_outline_rounded,
              kind: ButtonKind.secondary,
              small: true,
              onPressed: _clear,
            ),
          ],
        ],
      ],
    );
  }
}
