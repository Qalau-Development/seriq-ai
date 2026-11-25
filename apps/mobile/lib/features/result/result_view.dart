import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/lift_stats.dart';
import '../../core/measure_text.dart';
import '../../core/routes.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../models/analysis_result.dart';
import '../../widgets/app_card.dart';
import '../../widgets/big_button.dart';
import '../../widgets/lift_summary.dart';
import '../../widgets/measure_chart.dart';
import '../../widgets/mock_badge.dart';
import '../../widgets/pose_video.dart';
import '../../widgets/speak_button.dart';
import '../../widgets/verdict_card.dart';

// ResultView — результат одного повторения: итог, кнопки, видео с точками кисти, график, уверенность и подсказки по съёмке
class ResultView extends StatelessWidget {
  final AnalysisResult result;
  final String? videoPath;
  final VoidCallback? onAnother;

  const ResultView({
    super.key,
    required this.result,
    this.videoPath,
    this.onAnother,
  });

  // _spoken — что читать вслух: итог и строки под ним
  String _spoken() {
    final raw = result.mainCycle?.label ?? 'uncertain';
    final label = const {'complete', 'incomplete', 'uncertain'}.contains(raw) ? raw : 'uncertain';
    return [resultTitle(label, result.exercise), ...resultLines(result, label)].join('. ');
  }

  @override
  Widget build(BuildContext context) {
    final cycle = result.mainCycle;
    final pose = result.pose;
    final measure = result.measure;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (result.isMock) ...[
          MockBadge(text: tr('mock_badge')),
          const SizedBox(height: 16),
        ],
        VerdictCard(result: result),
        const SizedBox(height: 16),
        BigButton(
          label: tr('another_attempt'),
          icon: Icons.replay_rounded,
          onPressed: onAnother ?? () => Navigator.pop(context),
        ),
        const SizedBox(height: 12),
        SpeakButton(text: _spoken()),
        const SizedBox(height: 12),
        BigButton(
          label: tr('watch_instruction'),
          kind: ButtonKind.secondary,
          onPressed: () => Navigator.pushNamed(
            context,
            '/exercise',
            arguments: ExerciseArgs(result.exercise, fromSession: true),
          ),
        ),
        const SizedBox(height: 24),
        if (videoPath != null && pose != null) ...[
          AppCard(
            padding: const EdgeInsets.all(20),
            radius: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('pose_title'), style: AppText.h3),
                const SizedBox(height: 12),
                PoseVideo(
                  videoPath: videoPath!,
                  pose: pose,
                  liftStart: result.exercise == 'E01' ? liftStart(pose) : null,
                ),
                const SizedBox(height: 12),
                Text(
                  tr(pose.elbow != null ? 'pose_hint' : 'pose_hint_hand'),
                  style: AppText.small,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (measure != null && measure.series.values.isNotEmpty) ...[
          AppCard(
            padding: const EdgeInsets.all(20),
            radius: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('chart_title'), style: AppText.h3),
                const SizedBox(height: 12),
                MeasureChart(measure: measure, cycle: cycle),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        LiftSummary(result: result),
        if (result.exercise == 'E01') const SizedBox(height: 16),
        if (cycle != null) ...[
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
          const SizedBox(height: 16),
        ],
        if (result.warnings.isNotEmpty) _Warnings(result: result),
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

// _Warnings — нейтральные подсказки по съёмке из warnings
class _Warnings extends StatelessWidget {
  final AnalysisResult result;

  const _Warnings({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.neutralSoft,
        borderRadius: BorderRadius.circular(AppSizes.messageRadius),
        border: Border.all(color: AppColors.brandSoft2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: AppColors.neutralInk,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tr('warnings_title'),
                  style: AppText.bodyStrong.copyWith(color: AppColors.neutralInk),
                ),
              ),
            ],
          ),
          for (final code in result.warnings)
            Padding(
              padding: const EdgeInsets.only(left: 36, top: 4),
              child: Text(
                trForExercise(
                  'warning_$code',
                  result.exercise,
                  'warning_arm_not_visible',
                ),
                style: AppText.body.copyWith(color: AppColors.neutralInk),
              ),
            ),
        ],
      ),
    );
  }
}
