import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/strings.dart';
import '../../models/session.dart';
import '../../widgets/big_button.dart';
import '../../widgets/mock_badge.dart';

// SummaryScreen — итоги занятия: сколько повторений и с каким результатом
class SummaryScreen extends StatelessWidget {
  final Session session;

  const SummaryScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final time = DateFormat('HH:mm');
    return Scaffold(
      appBar: AppBar(title: Text(tr('summary_title'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (session.hasMock) ...[
              MockBadge(text: tr('summary_has_mock')),
              const SizedBox(height: 16),
            ],
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(DateFormat('dd.MM.yyyy, HH:mm')
                        .format(session.startedAt.toLocal())),
                    const SizedBox(height: 8),
                    Text('${tr('summary_total')}: ${session.total}',
                        style: text.headlineSmall),
                    const SizedBox(height: 20),
                    Text(tr('summary_chart_title'), style: text.titleLarge),
                    const SizedBox(height: 12),
                    _Bar(
                      label: tr('label_complete'),
                      count: session.completeCount,
                      total: session.total,
                      color: scheme.primary,
                    ),
                    _Bar(
                      label: tr('label_incomplete'),
                      count: session.incompleteCount,
                      total: session.total,
                      color: scheme.onSurfaceVariant,
                    ),
                    _Bar(
                      label: tr('label_uncertain'),
                      count: session.uncertainCount,
                      total: session.total,
                      color: scheme.outline,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(tr('summary_attempts'), style: text.titleLarge),
            const SizedBox(height: 8),
            for (var i = 0; i < session.attempts.length; i++)
              Card(
                child: ListTile(
                  leading: Icon(
                    session.attempts[i].verdict == 'completed'
                        ? Icons.check_circle_rounded
                        : Icons.info_outline_rounded,
                    color: session.attempts[i].verdict == 'completed'
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                    size: 32,
                  ),
                  title: Text(
                      '${tr('attempt_n')} ${i + 1}: ${tr('verdict_${session.attempts[i].verdict}')}'),
                  subtitle: Text(
                      '${tr('label_${session.attempts[i].label}')} · ${time.format(session.attempts[i].at.toLocal())}'),
                ),
              ),
            const SizedBox(height: 24),
            BigButton(
              label: tr('new_session'),
              icon: Icons.add_rounded,
              onPressed: () => Navigator.pushNamedAndRemoveUntil(
                  context, '/exercise', (r) => r.isFirst),
            ),
            const SizedBox(height: 12),
            BigButton(
              label: tr('nav_home'),
              icon: Icons.home_outlined,
              primary: false,
              onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
            ),
          ],
        ),
      ),
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
              Expanded(child: Text(label)),
              Text('$count',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : count / total,
              minHeight: 16,
              color: color,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}
