import { useEffect, useState, useSyncExternalStore } from "react";
import type { ExerciseId } from "@/types/analysis";
import { CHANGE_EVENT, loadSessions, summarize, useSessions, type LocalSession, type SessionSummary } from "@/lib/history";
import { useAccountsAvailable } from "@/lib/accounts";
import { useAuth } from "@/lib/auth";
import { getSession, listSessions } from "@/lib/serverHistory";
import { syncNow } from "@/lib/syncRuntime";

export interface SessionListItem {
  id: string;
  exercise: ExerciseId;
  started_at: string;
  summary: SessionSummary;
}

export type AccountMode = { kind: "loading" } | { kind: "guest" } | { kind: "account"; userId: string };

let version = 0;
const versionListeners = new Set<() => void>();
if (typeof window !== "undefined") {
  window.addEventListener(CHANGE_EVENT, () => {
    version += 1;
    versionListeners.forEach((l) => l());
  });
}

// useHistoryVersion — растёт при каждом изменении истории на устройстве; по нему перечитывается история с сервера
export function useHistoryVersion(): number {
  return useSyncExternalStore(
    (l) => {
      versionListeners.add(l);
      return () => versionListeners.delete(l);
    },
    () => version,
    () => 0,
  );
}

// useAccountMode — откуда читать историю: с устройства (гость) или с сервера (вошедший, аккаунты включены)
export function useAccountMode(): AccountMode {
  const available = useAccountsAvailable();
  const auth = useAuth();
  if (auth.kind === "restoring") return { kind: "loading" };
  if (available && auth.kind === "in") return { kind: "account", userId: auth.user.id };
  return { kind: "guest" };
}

// toListItem — строка списка занятий из занятия на устройстве
export function toListItem(session: LocalSession): SessionListItem {
  return { id: session.id, exercise: session.exercise, started_at: session.started_at, summary: summarize(session.attempts) };
}

// sortNewestFirst — занятия от новых к старым
export function sortNewestFirst(items: SessionListItem[]): SessionListItem[] {
  return [...items].sort((a, b) => b.started_at.localeCompare(a.started_at));
}

// mergeLists — список с сервера плюс занятия, которых там ещё нет (неотправленные)
export function mergeLists(server: SessionListItem[], local: SessionListItem[]): SessionListItem[] {
  const known = new Set(server.map((s) => s.id));
  return sortNewestFirst([...server, ...local.filter((s) => !known.has(s.id))]);
}

// ownedLocal — занятия аккаунта, сохранённые на устройстве
function ownedLocal(userId: string): LocalSession[] {
  return loadSessions().filter((s) => s.owner === userId && s.attempts.length > 0);
}

// useHistoryList — список занятий: у гостя с устройства, у вошедшего с сервера; без связи показываются занятия аккаунта с устройства
export function useHistoryList(): { items: SessionListItem[] | null; offline: boolean } {
  const mode = useAccountMode();
  const sessions = useSessions();
  const v = useHistoryVersion();
  const [remote, setRemote] = useState<{ key: string; items: SessionListItem[]; offline: boolean } | null>(null);
  const userId = mode.kind === "account" ? mode.userId : null;
  const key = `${userId}:${v}`;

  useEffect(() => {
    if (!userId) return;
    let alive = true;
    (async () => {
      await syncNow();
      try {
        const server = await listSessions();
        const pending = ownedLocal(userId).filter((s) => !s.synced).map(toListItem);
        if (alive) setRemote({ key, items: mergeLists(server, pending), offline: false });
      } catch {
        if (alive) setRemote({ key, items: sortNewestFirst(ownedLocal(userId).map(toListItem)), offline: true });
      }
    })();
    return () => {
      alive = false;
    };
  }, [userId, key]);

  if (mode.kind === "loading") return { items: null, offline: false };
  if (mode.kind === "account") return remote?.key === key ? { items: remote.items, offline: remote.offline } : { items: remote?.items ?? null, offline: remote?.offline ?? false };
  if (sessions === null) return { items: null, offline: false };
  return { items: sortNewestFirst(sessions.filter((s) => !s.owner && s.attempts.length > 0).map(toListItem)), offline: false };
}

// useSessionDetail — занятие для сводки: у гостя с устройства, у вошедшего с сервера; undefined, пока грузится, null, если не найдено
export function useSessionDetail(id: string | null): { session: LocalSession | null | undefined; offline: boolean } {
  const mode = useAccountMode();
  const sessions = useSessions();
  const [remote, setRemote] = useState<{ id: string; session: LocalSession | null; offline: boolean } | null>(null);
  const userId = mode.kind === "account" ? mode.userId : null;

  useEffect(() => {
    if (!userId || !id) return;
    let alive = true;
    (async () => {
      await syncNow();
      try {
        const server = await getSession(id);
        const local = ownedLocal(userId).find((s) => s.id === id) ?? null;
        if (alive) setRemote({ id, session: server ?? local, offline: false });
      } catch {
        const local = ownedLocal(userId).find((s) => s.id === id) ?? null;
        if (alive) setRemote({ id, session: local, offline: true });
      }
    })();
    return () => {
      alive = false;
    };
  }, [userId, id]);

  if (mode.kind === "loading") return { session: undefined, offline: false };
  if (mode.kind === "account") return remote?.id === id ? { session: remote.session, offline: remote.offline } : { session: undefined, offline: false };
  if (sessions === null) return { session: undefined, offline: false };
  return { session: sessions.find((s) => s.id === id && !s.owner) ?? null, offline: false };
}
