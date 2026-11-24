import type { ExerciseId } from "@/types/analysis";
import { summarize, useSessions, type LocalSession, type SessionSummary } from "@/lib/history";

export interface SessionListItem {
  id: string;
  exercise: ExerciseId;
  started_at: string;
  summary: SessionSummary;
}

// toListItem — строка списка занятий из занятия на устройстве
export function toListItem(session: LocalSession): SessionListItem {
  return { id: session.id, exercise: session.exercise, started_at: session.started_at, summary: summarize(session.attempts) };
}

// sortNewestFirst — занятия от новых к старым
export function sortNewestFirst(items: SessionListItem[]): SessionListItem[] {
  return [...items].sort((a, b) => b.started_at.localeCompare(a.started_at));
}

// useHistoryList — список занятий для истории и главной; null, пока страница не загрузилась
export function useHistoryList(): SessionListItem[] | null {
  const sessions = useSessions();
  if (sessions === null) return null;
  return sortNewestFirst(sessions.filter((s) => s.attempts.length > 0).map(toListItem));
}
