import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/session.dart';

// historyVersion — растёт при каждом изменении истории на устройстве; по нему экраны перечитывают данные
final historyVersion = ValueNotifier<int>(0);

// HistoryStorage — хранит занятия только на устройстве
class HistoryStorage {
  static const storageKey = 'seriq.sessions.v1';

  // loadSessions — читает все занятия, новые первыми
  Future<List<Session>> loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null) return [];
    try {
      final list = <Session>[];
      for (final item in jsonDecode(raw) as List) {
        try {
          list.add(Session.fromJson(item as Map<String, dynamic>));
        } catch (_) {
          // повреждённое занятие пропускается, остальные читаются
        }
      }
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
    historyVersion.value++;
  }

  // _write — записывает список занятий; notify — сообщить экранам об изменении
  Future<void> _write(List<Session> sessions, {bool notify = true}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      storageKey,
      jsonEncode(sessions.map((s) => s.toJson()).toList()),
    );
    if (notify) historyVersion.value++;
  }

  // updateSessions — меняет занятия на устройстве без уведомления экранов (служебные отметки отправки)
  Future<void> updateSessions(
    List<Session> Function(List<Session> all) change,
  ) async {
    await _write(change(await loadSessions()), notify: false);
  }

  // replaceSessions — меняет занятия на устройстве и сообщает экранам
  Future<void> replaceSessions(
    List<Session> Function(List<Session> all) change,
  ) async {
    await _write(change(await loadSessions()));
  }

  // removeSessions — удаляет с устройства занятия, подходящие под условие
  Future<void> removeSessions(bool Function(Session s) match) async {
    await _write((await loadSessions()).where((s) => !match(s)).toList());
  }

  // loadSession — одно занятие по id; null, если его нет
  Future<Session?> loadSession(String id) async {
    final all = await loadSessions();
    return all.where((s) => s.id == id).firstOrNull;
  }

  // deleteSession — удаляет одно занятие
  Future<void> deleteSession(String id) async {
    final sessions = (await loadSessions()).where((s) => s.id != id).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      storageKey,
      jsonEncode(sessions.map((s) => s.toJson()).toList()),
    );
    historyVersion.value++;
  }

  // clearAll — удаляет всю историю
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
    historyVersion.value++;
  }
}
