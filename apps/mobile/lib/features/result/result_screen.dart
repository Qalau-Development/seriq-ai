import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../models/analysis_result.dart';
import '../../widgets/angle_chart.dart';
import '../../widgets/app_card.dart';
import '../../widgets/big_button.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/mock_badge.dart';
import '../../widgets/page_shell.dart';
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
    final hints = result.warnings
        .map((w) => 'warning_$w')
        .where(Strings.ru.containsKey)
        .toList();
    return PageShell(
      tab: AppTab.home,
      children: [
        Text(tr('session_title'), style: AppText.title),
        const SizedBox(height: 4),
        Text(
          tr('exercise_e02_title'),
          style: AppText.bodyStrong.copyWith(color: AppColors.link),
        ),
        const SizedBox(height: 20),
        if (result.isMock) ...[
          MockBadge(text: tr('mock_badge')),
          const SizedBox(height: 16),
        ],
        VerdictCard(
          label: cycle?.label ?? 'uncertain',
          maxAngle: result.measure?.value,
        ),
        const SizedBox(height: 16),
        BigButton(
          label: tr('another_attempt'),
          icon: Icons.replay_rounded,
          onPressed: () => Navigator.pop(context),
        ),
        const SizedBox(height: 12),
        BigButton(
          label: tr('watch_instruction'),
          kind: ButtonKind.secondary,
          onPressed: () =>
              Navigator.pushNamed(context, '/exercise', arguments: true),
        ),
        const SizedBox(height: 24),
        if (videoPath != null) ...[
          AppCard(
            padding: const EdgeInsets.all(20),
            radius: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('pose_title'), style: AppText.h3),
                const SizedBox(height: 12),
                PoseVideo(videoPath: videoPath!, pose: result.pose),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        AppCard(
          padding: const EdgeInsets.all(20),
          radius: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('chart_title'), style: AppText.h3),
              const SizedBox(height: 12),
              if (result.measure != null)
                AngleChart(series: result.measure!.series),
            ],
          ),
        ),
        if (hints.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(tr('warnings_title'), style: AppText.h3),
          const SizedBox(height: 8),
          for (final h in hints) ...[
            MessageBox(text: tr(h), icon: Icons.videocam_outlined),
            const SizedBox(height: 8),
          ],
        ],
        if (cycle != null) ...[
          const SizedBox(height: 16),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            radius: AppSizes.tileRadius,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${tr('confidence_title')}:',
                    style: AppText.smallStrong,
                  ),
                ),
                Text(trConfidence(cycle.confidence), style: AppText.bodyStrong),
              ],
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
    );
  }
}
