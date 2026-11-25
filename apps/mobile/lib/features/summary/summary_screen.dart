import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../models/session.dart';
import '../../widgets/app_card.dart';
import '../../widgets/attempt_tile.dart';
import '../../widgets/big_button.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/mock_badge.dart';
import '../../widgets/page_shell.dart';

// SummaryScreen — итоги занятия: сколько повторений и с каким результатом
class SummaryScreen extends StatelessWidget {
  final Session session;

  const SummaryScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm');
    return PageShell(
      tab: AppTab.history,
      children: [
        Text(tr('summary_title'), style: AppText.title),
        const SizedBox(height: 16),
        if (session.hasMock) ...[
          MockBadge(text: tr('summary_has_mock')),
          const SizedBox(height: 16),
        ],
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('dd.MM.yyyy, HH:mm').format(session.startedAt.toLocal()),
                style: AppText.small,
              ),
              const SizedBox(height: 8),
              Text(
                '${tr('summary_total')}: ${session.total}',
                style: AppText.h2,
              ),
              const SizedBox(height: 20),
              Text(tr('summary_chart_title'), style: AppText.h3),
              const SizedBox(height: 12),
              _Bar(
                label: tr('label_complete'),
                count: session.completeCount,
                total: session.total,
                color: AppColors.brand,
              ),
              _Bar(
                label: tr('label_incomplete'),
                count: session.incompleteCount,
                total: session.total,
                color: AppColors.brand,
              ),
              _Bar(
                label: tr('label_uncertain'),
                count: session.uncertainCount,
                total: session.total,
                color: AppColors.brand,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(tr('summary_attempts'), style: AppText.h2),
        const SizedBox(height: 12),
        for (var i = 0; i < session.attempts.length; i++) ...[
          AttemptTile(
            number: i + 1,
            time: time.format(session.attempts[i].at.toLocal()),
            label: session.attempts[i].label,
            exercise: session.exercise,
            confidence: session.attempts[i].confidence,
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 12),
        BigButton(
          label: tr('new_session'),
          icon: Icons.add_rounded,
          onPressed: () => Navigator.pushNamedAndRemoveUntil(
            context,
            '/exercise',
            (r) => r.isFirst,
          ),
        ),
        const SizedBox(height: 12),
        BigButton(
          label: tr('nav_home'),
          icon: Icons.home_outlined,
          kind: ButtonKind.secondary,
          onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
        ),
      ],
    );
  }
}

// _Bar — строка простой диаграммы: подпись, число и полоса
class _Bar extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;

  const _Bar({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: AppText.body)),
              Text('$count', style: AppText.h3),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : count / total,
              minHeight: 16,
              color: color,
              backgroundColor: AppColors.brandSoft,
            ),
          ),
        ],
      ),
    );
  }
}
