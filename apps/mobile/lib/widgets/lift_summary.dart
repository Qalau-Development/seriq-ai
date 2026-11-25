import 'package:material_ui/material_ui.dart';

import '../core/lift_stats.dart';
import '../core/measure_text.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../models/analysis_result.dart';
import '../models/session.dart';
import '../services/history_storage.dart';

// signedValue — число со знаком и разделителем языка: +0,4 или −0,2
String signedValue(double value) {
  if (value == 0) return localNum('0.0');
  return '${value > 0 ? '+' : '−'}${localNum(value.abs().toStringAsFixed(1))}';
}

// liftHistory — попытки E01 на устройстве, кроме этой: только того же источника (настоящие с настоящими, тестовые с тестовыми)
List<LiftAttempt> liftHistory(List<Session> sessions, AnalysisResult result) => [
  for (final s in sessions)
    if (s.exercise == 'E01')
      for (final a in s.attempts)
        if (a.analysisId != result.analysisId && a.source == result.source)
          LiftAttempt(a.at, a.measure?.value, riseTime(a.measure?.series)),
];

// LiftSummary — E01: время подъёма, разница с прошлой попыткой и лучший результат по истории на устройстве
class LiftSummary extends StatefulWidget {
  final AnalysisResult result;
  final HistoryStorage? storage;

  const LiftSummary({super.key, required this.result, this.storage});

  @override
  State<LiftSummary> createState() => _LiftSummaryState();
}

class _LiftSummaryState extends State<LiftSummary> {
  List<Session>? _sessions;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // _load — читает занятия с устройства
  Future<void> _load() async {
    final all = await (widget.storage ?? HistoryStorage()).loadSessions();
    if (mounted) setState(() => _sessions = all);
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final measure = result.measure;
    final sessions = _sessions;
    if (result.exercise != 'E01' ||
        measure == null ||
        measure.name != 'lift_height' ||
        measure.value == null ||
        sessions == null) {
      return const SizedBox.shrink();
    }
    final riseS = riseTime(measure.series);
    final own = sessions
        .expand((s) => s.attempts)
        .where((a) => a.analysisId == result.analysisId)
        .firstOrNull;
    final current = LiftAttempt(own?.at ?? DateTime.now(), measure.value, riseS);
    final cmp = compareWithHistory(current, liftHistory(sessions, result));
    final unit = tr('chart_unit_hand_lengths');
    final prev = cmp.previous;
    final vs = prev == null
        ? tr('lift_first')
        : [
            if (prev.valueDelta != null)
              trFill('lift_vs_previous_value', {
                'd': signedValue(prev.valueDelta!),
                'unit': unit,
              }),
            if (prev.riseDelta != null)
              trFill('lift_vs_previous_time', {'d': signedValue(prev.riseDelta!)}),
          ].join(' ');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.neutralSoft,
        borderRadius: BorderRadius.circular(AppSizes.messageRadius),
        border: Border.all(color: AppColors.brandSoft2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('lift_title'),
            style: AppText.h2.copyWith(color: AppColors.neutralInk),
          ),
          if (riseS != null) ...[
            const SizedBox(height: 12),
            _line(Icons.timer_outlined, trFill('lift_rise_time', {'s': decimal(riseS)})),
          ],
          const SizedBox(height: 12),
          _line(Icons.trending_up_rounded, vs),
          if (cmp.best != null && prev != null) ...[
            const SizedBox(height: 12),
            Text(
              cmp.isBest
                  ? tr('lift_is_best')
                  : trFill('lift_best', {'n': decimal(cmp.best!), 'unit': unit}),
              style: AppText.bodyStrong.copyWith(
                color: AppColors.neutralInk,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (result.pose != null) ...[
            const SizedBox(height: 12),
            Text(
              tr('lift_line_hint'),
              style: AppText.small.copyWith(color: AppColors.neutralInk),
            ),
          ],
          const SizedBox(height: 12),
          Text(tr('lift_note'), style: AppText.small),
        ],
      ),
    );
  }

  // _line — строка с иконкой
  Widget _line(IconData icon, String text) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Icon(icon, color: AppColors.neutralInk, size: 24),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          text,
          style: AppText.body.copyWith(color: AppColors.neutralInk),
        ),
      ),
    ],
  );
}
