import 'package:material_ui/material_ui.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../models/history_view.dart';
import '../../models/progress.dart';
import '../../services/history_view.dart';
import '../../widgets/activity_calendar.dart';
import '../../widgets/app_card.dart';
import '../../widgets/big_button.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/exercise_filter.dart';
import '../../widgets/measure_bars.dart';
import '../../widgets/page_shell.dart';
import '../../widgets/summary_bars.dart';
import '../../widgets/sync_notice.dart';

// ProgressScreen — «Мой прогресс»: счёт повторений, доли исходов, дни с занятиями и измеренные значения; только факты, без оценок
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  ProgressSummary? _summary;
  bool _failed = false;
  String? _filter;

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

  // _load — считает счёт по занятиям на устройстве
  Future<void> _load() async {
    final r = await historyView.progress(_filter);
    if (mounted) {
      setState(() {
        _summary = r.summary;
        _failed = r.failed;
      });
    }
  }

  // _setFilter — выбирает упражнение и пересчитывает счёт
  void _setFilter(String? v) {
    _filter = v;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    return ValueListenableBuilder<String>(
      valueListenable: appLang,
      builder: (context, lang, _) => PageShell(
        tab: AppTab.progress,
        children: [
          Text(tr('progress_title'), style: AppText.title),
          const SizedBox(height: 20),
          const SyncNotice(),
          ExerciseFilter(value: _filter, onChanged: _setFilter),
          const SizedBox(height: 20),
          if (_failed) ...[
            MessageBox(text: tr('progress_load_failed')),
            const SizedBox(height: 20),
          ],
          if (summary == null)
            Text(tr('loading'), style: AppText.body)
          else if (summary.repetitions == 0) ...[
            Text(
              tr('progress_empty'),
              style: AppText.bodyStrong.copyWith(
                fontSize: 22,
                height: 33 / 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            BigButton(
              label: tr('start_session'),
              icon: Icons.play_arrow_outlined,
              onPressed: () => goTab(context, AppTab.home),
            ),
          ] else
            ..._content(summary),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 24),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.line)),
            ),
            child: Text(
              tr('progress_disclaimer'),
              style: AppText.bodyStrong.copyWith(
                fontWeight: FontWeight.w600,
                height: 27 / 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // _content — счёт, доли, календарь и значения выбранного упражнения
  List<Widget> _content(ProgressSummary s) {
    final counts = SessionCounts(
      s.repetitions,
      s.labels['complete'] ?? 0,
      s.labels['incomplete'] ?? 0,
      s.labels['uncertain'] ?? 0,
    );
    final points = [
      for (var i = 0; i < s.points.length; i++) ValuePoint(i + 1, s.points[i].value),
    ];
    return [
      Text(
        trFill('progress_done_line', {'n': s.repetitions}),
        style: AppText.title.copyWith(fontSize: 26, height: 31 / 26),
      ),
      const SizedBox(height: 20),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _Stat(tr('progress_sessions'), s.sessions)),
          const SizedBox(width: 16),
          Expanded(child: _Stat(tr('progress_repetitions'), s.repetitions)),
        ],
      ),
      const SizedBox(height: 20),
      SummaryBars(
        summary: counts,
        exercise: _filter,
        showShare: true,
        title: tr('progress_shares_title'),
      ),
      const SizedBox(height: 20),
      ActivityCalendar(
        activity: s.activity,
        utcOffsetMinutes: localUtcOffsetMinutes(),
      ),
      const SizedBox(height: 20),
      if (_filter == null)
        Text(
          tr('progress_choose_exercise'),
          style: AppText.body.copyWith(color: AppColors.muted),
        )
      else
        MeasureBars(points: points, measure: s.measure),
    ];
  }
}

// _Stat — плитка с числом: занятий или повторений
class _Stat extends StatelessWidget {
  final String label;
  final int value;

  const _Stat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppText.bodyStrong.copyWith(
              color: AppColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 48,
              height: 60 / 48,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
