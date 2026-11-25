import '../core/exercises.dart';
import 'session.dart';

// ActivityDay — день с занятиями: сколько занятий и повторений
class ActivityDay {
  final String date;
  final int sessions;
  final int repetitions;

  const ActivityDay(this.date, this.sessions, this.repetitions);
}

// ProgressPoint — измеренное значение одного повторения
class ProgressPoint {
  final DateTime at;
  final double value;
  final String label;

  const ProgressPoint(this.at, this.value, this.label);
}

// ProgressSummary — счёт повторений: занятия, исходы, доли, дни с занятиями и значения; не оценка восстановления
class ProgressSummary {
  final String? exercise;
  final int sessions;
  final int repetitions;
  final Map<String, int> labels;
  final Map<String, double>? shares;
  final List<ActivityDay> activity;
  final ({String name, String unit})? measure;
  final List<ProgressPoint> points;

  const ProgressSummary({
    required this.exercise,
    required this.sessions,
    required this.repetitions,
    required this.labels,
    required this.shares,
    required this.activity,
    required this.measure,
    required this.points,
  });

  // fromJson — ответ GET /progress/summary; points и measure бывают null, если упражнение не выбрано
  factory ProgressSummary.fromJson(Map<String, dynamic> j) {
    final labels = {
      'complete': 0,
      'incomplete': 0,
      'uncertain': 0,
      ...((j['labels'] as Map?)?.cast<String, int>() ?? {}),
    };
    final shares = (j['shares'] as Map?)?.map(
      (k, v) => MapEntry(k as String, (v as num).toDouble()),
    );
    final m = j['measure'] as Map?;
    return ProgressSummary(
      exercise: j['exercise'] as String?,
      sessions: (j['sessions'] as num?)?.toInt() ?? 0,
      repetitions: (j['repetitions'] as num?)?.toInt() ?? 0,
      labels: labels,
      shares: shares,
      activity: [
        for (final a in (j['activity'] as List? ?? []))
          ActivityDay(
            a['date'] as String,
            (a['sessions'] as num).toInt(),
            (a['repetitions'] as num).toInt(),
          ),
      ],
      measure: m == null
          ? null
          : (name: m['name'] as String, unit: m['unit'] as String),
      points: [
        for (final p in (j['points'] as List? ?? []))
          ProgressPoint(
            DateTime.parse(p['at'] as String),
            (p['value'] as num).toDouble(),
            p['label'] as String,
          ),
      ],
    );
  }
}

const _activityDays = 90;
const _maxPoints = 100;

// dayKey — дата YYYY-MM-DD момента времени в часовом поясе со сдвигом в минутах от UTC
String dayKey(DateTime t, int utcOffsetMinutes) => t
    .toUtc()
    .add(Duration(minutes: utcOffsetMinutes))
    .toIso8601String()
    .substring(0, 10);

// recentDays — последние N дней по порядку, до сегодняшнего включительно, в часовом поясе со сдвигом
List<String> recentDays(int count, int utcOffsetMinutes, [DateTime? now]) {
  final n = (now ?? DateTime.now()).toUtc();
  return [
    for (var i = 0; i < count; i++)
      dayKey(n.subtract(Duration(days: count - 1 - i)), utcOffsetMinutes),
  ];
}

// localUtcOffsetMinutes — сдвиг часового пояса устройства от UTC в минутах (UTC+5 = 300)
int localUtcOffsetMinutes() => DateTime.now().timeZoneOffset.inMinutes;

// computeProgress — счёт повторений по занятиям на устройстве в том же виде, что отдаёт сервер (GET /progress/summary)
ProgressSummary computeProgress(
  List<Session> sessions,
  String? exercise,
  int utcOffsetMinutes, [
  DateTime? now,
]) {
  final chosen = sessions
      .where(
        (s) => (exercise == null || s.exercise == exercise) && s.attempts.isNotEmpty,
      )
      .toList();
  final labels = {'complete': 0, 'incomplete': 0, 'uncertain': 0};
  final days = <String, ({Set<String> sessions, int repetitions})>{};
  final all = <ProgressPoint>[];
  final oldest = dayKey(
    (now ?? DateTime.now()).subtract(const Duration(days: _activityDays - 1)),
    utcOffsetMinutes,
  );
  for (final s in chosen) {
    for (final a in s.attempts) {
      labels[a.label] = (labels[a.label] ?? 0) + 1;
      final day = dayKey(a.at, utcOffsetMinutes);
      final entry = days[day] ?? (sessions: <String>{}, repetitions: 0);
      entry.sessions.add(s.id);
      days[day] = (sessions: entry.sessions, repetitions: entry.repetitions + 1);
      final v = a.measure?.value;
      if (exercise != null && v != null) all.add(ProgressPoint(a.at, v, a.label));
    }
  }
  final repetitions = labels.values.fold(0, (a, b) => a + b);
  double share(int n) => (n / repetitions * 10000).round() / 10000;
  final def = exercise == null ? null : exerciseDef(exercise);
  all.sort((a, b) => a.at.compareTo(b.at));
  final dayList = days.entries.where((e) => e.key.compareTo(oldest) >= 0).toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return ProgressSummary(
    exercise: exercise,
    sessions: chosen.length,
    repetitions: repetitions,
    labels: labels,
    shares: repetitions == 0
        ? null
        : {for (final k in labels.keys) k: share(labels[k]!)},
    activity: [
      for (final e in dayList)
        ActivityDay(e.key, e.value.sessions.length, e.value.repetitions),
    ],
    measure: def == null ? null : (name: def.measureName, unit: def.measureUnit),
    points: all.length > _maxPoints ? all.sublist(all.length - _maxPoints) : all,
  );
}
