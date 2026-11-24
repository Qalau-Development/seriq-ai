import type { CycleLabel, ExerciseId, MeasureName, MeasureUnit } from "@/types/analysis";
import { exerciseDef } from "@/lib/exercises";
import type { LocalSession } from "@/lib/history";

export interface ProgressSummary {
  exercise: ExerciseId | null;
  sessions: number;
  repetitions: number;
  labels: Record<CycleLabel, number>;
  shares: Record<CycleLabel, number> | null;
  activity: { date: string; sessions: number; repetitions: number }[];
  measure: { name: MeasureName; unit: MeasureUnit } | null;
  points: { at: string; value: number; label: CycleLabel }[];
}

const ACTIVITY_DAYS = 90;
const MAX_POINTS = 100;

// dayKey — дата YYYY-MM-DD момента времени в часовом поясе со сдвигом в минутах от UTC
export function dayKey(iso: string, utcOffsetMinutes: number): string {
  return new Date(new Date(iso).getTime() + utcOffsetMinutes * 60000).toISOString().slice(0, 10);
}

// computeProgress — счёт повторений по занятиям на устройстве в том же виде, что отдаёт сервер (GET /progress/summary)
export function computeProgress(
  sessions: LocalSession[],
  exercise: ExerciseId | null,
  utcOffsetMinutes: number,
  now: Date = new Date(),
): ProgressSummary {
  const chosen = sessions.filter((s) => (exercise === null || s.exercise === exercise) && s.attempts.length > 0);
  const labels: Record<CycleLabel, number> = { complete: 0, incomplete: 0, uncertain: 0 };
  const days = new Map<string, { sessions: Set<string>; repetitions: number }>();
  const all: { at: string; value: number; label: CycleLabel }[] = [];
  const oldest = dayKey(new Date(now.getTime() - (ACTIVITY_DAYS - 1) * 86400000).toISOString(), utcOffsetMinutes);

  for (const s of chosen) {
    for (const a of s.attempts) {
      labels[a.label] += 1;
      const day = dayKey(a.at, utcOffsetMinutes);
      const entry = days.get(day) ?? { sessions: new Set<string>(), repetitions: 0 };
      entry.sessions.add(s.id);
      entry.repetitions += 1;
      days.set(day, entry);
      if (exercise !== null && a.measure && a.measure.value !== null) all.push({ at: a.at, value: a.measure.value, label: a.label });
    }
  }
  const repetitions = labels.complete + labels.incomplete + labels.uncertain;
  const share = (n: number) => Math.round((n / repetitions) * 10000) / 10000;
  const def = exercise ? exerciseDef(exercise) : null;
  return {
    exercise,
    sessions: chosen.length,
    repetitions,
    labels,
    shares: repetitions === 0 ? null : { complete: share(labels.complete), incomplete: share(labels.incomplete), uncertain: share(labels.uncertain) },
    activity: [...days.entries()]
      .filter(([date]) => date >= oldest)
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([date, v]) => ({ date, sessions: v.sessions.size, repetitions: v.repetitions })),
    measure: def ? { name: def.measureName, unit: def.measureUnit } : null,
    points: all.sort((a, b) => a.at.localeCompare(b.at)).slice(-MAX_POINTS),
  };
}

// recentDays — последние N дней по порядку, до сегодняшнего включительно, в часовом поясе со сдвигом
export function recentDays(count: number, utcOffsetMinutes: number, now: Date = new Date()): string[] {
  return Array.from({ length: count }, (_, i) => dayKey(new Date(now.getTime() - (count - 1 - i) * 86400000).toISOString(), utcOffsetMinutes));
}

// localUtcOffsetMinutes — сдвиг часового пояса устройства от UTC в минутах (UTC+5 = 300)
export function localUtcOffsetMinutes(): number {
  return -new Date().getTimezoneOffset();
}

// normalizeProgress — приводит ответ сервера к ProgressSummary: points и measure бывают null, если упражнение не выбрано
export function normalizeProgress(body: Partial<ProgressSummary> | null | undefined): ProgressSummary {
  const labels = { complete: 0, incomplete: 0, uncertain: 0, ...(body?.labels ?? {}) };
  return {
    exercise: body?.exercise ?? null,
    sessions: body?.sessions ?? 0,
    repetitions: body?.repetitions ?? 0,
    labels,
    shares: body?.shares ?? null,
    activity: body?.activity ?? [],
    measure: body?.measure ?? null,
    points: body?.points ?? [],
  };
}
