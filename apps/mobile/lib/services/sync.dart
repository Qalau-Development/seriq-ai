import '../models/session.dart';
import 'auth.dart';

// PutFn — отправка одного занятия на сервер: PUT /sessions/{id}
typedef PutFn = Future<void> Function(Session session);

// FlushResult — итог отправки: что ушло, что сервер отклонил и почему остановились
class FlushResult {
  final List<String> sent;
  final List<({String id, String code})> dropped;
  final String? stopped;

  const FlushResult(this.sent, this.dropped, this.stopped);
}

// isReal — повторение настоящее, не тестовое (source не mock): тестовые на сервер не отправляются никогда
bool isReal(Attempt a) => a.source != 'mock';

// hasReal — в занятии есть хотя бы одно настоящее повторение
bool hasReal(Session s) => s.attempts.any(isReal);

const _rejectedCodes = ['invalid_request', 'id_conflict', 'payload_too_large'];

// toServerAttempt — повторение в формате контракта; у старых записей без версии модели: unknown
Map<String, dynamic> toServerAttempt(Attempt a) => {
  'analysis_id': a.analysisId,
  'at': isoUtc(a.at),
  'source': a.source,
  'model_version': a.modelVersion ?? 'unknown',
  'verdict': a.verdict,
  'label': a.label,
  'confidence': a.confidence,
  if (a.measure != null) 'measure': a.measure!.toJson(),
};

// toServerBody — тело PUT /sessions/{id} из занятия на устройстве; тестовые (mock) повторения в него не попадают
Map<String, dynamic> toServerBody(Session s) => {
  'exercise': s.exercise,
  'started_at': isoUtc(s.startedAt),
  'attempts': s.attempts.where(isReal).map(toServerAttempt).toList(),
};

// pendingSessions — занятия вошедшего, которые ещё не отправлены и могут быть отправлены; занятие из одних mock-повторений не отправляется вовсе
List<Session> pendingSessions(List<Session> sessions, String userId) => [
  for (final s in sessions)
    if (s.owner == userId && s.synced != true && s.syncFailed == null && hasReal(s)) s,
];

// flushPending — отправляет занятия по одному; сеть, истёкший вход, предел истории или ошибка сервера останавливают отправку до следующего раза, отклонённые сервером занятия отмечаются и больше не повторяются
Future<FlushResult> flushPending(List<Session> pending, PutFn put) async {
  final sent = <String>[];
  final dropped = <({String id, String code})>[];
  for (final s in pending) {
    try {
      await put(s);
      sent.add(s.id);
    } catch (e) {
      final code = e is AccountError ? e.code : 'internal_error';
      if (code == 'network_error') return FlushResult(sent, dropped, 'network');
      if (authCodes.contains(code)) return FlushResult(sent, dropped, 'auth');
      if (code == 'quota_exceeded') return FlushResult(sent, dropped, 'quota');
      if (_rejectedCodes.contains(code)) {
        dropped.add((id: s.id, code: code));
      } else {
        return FlushResult(sent, dropped, 'server');
      }
    }
  }
  return FlushResult(sent, dropped, null);
}

// migratableCount — сколько гостевых занятий можно перенести в аккаунт: в них есть хотя бы одно настоящее повторение
int migratableCount(List<Session> guests) =>
    guests.where((s) => s.attempts.any(isReal)).length;

// planMigration — делит гостевые занятия: настоящие повторения уходят в аккаунт, тестовые (mock) остаются на устройстве гостевым занятием; newId даёт id для остатка смешанного занятия
({List<Session> migrate, List<Session> keepGuest}) planMigration(
  List<Session> guests,
  String Function() newId,
) {
  final migrate = <Session>[];
  final keepGuest = <Session>[];
  for (final s in guests) {
    final real = s.attempts.where(isReal).toList();
    final mock = s.attempts.where((a) => !isReal(a)).toList();
    if (real.isEmpty) {
      keepGuest.add(s);
    } else {
      migrate.add(s.copy(attempts: real));
      if (mock.isNotEmpty) keepGuest.add(s.copy(id: newId(), attempts: mock));
    }
  }
  return (migrate: migrate, keepGuest: keepGuest);
}

// cleanupOnLogout — что оставить на устройстве при выходе: неотправленные настоящие занятия остаются за аккаунтом, занятия из одних mock-повторений становятся гостевыми, сохранённые на сервере убираются, а их mock-повторения остаются гостевым занятием с новым id
List<Session> cleanupOnLogout(
  List<Session> sessions,
  String userId,
  String Function() newId,
) {
  final out = <Session>[];
  for (final s in sessions) {
    if (s.owner != userId) {
      out.add(s);
    } else if (s.synced != true) {
      out.add(hasReal(s) ? s : s.copy(clearOwner: true));
    } else {
      final mock = s.attempts.where((a) => !isReal(a)).toList();
      if (mock.isNotEmpty) {
        out.add(Session(
          id: newId(),
          exercise: s.exercise,
          startedAt: s.startedAt,
          attempts: mock,
        ));
      }
    }
  }
  return out;
}
