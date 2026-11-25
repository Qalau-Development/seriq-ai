import 'dart:convert';

import '../core/exercises.dart';
import '../models/history_view.dart';
import '../models/progress.dart';
import '../models/session.dart';
import 'auth.dart';
import 'sync.dart';

const _pageLimit = 100;
const _maxPages = 5;

// ServerHistory — обмен занятиями и счётом с сервером для вошедшего пользователя
class ServerHistory {
  final AuthService auth;

  ServerHistory(this.auth);

  // _json — разбирает тело ответа как JSON-объект
  Map<String, dynamic> _json(List<int> bytes) =>
      jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;

  // putSession — сохраняет занятие на сервере (идемпотентно, повтор не создаёт дубликатов)
  Future<void> putSession(Session session) async {
    await auth.authorized('PUT', '/sessions/${session.id}', body: toServerBody(session));
  }

  // listSessions — занятия с сервера, новые первыми; читает до пяти страниц по 100
  Future<List<SessionListItem>> listSessions() async {
    final items = <SessionListItem>[];
    String? cursor;
    for (var page = 0; page < _maxPages; page++) {
      final query = 'limit=$_pageLimit${cursor == null ? '' : '&cursor=${Uri.encodeQueryComponent(cursor)}'}';
      final body = _json((await auth.authorized('GET', '/sessions?$query')).bodyBytes);
      for (final raw in (body['items'] as List? ?? [])) {
        final s = raw as Map<String, dynamic>;
        items.add(SessionListItem(
          s['id'] as String,
          parseExercise(s['exercise'] as String?),
          DateTime.parse(s['started_at'] as String),
          SessionCounts.fromJson(s['summary'] as Map<String, dynamic>),
        ));
      }
      cursor = body['next_cursor'] as String?;
      if (cursor == null) break;
    }
    return items;
  }

  // getSession — занятие с сервера со всеми повторениями; null, если его там нет
  Future<Session?> getSession(String id) async {
    try {
      final s = _json((await auth.authorized('GET', '/sessions/$id')).bodyBytes);
      return Session(
        id: s['id'] as String,
        exercise: parseExercise(s['exercise'] as String?),
        startedAt: DateTime.parse(s['started_at'] as String),
        attempts: [
          for (final a in (s['attempts'] as List? ?? []))
            Attempt.fromJson(a as Map<String, dynamic>),
        ],
        synced: true,
      );
    } on AccountError catch (e) {
      if (e.code == 'not_found') return null;
      rethrow;
    }
  }

  // deleteRemoteSession — удаляет занятие на сервере; если его там уже нет, это не ошибка
  Future<void> deleteRemoteSession(String id) async {
    try {
      await auth.authorized('DELETE', '/sessions/$id');
    } on AccountError catch (e) {
      if (e.code != 'not_found') rethrow;
    }
  }

  // clearRemoteHistory — удаляет всю историю в аккаунте, сам аккаунт остаётся
  Future<void> clearRemoteHistory() async {
    await auth.authorized('DELETE', '/sessions');
  }

  // fetchProgress — счёт повторений с сервера (GET /progress/summary)
  Future<ProgressSummary> fetchProgress(String? exercise, int utcOffsetMinutes) async {
    final params = {
      'utc_offset_minutes': '$utcOffsetMinutes',
      'exercise': ?exercise,
    };
    final query = params.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&');
    return ProgressSummary.fromJson(
      _json((await auth.authorized('GET', '/progress/summary?$query')).bodyBytes),
    );
  }
}
