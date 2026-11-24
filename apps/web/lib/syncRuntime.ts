import { useSyncExternalStore } from "react";
import { currentUser, deleteAccount, signOut } from "@/lib/auth";
import { loadSessions, removeSessions, saveSession, updateSessions, type LocalSession } from "@/lib/history";
import { putSession } from "@/lib/serverHistory";
import { flushPending, pendingSessions } from "@/lib/sync";

const DECLINED_KEY = "seriq.migrate.declined";

export type SyncState = "idle" | "syncing" | "ok" | "offline" | "auth" | "error";

let status: SyncState = "idle";
let running: Promise<void> | null = null;
const listeners = new Set<() => void>();

// setStatus — меняет состояние отправки и сообщает подписчикам
function setStatus(next: SyncState) {
  status = next;
  listeners.forEach((l) => l());
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

// syncNow — отправляет на сервер неотправленные занятия вошедшего; один запуск за раз, ошибки не бросает
export function syncNow(): Promise<void> {
  running ??= (async () => {
    const user = currentUser();
    if (!user) return;
    const pending = pendingSessions(loadSessions(), user.id);
    if (pending.length === 0) return;
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
    setStatus(result.stopped === "network" ? "offline" : result.stopped === "auth" ? "auth" : result.stopped === "server" ? "error" : "ok");
  })().finally(() => {
    running = null;
  });
  return running;
}

// guestSessions — гостевые занятия на устройстве: у них нет владельца
export function guestSessions(): LocalSession[] {
  return loadSessions().filter((s) => !s.owner && s.attempts.length > 0);
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

// migrateGuestSessions — передаёт гостевые занятия аккаунту и отправляет их серией PUT; возвращает, сколько занятий перенесено
export async function migrateGuestSessions(): Promise<{ moved: number; left: number }> {
  const user = currentUser();
  if (!user) return { moved: 0, left: 0 };
  const guests = guestSessions();
  guests.forEach((s) => saveSession({ ...s, owner: user.id, synced: false }));
  await syncNow();
  const mine = loadSessions().filter((s) => s.owner === user.id && guests.some((g) => g.id === s.id));
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
