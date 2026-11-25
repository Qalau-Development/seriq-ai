import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../models/progress.dart';
import 'app_card.dart';

// calendarDays — сколько последних дней показывает календарь
const calendarDays = 28;

// ActivityCalendar — последние 28 дней: закрашены дни с повторениями; под сеткой список таких дней
class ActivityCalendar extends StatelessWidget {
  final List<ActivityDay> activity;
  final int utcOffsetMinutes;
  final DateTime? now;

  const ActivityCalendar({
    super.key,
    required this.activity,
    required this.utcOffsetMinutes,
    this.now,
  });

  @override
  Widget build(BuildContext context) {
    final byDay = {for (final a in activity) a.date: a};
    final days = recentDays(calendarDays, utcOffsetMinutes, now);
    final active = days.where(byDay.containsKey).toList().reversed.toList();
    return AppCard(
      padding: const EdgeInsets.all(20),
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('progress_days_title'), style: AppText.h3),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1,
            children: [
              for (final d in days)
                Semantics(
                  label: byDay[d] == null
                      ? formatDay(d)
                      : trFill('progress_day_label', {
                          'date': formatDay(d),
                          'n': byDay[d]!.repetitions,
                        }),
                  excludeSemantics: true,
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: byDay[d] == null ? AppColors.tile : AppColors.brand,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '${int.parse(d.substring(8))}',
                      style: TextStyle(
                        fontSize: 18,
                        height: 1,
                        fontWeight: byDay[d] == null ? FontWeight.w600 : FontWeight.w800,
                        color: byDay[d] == null ? AppColors.muted : Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(tr('progress_days_hint'), style: AppText.small),
          if (active.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final d in active.take(7))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  trFill('progress_day_label', {
                    'date': formatDay(d),
                    'n': byDay[d]!.repetitions,
                  }),
                  style: AppText.body,
                ),
              ),
          ],
        ],
      ),
    );
  }
}
