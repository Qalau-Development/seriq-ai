import 'package:flutter/foundation.dart';

import '../models/history_view.dart';
import '../models/progress.dart';
import '../models/session.dart';
import 'accounts.dart';
import 'auth.dart';
import 'history_storage.dart';
import 'server_history.dart';
import 'sync_runtime.dart';

// AccountModeKind — откуда читать историю: загрузка, устройство (гость) или сервер (вошедший)
enum AccountModeKind { loading, guest, account }

// AccountMode — режим данных и id вошедшего
class AccountMode {
  final AccountModeKind kind;
  final String? userId;

  const AccountMode(this.kind, [this.userId]);
}

// accountMode — откуда читать историю: с устройства (гость) или с сервера (вошедший, аккаунты включены)
AccountMode accountMode(AuthService auth, AccountsAvailability available) {
  if (auth.value.kind == AuthKind.restoring) {
    return const AccountMode(AccountModeKind.loading);
  }
  final signedIn = auth.value.kind == AuthKind.signedIn;
  if (signedIn && accountsOn(available.value, true)) {
    return AccountMode(AccountModeKind.account, auth.user!.id);
  }
  return const AccountMode(AccountModeKind.guest);
}

// HistoryView — история, сводка и счёт для экранов: у гостя с устройства, у вошедшего с сервера; без связи показываются занятия аккаунта с устройства
class HistoryView {
  final AuthService auth;
  final AccountsAvailability available;
  final HistoryStorage storage;
  final ServerHistory server;
  final SyncRuntime sync;

  HistoryView(this.auth, this.available, this.storage, this.server, this.sync);

  // changes — что меняет данные: история на устройстве, вход, доступность аккаунтов
  Listenable get changes =>
      Listenable.merge([historyVersion, auth, available, sync.status]);

  // mode — текущий режим данных
  AccountMode get mode => accountMode(auth, available);

  // _owned — занятия аккаунта, сохранённые на устройстве
  Future<List<Session>> _owned(String userId) async => [
    for (final s in await storage.loadSessions())
      if (s.owner == userId && s.attempts.isNotEmpty) s,
  ];

  // list — список занятий: у гостя с устройства, у вошедшего с сервера плюс ещё не отправленные; offline — сервер недоступен
  Future<({List<SessionListItem>? items, bool offline})> list() async {
    final m = mode;
    if (m.kind == AccountModeKind.loading) return (items: null, offline: false);
    if (m.kind == AccountModeKind.guest) {
      final all = await storage.loadSessions();
      return (
        items: sortNewestFirst(
          all.where((s) => s.owner == null && s.attempts.isNotEmpty).map(toListItem),
        ),
        offline: false,
      );
    }
    await sync.syncNow();
    final userId = m.userId!;
    try {
      final remote = await server.listSessions();
      final known = remote.map((s) => s.id).toSet();
      final pending = (await _owned(userId))
          .where((s) => s.synced != true && !known.contains(s.id))
          .map(toListItem);
      return (items: sortNewestFirst([...remote, ...pending]), offline: false);
    } catch (_) {
      return (
        items: sortNewestFirst((await _owned(userId)).map(toListItem)),
        offline: true,
      );
    }
  }

  // detail — занятие для сводки: у гостя с устройства, у вошедшего с сервера; session == null, если не найдено
  Future<({Session? session, bool offline})> detail(String id) async {
    final m = mode;
    if (m.kind != AccountModeKind.account) {
      final s = await storage.loadSession(id);
      return (session: s != null && s.owner == null ? s : null, offline: false);
    }
    await sync.syncNow();
    final userId = m.userId!;
    try {
      final remote = await server.getSession(id);
      if (remote != null) return (session: remote, offline: false);
      final mine = (await _owned(userId)).where((s) => s.id == id).firstOrNull;
      return (session: mine, offline: false);
    } catch (_) {
      final mine = (await _owned(userId)).where((s) => s.id == id).firstOrNull;
      return (session: mine, offline: true);
    }
  }

  // progress — счёт повторений: у гостя считается из занятий на устройстве, у вошедшего приходит с сервера; failed — не удалось загрузить, показаны данные устройства
  Future<({ProgressSummary summary, bool failed})> progress(String? exercise) async {
    final m = mode;
    final offset = localUtcOffsetMinutes();
    Future<ProgressSummary> localSummary(String? userId) async {
      final all = await storage.loadSessions();
      return computeProgress(
        all.where((s) => userId == null ? s.owner == null : s.owner == userId).toList(),
        exercise,
        offset,
      );
    }

    if (m.kind != AccountModeKind.account) {
      return (summary: await localSummary(null), failed: false);
    }
    await sync.syncNow();
    try {
      return (summary: await server.fetchProgress(exercise, offset), failed: false);
    } catch (_) {
      return (summary: await localSummary(m.userId), failed: true);
    }
  }

  // removeOne — удаляет занятие: у вошедшего сначала на сервере, затем на устройстве
  Future<void> removeOne(String id) async {
    if (mode.kind == AccountModeKind.account) await server.deleteRemoteSession(id);
    await storage.removeSessions((s) => s.id == id);
  }

  // removeAll — очищает историю: у вошедшего на сервере и копии на устройстве, у гостя гостевые занятия
  Future<void> removeAll() async {
    final m = mode;
    final account = m.kind == AccountModeKind.account;
    if (account) await server.clearRemoteHistory();
    await storage.removeSessions(
      (s) => account ? s.owner == m.userId : s.owner == null,
    );
  }
}

// historyView — история приложения
var historyView = HistoryView(
  auth,
  accountsAvailable,
  HistoryStorage(),
  ServerHistory(auth),
  syncRuntime,
);
