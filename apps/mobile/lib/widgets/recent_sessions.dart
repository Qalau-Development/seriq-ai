import 'package:material_ui/material_ui.dart';

import '../core/exercises.dart';
import '../core/format.dart';
import '../core/routes.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../models/history_view.dart';
import '../services/history_view.dart';
import 'app_card.dart';
import 'big_button.dart';
import 'bottom_nav.dart';
import 'session_tile.dart';

// RecentSessions — на главной: до трёх последних занятий, кнопка «Начать занятие» и ссылка на всю историю; без истории блока нет
class RecentSessions extends StatefulWidget {
  final List<CatalogEntry>? catalog;

  const RecentSessions({super.key, required this.catalog});

  @override
  State<RecentSessions> createState() => _RecentSessionsState();
}

class _RecentSessionsState extends State<RecentSessions> {
  List<SessionListItem> _items = const [];

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

  // _load — читает последние занятия с устройства
  Future<void> _load() async {
    final r = await historyView.list();
    if (mounted) setState(() => _items = r.items ?? const []);
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();
    final last = _items.first.exercise;
    final ready = exerciseAvailability(widget.catalog, last) == 'ready';
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: AppCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('recent_title'), style: AppText.h2),
            const SizedBox(height: 20),
            for (final s in _items.take(3)) ...[
              SessionTile(
                white: false,
                semanticLabel: tr('open_summary'),
                exercise: tr(exerciseDef(s.exercise).titleKey),
                date: formatDateTime(s.startedAt),
                done: trFill('history_completed_count', {
                  'done': s.summary.complete,
                  'total': s.summary.total,
                }),
                onTap: () =>
                    Navigator.pushNamed(context, '/summary', arguments: s.id),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 8),
            if (ready) ...[
              BigButton(
                label: tr('start_session'),
                icon: Icons.play_arrow_outlined,
                onPressed: () => Navigator.pushNamed(
                  context,
                  '/exercise',
                  arguments: ExerciseArgs(last),
                ),
              ),
              const SizedBox(height: 12),
            ],
            BigButton(
              label: tr('recent_all'),
              kind: ButtonKind.secondary,
              onPressed: () => goTab(context, AppTab.history),
            ),
          ],
        ),
      ),
    );
  }
}
