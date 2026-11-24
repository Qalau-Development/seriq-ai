import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/session.dart';

// HistoryStorage — хранит занятия только на устройстве
class HistoryStorage {
  static const storageKey = 'seriq.sessions.v1';

  // loadSessions — читает все занятия, новые первыми
  Future<List<Session>> loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null) return [];
    try {
      final list = (jsonDecode(raw) as List)
          .map((s) => Session.fromJson(s as Map<String, dynamic>))
          .toList();
      list.sort((a, b) => b.startedAt.compareTo(a.startedAt));
      return list;
    } catch (_) {
      return [];
    }
  }

  // saveSession — добавляет занятие или обновляет его по id
  Future<void> saveSession(Session session) async {
    final sessions = await loadSessions();
    final i = sessions.indexWhere((s) => s.id == session.id);
    if (i >= 0) {
      sessions[i] = session;
    } else {
      sessions.add(session);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        storageKey, jsonEncode(sessions.map((s) => s.toJson()).toList()));
  }

  // clearAll — удаляет всю историю
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
  }
}
