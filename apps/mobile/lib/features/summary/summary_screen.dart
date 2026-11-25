import 'package:material_ui/material_ui.dart';

import '../../core/exercises.dart';
import '../../core/format.dart';
import '../../core/routes.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../models/history_view.dart';
import '../../models/session.dart';
import '../../services/history_storage.dart';
import '../../widgets/app_card.dart';
import '../../widgets/attempt_tile.dart';
import '../../widgets/big_button.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/confirm_action.dart';
import '../../widgets/measure_bars.dart';
import '../../widgets/mock_badge.dart';
import '../../widgets/page_shell.dart';
import '../../widgets/summary_bars.dart';

// SummaryScreen — итоги занятия по его id: сводка по меткам, значения по повторениям, список повторений
class SummaryScreen extends StatefulWidget {
  final String id;

  const SummaryScreen({super.key, required this.id});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  final _storage = HistoryStorage();
  bool _loaded = false;
  Session? _session;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // _load — читает занятие с устройства
  Future<void> _load() async {
    final s = await _storage.loadSession(widget.id);
    if (mounted) {
      setState(() {
        _session = s;
        _loaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: appLang,
      builder: (context, lang, _) {
        if (!_loaded) {
          return PageShell(
            tab: AppTab.history,
            children: [Text(tr('loading'), style: AppText.body)],
          );
        }
        final session = _session;
        if (session == null) return _notFound(context);
        return _content(context, session);
      },
    );
  }

  // _notFound — занятие не найдено: пояснение и кнопка «История»
  Widget _notFound(BuildContext context) {
    return PageShell(
      tab: AppTab.history,
      children: [
        AppCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('summary_not_found'),
                style: AppText.h3.copyWith(fontSize: 22, height: 31 / 22),
              ),
              const SizedBox(height: 24),
              BigButton(
                label: tr('nav_history'),
                icon: Icons.history_rounded,
                kind: ButtonKind.secondary,
                onPressed: () => goTab(context, AppTab.history),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // _content — итоги найденного занятия
  Widget _content(BuildContext context, Session session) {
    final counts = toListItem(session).summary;
    final values = attemptPoints(session.attempts);
    return PageShell(
      tab: AppTab.history,
      children: [
        Text(tr('summary_title'), style: AppText.title),
        const SizedBox(height: 6),
        Text(
          tr(exerciseDef(session.exercise).titleKey),
          style: AppText.bodyStrong.copyWith(
            color: AppColors.link,
            fontSize: 22,
            height: 30 / 22,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          formatDateTime(session.startedAt),
          style: AppText.body.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: AppColors.brand,
            borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  tr('summary_total'),
                  style: const TextStyle(
                    fontSize: 20,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                '${counts.total}',
                style: const TextStyle(
                  fontSize: 56,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (session.hasMock) ...[
          MockBadge(text: tr('summary_has_mock')),
          const SizedBox(height: 20),
        ],
        SummaryBars(summary: counts, exercise: session.exercise),
        if (values.points.isNotEmpty) ...[
          const SizedBox(height: 20),
          MeasureBars(points: values.points, measure: values.measure),
        ],
        const SizedBox(height: 28),
        Text(tr('summary_attempts'), style: AppText.h2),
        const SizedBox(height: 16),
        for (var i = 0; i < session.attempts.length; i++) ...[
          AttemptTile(
            number: i + 1,
            time: formatTime(session.attempts[i].at),
            label: session.attempts[i].label,
            exercise: session.exercise,
            confidence: session.attempts[i].confidence,
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 8),
        BigButton(
          label: tr('new_session'),
          icon: Icons.play_arrow_outlined,
          onPressed: () => Navigator.pushNamedAndRemoveUntil(
            context,
            '/exercise',
            (r) => r.isFirst,
            arguments: ExerciseArgs(session.exercise),
          ),
        ),
        const SizedBox(height: 12),
        BigButton(
          label: tr('nav_history'),
          icon: Icons.history_rounded,
          kind: ButtonKind.secondary,
          onPressed: () => goTab(context, AppTab.history),
        ),
        const SizedBox(height: 12),
        ConfirmAction(
          label: tr('delete_session'),
          question: tr('delete_session_confirm'),
          yes: tr('clear_history_yes'),
          icon: Icons.delete_outline_rounded,
          onConfirm: () async {
            await _storage.deleteSession(session.id);
            if (context.mounted) goTab(context, AppTab.history);
          },
        ),
      ],
    );
  }
}
