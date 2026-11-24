import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { addAttempt, loadSessions, parseSessions, startSession, summarize } from "@/lib/history";
import type { AnalysisResult } from "@/types/analysis";

// OLD_E02 — запись истории в старом формате: без measure, model_version, owner
const OLD_E02 = JSON.stringify([
  {
    id: "old-1",
    exercise: "E02",
    started_at: "2026-11-20T10:00:00Z",
    attempts: [{ analysis_id: "a1", at: "2026-11-20T10:01:00Z", verdict: "completed", label: "complete", confidence: 0.9, source: "model" }],
  },
]);

describe("чтение истории", () => {
  it("старая запись E02 без measure читается как есть", () => {
    const [s] = parseSessions(OLD_E02);
    expect(s.exercise).toBe("E02");
    expect(s.attempts).toHaveLength(1);
    expect(s.attempts[0].measure).toBeUndefined();
    expect(summarize(s.attempts)).toEqual({ total: 1, complete: 1, incomplete: 0, uncertain: 0 });
  });
  it("пустая строка, мусор и не массив — пустая история", () => {
    expect(parseSessions(null)).toEqual([]);
    expect(parseSessions("не json")).toEqual([]);
    expect(parseSessions('{"a":1}')).toEqual([]);
  });
  it("занятие без упражнения читается как E02, неизвестное — тоже; записи без attempts пропускаются", () => {
    const list = parseSessions(JSON.stringify([{ id: "x", attempts: [] }, { id: "y", exercise: "E99", attempts: [] }, { id: "z" }, null]));
    expect(list.map((s) => [s.id, s.exercise])).toEqual([["x", "E02"], ["y", "E02"]]);
  });
});

describe("addAttempt", () => {
  const store = new Map<string, string>();
  beforeEach(() => {
    store.clear();
    vi.stubGlobal("localStorage", { getItem: (k: string) => store.get(k) ?? null, setItem: (k: string, v: string) => void store.set(k, v), removeItem: (k: string) => void store.delete(k) });
    vi.stubGlobal("window", { dispatchEvent: () => true });
  });
  afterEach(() => vi.unstubAllGlobals());

  const result = {
    status: "ok",
    analysis_id: "an-1",
    source: "model",
    model_version: "e04-logreg2-1",
    exercise: "E04",
    verdict: "completed",
    summary: { total: 1, complete: 1, incomplete: 0, uncertain: 0 },
    cycles: [{ index: 1, start_s: 0, end_s: 5, label: "complete", confidence: 0.917, verdict: "completed" }],
    measure: { name: "hand_openness", unit: "percent", value: 178.94, series: { fps: 10, values: [100, 101.26, null, 178.94] } },
    warnings: [],
    processing_ms: 1,
  } as AnalysisResult;

  it("сохраняет упражнение, версию модели и measure с рядом, округлённым до десятых", () => {
    const session = addAttempt(startSession("E04", "user-1"), result);
    const [saved] = loadSessions();
    expect(saved.id).toBe(session.id);
    expect(saved.exercise).toBe("E04");
    expect(saved.owner).toBe("user-1");
    expect(saved.synced).toBe(false);
    expect(saved.attempts[0].model_version).toBe("e04-logreg2-1");
    expect(saved.attempts[0].measure).toEqual({ name: "hand_openness", unit: "percent", value: 178.9, series: { fps: 10, values: [100, 101.3, null, 178.9] } });
  });
  it("гостевое занятие без владельца; результат без measure и angle_series сохраняется без measure", () => {
    const bare = { ...result, measure: undefined } as AnalysisResult;
    addAttempt(startSession("E02"), bare);
    const [saved] = loadSessions();
    expect(saved.owner).toBeUndefined();
    expect(saved.attempts[0].measure).toBeUndefined();
  });
});
