import type { ExerciseId, Measure } from "@/types/analysis";
import { AccountError } from "@/lib/auth";
import type { LocalAttempt, LocalSession } from "@/lib/history";

export interface ServerAttempt {
  analysis_id: string;
  at: string;
  source: "mock" | "model";
  model_version: string;
  verdict: string;
  label: string;
  confidence: number;
  measure?: Measure;
}

export interface ServerSessionBody {
  exercise: ExerciseId;
  started_at: string;
  attempts: ServerAttempt[];
}

export type PutFn = (id: string, body: ServerSessionBody) => Promise<void>;

export interface FlushResult {
  sent: string[];
  dropped: { id: string; code: string }[];
  stopped: "network" | "auth" | "quota" | "server" | null;
}

// isReal — повторение настоящее, не тестовое (source не mock): тестовые на сервер не отправляются никогда
export function isReal(a: LocalAttempt): boolean {
  return a.source !== "mock";
}

// hasReal — в занятии есть хотя бы одно настоящее повторение
export function hasReal(s: LocalSession): boolean {
  return s.attempts.some(isReal);
}

const AUTH_CODES = ["invalid_token", "token_expired", "refresh_reused"];
const REJECTED_CODES = ["invalid_request", "id_conflict", "payload_too_large"];

// toServerAttempt — повторение в формате контракта; у старых записей без версии модели: unknown
export function toServerAttempt(a: LocalAttempt): ServerAttempt {
  return {
    analysis_id: a.analysis_id,
    at: a.at,
    source: a.source,
    model_version: a.model_version ?? "unknown",
    verdict: a.verdict,
    label: a.label,
    confidence: a.confidence,
    ...(a.measure ? { measure: a.measure } : {}),
  };
}

// toServerBody — тело PUT /sessions/{id} из занятия на устройстве; тестовые (mock) повторения в него не попадают
export function toServerBody(s: LocalSession): ServerSessionBody {
  return { exercise: s.exercise, started_at: s.started_at, attempts: s.attempts.filter(isReal).map(toServerAttempt) };
}

// pendingSessions — занятия вошедшего, которые ещё не отправлены на сервер и могут быть отправлены; занятие из одних mock-повторений не отправляется вовсе
export function pendingSessions(sessions: LocalSession[], userId: string): LocalSession[] {
  return sessions.filter((s) => s.owner === userId && !s.synced && !s.sync_failed && hasReal(s));
}

// flushPending — отправляет занятия по одному; сетевая ошибка, истёкший вход, предел истории или ошибка сервера останавливают отправку до следующего раза (занятие не отклоняется), отклонённые сервером занятия отмечаются и больше не повторяются
export async function flushPending(pending: LocalSession[], put: PutFn): Promise<FlushResult> {
  const result: FlushResult = { sent: [], dropped: [], stopped: null };
  for (const s of pending) {
    try {
      await put(s.id, toServerBody(s));
      result.sent.push(s.id);
    } catch (e) {
      const code = e instanceof AccountError ? e.code : "internal_error";
      if (code === "network_error") return { ...result, stopped: "network" };
      if (AUTH_CODES.includes(code)) return { ...result, stopped: "auth" };
      if (code === "quota_exceeded") return { ...result, stopped: "quota" };
      if (REJECTED_CODES.includes(code)) result.dropped.push({ id: s.id, code });
      else return { ...result, stopped: "server" };
    }
  }
  return result;
}

// migratableCount — сколько гостевых занятий можно перенести в аккаунт: в них есть хотя бы одно настоящее повторение
export function migratableCount(guests: LocalSession[]): number {
  return guests.filter((s) => s.attempts.some(isReal)).length;
}

// planMigration — делит гостевые занятия: настоящие повторения уходят в аккаунт, тестовые (mock) остаются на устройстве гостевым занятием; newId даёт id для остатка смешанного занятия
export function planMigration(guests: LocalSession[], newId: () => string): { migrate: LocalSession[]; keepGuest: LocalSession[] } {
  const migrate: LocalSession[] = [];
  const keepGuest: LocalSession[] = [];
  for (const s of guests) {
    const real = s.attempts.filter(isReal);
    const mock = s.attempts.filter((a) => !isReal(a));
    if (real.length === 0) keepGuest.push(s);
    else {
      migrate.push({ ...s, attempts: real });
      if (mock.length > 0) keepGuest.push({ ...s, id: newId(), attempts: mock });
    }
  }
  return { migrate, keepGuest };
}

// cleanupOnLogout — что оставить на устройстве при выходе: неотправленные настоящие занятия остаются за аккаунтом, занятия из одних mock-повторений становятся гостевыми, сохранённые на сервере убираются, а их mock-повторения остаются гостевым занятием с новым id
export function cleanupOnLogout(sessions: LocalSession[], userId: string, newId: () => string): LocalSession[] {
  return sessions.flatMap((s) => {
    if (s.owner !== userId) return [s];
    if (!s.synced) return hasReal(s) ? [s] : [{ ...s, owner: undefined, synced: undefined }];
    const mock = s.attempts.filter((a) => !isReal(a));
    return mock.length > 0 ? [{ id: newId(), exercise: s.exercise, started_at: s.started_at, attempts: mock }] : [];
  });
}
