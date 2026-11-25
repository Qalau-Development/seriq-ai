import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/session.dart';
import 'auth.dart';
import 'history_storage.dart';
import 'server_history.dart';
import 'sync.dart';

// SyncState — состояние фоновой отправки занятий: простой, отправка, сохранено, нет связи, вход истёк, предел истории, ошибка сервера
enum SyncState { idle, syncing, ok, offline, auth, quota, error }

// SyncRuntime — отправка занятий вошедшего в аккаунт, перенос гостевой истории, выход и удаление аккаунта
class SyncRuntime {
  static const declinedKey = 'seriq.migrate.declined';

  final AuthService auth;
  final ServerHistory server;
  final HistoryStorage storage;
  final String Function() newId;
  final status = ValueNotifier<SyncState>(SyncState.idle);
  Future<void>? _running;
  bool _again = false;

  SyncRuntime(this.auth, this.server, this.storage, {String Function()? newId})
    : newId = newId ?? (() => const Uuid().v4());

  // _syncOnce — один проход отправки неотправленных занятий вошедшего
  Future<void> _syncOnce() async {
    final user = auth.user;
    if (user == null) return;
    final pending = pendingSessions(await storage.loadSessions(), user.id);
    if (pending.isEmpty) {
      if (const [SyncState.quota, SyncState.error, SyncState.offline].contains(status.value)) {
        status.value = SyncState.idle;
      }
      return;
    }
    status.value = SyncState.syncing;
    final result = await flushPending(pending, server.putSession);
    await storage.updateSessions((all) {
      for (final s in all) {
        if (result.sent.contains(s.id)) s.synced = true;
        for (final d in result.dropped) {
          if (d.id == s.id) s.syncFailed = d.code;
        }
      }
      return all;
    });
    status.value = switch (result.stopped) {
      'network' => SyncState.offline,
      'auth' => SyncState.auth,
      'quota' => SyncState.quota,
      'server' => SyncState.error,
      _ => SyncState.ok,
    };
  }

  // syncNow — отправляет на сервер неотправленные занятия вошедшего; один запуск за раз, а запрос во время отправки запускает ещё один проход; ошибки не бросает
  Future<void> syncNow() {
    if (_running != null) {
      _again = true;
      return _running!;
    }
    _running = (() async {
      do {
        _again = false;
        try {
          await _syncOnce();
        } catch (_) {
          status.value = SyncState.error;
        }
      } while (_again);
    })().whenComplete(() => _running = null);
    return _running!;
  }

  // guestSessions — гостевые занятия на устройстве: у них нет владельца
  Future<List<Session>> guestSessions() async => [
    for (final s in await storage.loadSessions())
      if (s.owner == null && s.attempts.isNotEmpty) s,
  ];

  // guestMigratableCount — сколько гостевых занятий можно перенести: тестовые (mock) не переносятся
  Future<int> guestMigratableCount() async =>
      migratableCount(await guestSessions());

  // isMigrationDeclined — пользователь уже отказался переносить гостевую историю в этот аккаунт
  Future<bool> isMigrationDeclined(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(declinedKey) ?? const []).contains(userId);
  }

  // declineMigration — запоминает отказ от переноса для этого аккаунта
  Future<void> declineMigration(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = {...(prefs.getStringList(declinedKey) ?? const <String>[]), userId};
    await prefs.setStringList(declinedKey, list.toList());
  }

  // migrateGuestSessions — переносит настоящие гостевые повторения в аккаунт серией PUT; тестовые (mock) остаются на устройстве; возвращает, сколько занятий перенесено и сколько ещё не отправлено
  Future<({int moved, int left})> migrateGuestSessions() async {
    final user = auth.user;
    if (user == null) return (moved: 0, left: 0);
    final guests = await guestSessions();
    final plan = planMigration(guests, newId);
    if (plan.migrate.isEmpty) return (moved: 0, left: 0);
    final guestIds = guests.map((s) => s.id).toSet();
    await storage.replaceSessions(
      (all) => [
        ...all.where((s) => !guestIds.contains(s.id)),
        ...plan.keepGuest,
        for (final s in plan.migrate) s.copy(owner: user.id, synced: false),
      ],
    );
    await syncNow();
    final ids = plan.migrate.map((s) => s.id).toSet();
    final mine = (await storage.loadSessions())
        .where((s) => s.owner == user.id && ids.contains(s.id))
        .toList();
    return (
      moved: mine.where((s) => s.synced == true).length,
      left: mine.where((s) => s.synced != true).length,
    );
  }

  // logout — выход: пытается отправить неотправленное, убирает с устройства копии занятий аккаунта, уже сохранённые на сервере (mock-повторения остаются гостевыми)
  Future<void> logout() async {
    final user = auth.user;
    if (user != null) {
      await syncNow();
      await storage.replaceSessions((all) => cleanupOnLogout(all, user.id, newId));
    }
    status.value = SyncState.idle;
    await auth.signOut();
  }

  // removeAccount — удаляет аккаунт на сервере и все копии его занятий на устройстве
  Future<void> removeAccount(String password) async {
    final user = auth.user;
    await auth.deleteAccount(password);
    if (user != null) await storage.removeSessions((s) => s.owner == user.id);
    status.value = SyncState.idle;
  }
}

// syncRuntime — отправка занятий приложения
final syncRuntime = SyncRuntime(auth, ServerHistory(auth), HistoryStorage());
