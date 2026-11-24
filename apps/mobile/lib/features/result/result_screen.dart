import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/strings.dart';
import '../../models/analysis_result.dart';
import '../../widgets/angle_chart.dart';
import '../../widgets/big_button.dart';
import '../../widgets/mock_badge.dart';
import '../../widgets/pose_video.dart';
import '../../widgets/verdict_card.dart';

// ResultScreen — результат одного повторения: итог, кнопки, график, уверенность
class ResultScreen extends StatelessWidget {
  final AnalysisResult result;
  final String? videoPath;

  const ResultScreen({super.key, required this.result, this.videoPath});

  @override
  Widget build(BuildContext context) {
    final cycle = result.mainCycle;
    final titleStyle = Theme.of(context).textTheme.titleLarge;
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
              label: cycle?.label ?? 'uncertain',
              maxAngle: result.angleSeries.maxValue,
            ),
            const SizedBox(height: 20),
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
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 20, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 8),
                      child: Text(tr('chart_title'), style: titleStyle),
                    ),
                    if (videoPath != null) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 16),
                        child: PoseVideo(
                            videoPath: videoPath!, pose: result.pose),
                      ),
                    ],
                    AngleChart(series: result.angleSeries),
                  ],
                ),
              ),
            ),
            if (hints.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('warnings_title'), style: titleStyle),
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
            if (cycle != null) ...[
              const SizedBox(height: 16),
              Text(
                '${tr('confidence_title')}: ${trConfidence(cycle.confidence)}',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (kDebugMode) ...[
              const SizedBox(height: 8),
              Text(
                'source: ${result.source} · model_version: ${result.modelVersion} · processing_ms: ${result.processingMs}',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
