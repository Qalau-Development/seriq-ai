import { useSyncExternalStore } from "react";
import type { AnalysisResult, CycleLabel, ExerciseId, Measure, Verdict } from "@/types/analysis";
import { DEFAULT_EXERCISE, parseExercise } from "@/lib/exercises";
import { resultMeasure } from "@/lib/measure";

const STORAGE_KEY = "seriq.sessions.v1";
export const CHANGE_EVENT = "seriq-history-change";

export interface LocalAttempt {
  analysis_id: string;
  at: string;
  verdict: Verdict;
  label: CycleLabel;
  confidence: number;
  source: "mock" | "model";
  model_version?: string;
  measure?: Measure;
}

export interface LocalSession {
  id: string;
  exercise: ExerciseId;
  started_at: string;
  attempts: LocalAttempt[];
  owner?: string;
  synced?: boolean;
  sync_failed?: string;
}

export interface SessionSummary {
  total: number;
  complete: number;
  incomplete: number;
  uncertain: number;
}

// readRaw — читает сырую строку истории из localStorage
function readRaw(): string | null {
  try {
    return localStorage.getItem(STORAGE_KEY);
  } catch {
    return null;
  }
}

// parseSessions — разбирает строку истории, при ошибке возвращает пустой список; старые занятия E02 без measure читаются как есть
export function parseSessions(raw: string | null): LocalSession[] {
  if (!raw) return [];
  try {
    const data = JSON.parse(raw);
    if (!Array.isArray(data)) return [];
    return data
      .filter((s) => s && typeof s === "object" && Array.isArray(s.attempts))
      .map((s) => ({ ...s, exercise: parseExercise(s.exercise) }));
  } catch {
    return [];
  }
}

// writeSessions — сохраняет список занятий и сообщает об изменении
function writeSessions(sessions: LocalSession[]) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(sessions));
  window.dispatchEvent(new Event(CHANGE_EVENT));
}

// loadSessions — возвращает все занятия с устройства
export function loadSessions(): LocalSession[] {
  return parseSessions(readRaw());
}

// saveSession — добавляет занятие или обновляет его по id
export function saveSession(session: LocalSession) {
  const others = loadSessions().filter((s) => s.id !== session.id);
  writeSessions([...others, session]);
}

// startSession — создаёт новое занятие по выбранному упражнению (owner — id вошедшего); сохраняется с первой попыткой
export function startSession(exercise: ExerciseId = DEFAULT_EXERCISE, owner?: string): LocalSession {
  return { id: crypto.randomUUID(), exercise, started_at: new Date().toISOString(), attempts: [], ...(owner ? { owner } : {}) };
}

// storedMeasure — измеряемое значение для истории: ряд округлён до десятых, чтобы занимать меньше места
function storedMeasure(result: AnalysisResult): Measure | undefined {
  const m = resultMeasure(result);
  if (!m) return undefined;
  const round = (v: number | null) => (v === null ? null : Math.round(v * 10) / 10);
  return { ...m, value: round(m.value), series: { fps: m.series.fps, values: m.series.values.map(round) } };
}

// addAttempt — добавляет результат анализа в занятие и сохраняет его
export function addAttempt(session: LocalSession, result: AnalysisResult): LocalSession {
  const cycle = result.cycles[0];
  const attempt: LocalAttempt = {
    analysis_id: result.analysis_id,
    at: new Date().toISOString(),
    verdict: result.verdict,
    label: cycle?.label ?? "uncertain",
    confidence: cycle?.confidence ?? 0,
    source: result.source,
    model_version: result.model_version,
    measure: storedMeasure(result),
  };
  const updated = { ...session, synced: false, attempts: [...session.attempts, attempt] };
  saveSession(updated);
  return updated;
}

// deleteSession — удаляет одно занятие с устройства
export function deleteSession(id: string) {
  writeSessions(loadSessions().filter((s) => s.id !== id));
}

// updateSessions — меняет занятия на устройстве без уведомления подписчиков (служебные отметки отправки)
export function updateSessions(change: (sessions: LocalSession[]) => LocalSession[]) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(change(loadSessions())));
}

// removeSessions — удаляет с устройства занятия, подходящие под условие
export function removeSessions(match: (s: LocalSession) => boolean) {
  writeSessions(loadSessions().filter((s) => !match(s)));
}

// summarize — считает сводку занятия по попыткам
export function summarize(attempts: LocalAttempt[]): SessionSummary {
  return {
    total: attempts.length,
    complete: attempts.filter((a) => a.label === "complete").length,
    incomplete: attempts.filter((a) => a.label === "incomplete").length,
    uncertain: attempts.filter((a) => a.label === "uncertain").length,
  };
}

// subscribe — следит за изменениями истории в этой и других вкладках
function subscribe(onChange: () => void) {
  window.addEventListener("storage", onChange);
  window.addEventListener(CHANGE_EVENT, onChange);
  return () => {
    window.removeEventListener("storage", onChange);
    window.removeEventListener(CHANGE_EVENT, onChange);
  };
}

// subscribeHistory — подписка на изменения истории на устройстве
export const subscribeHistory = subscribe;

// useSessions — занятия с устройства; null, пока страница не загрузилась в браузере
export function useSessions(): LocalSession[] | null {
  const raw = useSyncExternalStore(subscribe, readRaw, () => undefined);
  return raw === undefined ? null : parseSessions(raw);
}
