import { useSyncExternalStore } from "react";
import { currentUser, deleteAccount, signOut } from "@/lib/auth";
import { CHANGE_EVENT, loadSessions, removeSessions, updateSessions, type LocalSession } from "@/lib/history";
import { putSession } from "@/lib/serverHistory";
import { flushPending, migratableCount, pendingSessions, planMigration } from "@/lib/sync";

const DECLINED_KEY = "seriq.migrate.declined";

export type SyncState = "idle" | "syncing" | "ok" | "offline" | "auth" | "quota" | "error";

let status: SyncState = "idle";
let running: Promise<void> | null = null;
let again = false;
const listeners = new Set<() => void>();

// setStatus — меняет состояние отправки и сообщает подписчикам
function setStatus(next: SyncState) {
  status = next;
  listeners.forEach((l) => l());
}

// getSyncStatus — текущее состояние отправки
export function getSyncStatus(): SyncState {
  return status;
}

// useSyncStatus — состояние фоновой отправки занятий в аккаунт
export function useSyncStatus(): SyncState {
  return useSyncExternalStore(
    (l) => {
      listeners.add(l);
      return () => listeners.delete(l);
    },
    () => status,
    () => "idle" as SyncState,
  );
}

// syncOnce — один проход отправки неотправленных занятий вошедшего
async function syncOnce() {
  const user = currentUser();
  if (!user) return;
  const pending = pendingSessions(loadSessions(), user.id);
  if (pending.length === 0) {
    if (status === "quota" || status === "error" || status === "offline") setStatus("idle");
    return;
  }
  setStatus("syncing");
  const result = await flushPending(pending, async (id) => {
    const session = pending.find((p) => p.id === id);
    if (session) await putSession(session);
  });
  updateSessions((all) =>
    all.map((s) => {
      if (result.sent.includes(s.id)) return { ...s, synced: true };
      const bad = result.dropped.find((d) => d.id === s.id);
      return bad ? { ...s, sync_failed: bad.code } : s;
    }),
  );
  const failed = { network: "offline", auth: "auth", quota: "quota", server: "error" } as const;
  setStatus(result.stopped ? failed[result.stopped] : "ok");
}

// syncNow — отправляет на сервер неотправленные занятия вошедшего; один запуск за раз, а запрос во время отправки запускает ещё один проход; ошибки не бросает
export function syncNow(): Promise<void> {
  if (running) {
    again = true;
    return running;
  }
  running = (async () => {
    do {
      again = false;
      await syncOnce();
    } while (again);
  })().finally(() => {
    running = null;
  });
  return running;
}

// guestSessions — гостевые занятия на устройстве: у них нет владельца
export function guestSessions(): LocalSession[] {
  return loadSessions().filter((s) => !s.owner && s.attempts.length > 0);
}

// guestMigratableCount — сколько гостевых занятий можно перенести: тестовые (mock) не переносятся
export function guestMigratableCount(): number {
  return migratableCount(guestSessions());
}

// isMigrationDeclined — пользователь уже отказался переносить гостевую историю в этот аккаунт
export function isMigrationDeclined(userId: string): boolean {
  try {
    return (JSON.parse(localStorage.getItem(DECLINED_KEY) ?? "[]") as string[]).includes(userId);
  } catch {
    return false;
  }
}

// declineMigration — запоминает отказ от переноса для этого аккаунта
export function declineMigration(userId: string) {
  try {
    const list = JSON.parse(localStorage.getItem(DECLINED_KEY) ?? "[]") as string[];
    localStorage.setItem(DECLINED_KEY, JSON.stringify([...new Set([...list, userId])]));
  } catch {
    // отказ не сохранился — вопрос появится при следующем входе
  }
}

// migrateGuestSessions — переносит настоящие гостевые повторения в аккаунт серией PUT; тестовые (mock) остаются на устройстве; возвращает, сколько занятий перенесено и сколько ещё не отправлено
export async function migrateGuestSessions(): Promise<{ moved: number; left: number }> {
  const user = currentUser();
  if (!user) return { moved: 0, left: 0 };
  const guests = guestSessions();
  const { migrate, keepGuest } = planMigration(guests, () => crypto.randomUUID());
  if (migrate.length === 0) return { moved: 0, left: 0 };
  const guestIds = new Set(guests.map((s) => s.id));
  updateSessions((all) => [
    ...all.filter((s) => !guestIds.has(s.id)),
    ...keepGuest,
    ...migrate.map((s) => ({ ...s, owner: user.id, synced: false })),
  ]);
  window.dispatchEvent(new Event(CHANGE_EVENT));
  await syncNow();
  const ids = new Set(migrate.map((s) => s.id));
  const mine = loadSessions().filter((s) => s.owner === user.id && ids.has(s.id));
  return { moved: mine.filter((s) => s.synced).length, left: mine.filter((s) => !s.synced).length };
}

// logout — выход: пытается отправить неотправленное, убирает с устройства копии занятий аккаунта, уже сохранённые на сервере
export async function logout(): Promise<void> {
  const user = currentUser();
  if (user) {
    await syncNow();
    removeSessions((s) => s.owner === user.id && s.synced === true);
  }
  setStatus("idle");
  await signOut();
}

// removeAccount — удаляет аккаунт на сервере и все копии его занятий на устройстве
export async function removeAccount(password: string): Promise<void> {
  const user = currentUser();
  await deleteAccount(password);
  if (user) removeSessions((s) => s.owner === user.id);
  setStatus("idle");
}
