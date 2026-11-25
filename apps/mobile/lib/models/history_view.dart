import 'session.dart';

// SessionCounts — сводка занятия по меткам повторений
class SessionCounts {
  final int total;
  final int complete;
  final int incomplete;
  final int uncertain;

  const SessionCounts(this.total, this.complete, this.incomplete, this.uncertain);

  // fromJson — summary занятия из GET /sessions
  factory SessionCounts.fromJson(Map<String, dynamic> j) => SessionCounts(
    (j['total'] as num).toInt(),
    (j['complete'] as num).toInt(),
    (j['incomplete'] as num).toInt(),
    (j['uncertain'] as num).toInt(),
  );
}

// SessionListItem — строка списка занятий: упражнение, начало и сводка
class SessionListItem {
  final String id;
  final String exercise;
  final DateTime startedAt;
  final SessionCounts summary;

  const SessionListItem(this.id, this.exercise, this.startedAt, this.summary);
}

// toListItem — строка списка из занятия на устройстве
SessionListItem toListItem(Session s) => SessionListItem(
  s.id,
  s.exercise,
  s.startedAt,
  SessionCounts(s.total, s.completeCount, s.incompleteCount, s.uncertainCount),
);

// sortNewestFirst — занятия от новых к старым
List<SessionListItem> sortNewestFirst(Iterable<SessionListItem> items) =>
    items.toList()..sort((a, b) => b.startedAt.compareTo(a.startedAt));
