import { describe, expect, it } from "vitest";
import { computeProgress, dayKey, normalizeProgress, recentDays } from "@/lib/progress";
import { mergeLists, toListItem } from "@/lib/historyView";
import type { LocalSession } from "@/lib/history";

const at = (d: string) => `${d}T10:00:00Z`;
const a = (id: string, day: string, label: "complete" | "incomplete" | "uncertain", value: number | null) => ({
  analysis_id: id,
  at: at(day),
  verdict: label === "complete" ? ("completed" as const) : ("check_instructions" as const),
  label,
  confidence: 0.9,
  source: "model" as const,
  ...(value === null ? {} : { measure: { name: "hand_openness" as const, unit: "percent" as const, value, series: { fps: 10, values: [value] } } }),
});
const SESSIONS: LocalSession[] = [
  { id: "s1", exercise: "E04", started_at: at("2026-11-24"), attempts: [a("1", "2026-11-24", "incomplete", 130), a("2", "2026-11-24", "complete", 160)] },
  { id: "s2", exercise: "E04", started_at: at("2026-11-25"), attempts: [a("3", "2026-11-25", "complete", 180), a("4", "2026-11-25", "uncertain", null)] },
  { id: "s3", exercise: "E02", started_at: at("2026-11-25"), attempts: [a("5", "2026-11-25", "complete", null)] },
];
const NOW = new Date("2026-11-25T12:00:00Z");

describe("computeProgress", () => {
  it("по упражнению: занятия, повторения, доли, дни и значения в порядке времени", () => {
    const p = computeProgress(SESSIONS, "E04", 0, NOW);
    expect(p.sessions).toBe(2);
    expect(p.repetitions).toBe(4);
    expect(p.labels).toEqual({ complete: 2, incomplete: 1, uncertain: 1 });
    expect(p.shares).toEqual({ complete: 0.5, incomplete: 0.25, uncertain: 0.25 });
    expect(p.activity).toEqual([
      { date: "2026-11-24", sessions: 1, repetitions: 2 },
      { date: "2026-11-25", sessions: 1, repetitions: 2 },
    ]);
    expect(p.measure).toEqual({ name: "hand_openness", unit: "percent" });
    expect(p.points.map((x) => x.value)).toEqual([130, 160, 180]);
  });
  it("без выбранного упражнения нет measure и значений", () => {
    const p = computeProgress(SESSIONS, null, 0, NOW);
    expect(p.repetitions).toBe(5);
    expect(p.measure).toBeNull();
    expect(p.points).toEqual([]);
  });
  it("нет повторений — shares null", () => {
    expect(computeProgress([], "E01", 0, NOW).shares).toBeNull();
  });
  it("границы дня считаются в часовом поясе устройства", () => {
    expect(dayKey("2026-11-24T22:00:00Z", 0)).toBe("2026-11-24");
    expect(dayKey("2026-11-24T22:00:00Z", 300)).toBe("2026-11-25");
    expect(recentDays(3, 0, NOW)).toEqual(["2026-11-23", "2026-11-24", "2026-11-25"]);
  });
});

describe("normalizeProgress", () => {
  it("points и measure бывают null, если упражнение не выбрано: приводятся к пустым значениям", () => {
    const p = normalizeProgress({ exercise: null, sessions: 4, repetitions: 11, labels: { complete: 7, incomplete: 3, uncertain: 1 }, shares: null, activity: [], measure: null, points: null as never });
    expect(p.points).toEqual([]);
    expect(p.measure).toBeNull();
    expect(p.repetitions).toBe(11);
  });
  it("пустой ответ не падает", () => {
    expect(normalizeProgress(null).labels).toEqual({ complete: 0, incomplete: 0, uncertain: 0 });
  });
});

describe("mergeLists", () => {
  it("список с сервера плюс неотправленные занятия, без дублей, новые первыми", () => {
    const server = [toListItem(SESSIONS[0])];
    const local = [toListItem(SESSIONS[0]), toListItem(SESSIONS[1])];
    expect(mergeLists(server, local).map((x) => x.id)).toEqual(["s2", "s1"]);
  });
});
