import 'package:material_ui/material_ui.dart';

import '../../core/strings.dart';
import '../../models/analysis_result.dart';
import '../../widgets/angle_chart.dart';
import '../../widgets/big_button.dart';
import '../../widgets/mock_badge.dart';
import '../../widgets/verdict_card.dart';

// ResultScreen — результат анализа одного повторения
class ResultScreen extends StatelessWidget {
  final AnalysisResult result;

  const ResultScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final cycle = result.mainCycle;
    final hints = result.warnings
        .map((w) => 'warning_$w')
        .where(Strings.ru.containsKey)
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(tr('result_title'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (result.isMock) ...[
              MockBadge(text: tr('mock_badge')),
              const SizedBox(height: 16),
            ],
            VerdictCard(
              verdict: result.verdict,
              label: cycle?.label ?? 'uncertain',
              confidence: cycle?.confidence ?? 0,
            ),
            if (hints.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('warnings_title'),
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      for (final h in hints)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.videocam_outlined, size: 26),
                              const SizedBox(width: 10),
                              Expanded(child: Text(tr(h))),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 20, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 12),
                      child: Text(tr('chart_title'),
                          style: Theme.of(context).textTheme.titleLarge),
                    ),
                    AngleChart(series: result.angleSeries),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            BigButton(
              label: tr('another_attempt'),
              icon: Icons.replay_rounded,
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(height: 12),
            BigButton(
              label: tr('watch_instruction'),
              icon: Icons.play_circle_outline_rounded,
              primary: false,
              onPressed: () =>
                  Navigator.pushNamed(context, '/exercise', arguments: true),
            ),
          ],
        ),
      ),
    );
  }
}
