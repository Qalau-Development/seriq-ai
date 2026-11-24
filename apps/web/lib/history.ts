import { useSyncExternalStore } from "react";
import type { AnalysisResult, CycleLabel, Verdict } from "@/types/analysis";

const STORAGE_KEY = "seriq.sessions.v1";
const CHANGE_EVENT = "seriq-history-change";

export interface LocalAttempt {
  analysis_id: string;
  at: string;
  verdict: Verdict;
  label: CycleLabel;
  confidence: number;
  source: "mock" | "model";
}

export interface LocalSession {
  id: string;
  exercise: "E02";
  started_at: string;
  attempts: LocalAttempt[];
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

// parseSessions — разбирает строку истории, при ошибке возвращает пустой список
function parseSessions(raw: string | null): LocalSession[] {
  if (!raw) return [];
  try {
    const data = JSON.parse(raw);
    return Array.isArray(data) ? data : [];
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

// startSession — создаёт новое занятие; сохраняется с первой попыткой
export function startSession(): LocalSession {
  return { id: crypto.randomUUID(), exercise: "E02", started_at: new Date().toISOString(), attempts: [] };
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
  };
  const updated = { ...session, attempts: [...session.attempts, attempt] };
  saveSession(updated);
  return updated;
}

// clearHistory — удаляет все занятия с устройства
export function clearHistory() {
  localStorage.removeItem(STORAGE_KEY);
  window.dispatchEvent(new Event(CHANGE_EVENT));
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

// useSessions — занятия с устройства; null, пока страница не загрузилась в браузере
export function useSessions(): LocalSession[] | null {
  const raw = useSyncExternalStore(subscribe, readRaw, () => undefined);
  return raw === undefined ? null : parseSessions(raw);
}
