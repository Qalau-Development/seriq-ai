import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/strings.dart';
import '../../models/session.dart';
import '../../services/history_storage.dart';
import '../../widgets/big_button.dart';

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
        content: Text(tr('clear_history_confirm'),
            style: const TextStyle(fontSize: 20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('clear_history_no')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('clear_history_yes')),
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
    return Scaffold(
      appBar: AppBar(title: Text(tr('history_title'))),
      body: SafeArea(
        child: sessions == null
            ? Center(child: Text(tr('loading')))
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(tr(sessions.isEmpty ? 'history_empty' : 'history_local_note')),
                  const SizedBox(height: 16),
                  for (final s in sessions)
                    Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        title: Text(date.format(s.startedAt.toLocal()),
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w700)),
                        subtitle: Text(
                          tr('history_completed_count')
                              .replaceAll('{done}', '${s.completeCount}')
                              .replaceAll('{total}', '${s.total}'),
                          style: const TextStyle(fontSize: 18),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded, size: 32),
                        onTap: () =>
                            Navigator.pushNamed(context, '/summary', arguments: s),
                      ),
                    ),
                  if (sessions.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    BigButton(
                      label: tr('clear_history'),
                      icon: Icons.delete_outline_rounded,
                      primary: false,
                      onPressed: _clear,
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
