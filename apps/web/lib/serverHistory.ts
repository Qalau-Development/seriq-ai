import type { LocalAttempt, LocalSession } from "@/lib/history";
import { parseExercise } from "@/lib/exercises";
import type { SessionListItem } from "@/lib/historyView";
import { AccountError, accountFetch } from "@/lib/auth";
import { normalizeProgress, type ProgressSummary } from "@/lib/progress";
import type { ExerciseId } from "@/types/analysis";
import { toServerBody } from "@/lib/sync";

const JSON_HEADERS = { "Content-Type": "application/json" };
const PAGE_LIMIT = 100;
const MAX_PAGES = 5;

// putSession — сохраняет занятие на сервере (идемпотентно, повтор не создаёт дубликатов)
export async function putSession(session: LocalSession): Promise<void> {
  await accountFetch(`/sessions/${session.id}`, { method: "PUT", headers: JSON_HEADERS, body: JSON.stringify(toServerBody(session)) });
}

// listSessions — занятия с сервера, новые первыми; читает до пяти страниц по 100
export async function listSessions(): Promise<SessionListItem[]> {
  const items: SessionListItem[] = [];
  let cursor: string | null = null;
  for (let page = 0; page < MAX_PAGES; page++) {
    const query: string = `limit=${PAGE_LIMIT}${cursor ? `&cursor=${encodeURIComponent(cursor)}` : ""}`;
    const body: { items?: unknown[]; next_cursor?: string | null } = await (await accountFetch(`/sessions?${query}`)).json();
    for (const raw of body.items ?? []) {
      const s = raw as { id: string; exercise: string; started_at: string; summary: SessionListItem["summary"] };
      items.push({ id: s.id, exercise: parseExercise(s.exercise), started_at: s.started_at, summary: s.summary });
    }
    cursor = body.next_cursor ?? null;
    if (!cursor) break;
  }
  return items;
}

// getSession — занятие с сервера со всеми повторениями; null, если его там нет
export async function getSession(id: string): Promise<LocalSession | null> {
  try {
    const s = await (await accountFetch(`/sessions/${id}`)).json();
    return {
      id: s.id,
      exercise: parseExercise(s.exercise),
      started_at: s.started_at,
      attempts: (s.attempts ?? []) as LocalAttempt[],
      synced: true,
    };
  } catch (e) {
    if (e instanceof AccountError && e.code === "not_found") return null;
    throw e;
  }
}

// deleteRemoteSession — удаляет занятие на сервере; если его там уже нет, это не ошибка
export async function deleteRemoteSession(id: string): Promise<void> {
  try {
    await accountFetch(`/sessions/${id}`, { method: "DELETE" });
  } catch (e) {
    if (!(e instanceof AccountError && e.code === "not_found")) throw e;
  }
}

// clearRemoteHistory — удаляет всю историю в аккаунте, сам аккаунт остаётся
export async function clearRemoteHistory(): Promise<void> {
  await accountFetch("/sessions", { method: "DELETE" });
}

// fetchProgress — счёт повторений с сервера (GET /progress/summary)
export async function fetchProgress(exercise: ExerciseId | null, utcOffsetMinutes: number): Promise<ProgressSummary> {
  const params = new URLSearchParams({ utc_offset_minutes: String(utcOffsetMinutes) });
  if (exercise) params.set("exercise", exercise);
  return normalizeProgress(await (await accountFetch(`/progress/summary?${params}`)).json());
}
