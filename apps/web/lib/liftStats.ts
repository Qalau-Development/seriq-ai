import type { Point, Pose, Series } from "@/types/analysis";

const START_SHARE = 0.1;
const RISE_FROM = 0.1;
const RISE_TO = 0.9;

export interface LiftAttempt {
  at: string;
  value: number | null;
  riseS: number | null;
}

export interface LiftComparison {
  previous: { at: string; valueDelta: number | null; riseDelta: number | null } | null;
  best: number | null;
  isBest: boolean;
}

// round1 — округление до 0,1, как значения в ответе API
function round1(v: number): number {
  return Math.round(v * 10) / 10;
}

// liftStart — точка старта подъёма: среднее положение запястья в первых 10% кадров с кистью, как в движке E01
export function liftStart(pose: Pose | undefined): Point | null {
  const wrists = (pose?.frames ?? []).filter((f) => f !== null).map((f) => f.wrist);
  if (wrists.length === 0) return null;
  const first = wrists.slice(0, Math.max(1, Math.round(wrists.length * START_SHARE)));
  return [first.reduce((s, p) => s + p[0], 0) / first.length, first.reduce((s, p) => s + p[1], 0) / first.length];
}

// liftLine — линия подъёма для кадра: уровень старта и вертикаль от него до запястья; null, если кисти в кадре нет
export function liftLine(pose: Pose | undefined, index: number): { start: Point; foot: Point; wrist: Point } | null {
  const start = liftStart(pose);
  const frame = pose?.frames[index];
  if (!start || !frame) return null;
  return { start, foot: [frame.wrist[0], start[1]], wrist: frame.wrist };
}

// riseTime — секунды подъёма: от 10% до 90% максимума ряда; null, если подъёма нет или ряд пуст
export function riseTime(series: Series | undefined): number | null {
  const values = series?.values ?? [];
  const known = values.filter((v): v is number => v !== null);
  if (known.length === 0 || !series || series.fps <= 0) return null;
  const base = known[0];
  const peak = Math.max(...known);
  const range = peak - base;
  if (range <= 0) return null;
  const from = values.findIndex((v) => v !== null && v - base >= RISE_FROM * range);
  const to = values.findIndex((v) => v !== null && v - base >= RISE_TO * range);
  if (from < 0 || to < from) return null;
  return round1((to - from) / series.fps);
}

// compareWithHistory — сравнение с прошлой попыткой того же упражнения и лучший результат по измеренному значению
export function compareWithHistory(current: LiftAttempt, history: LiftAttempt[]): LiftComparison {
  const earlier = history.filter((a) => a.at < current.at && a.value !== null).sort((a, b) => (a.at < b.at ? 1 : -1));
  const prev = earlier[0];
  const values = [...earlier.map((a) => a.value as number), ...(current.value !== null ? [current.value] : [])];
  const best = values.length ? Math.max(...values) : null;
  return {
    previous: prev
      ? {
          at: prev.at,
          valueDelta: current.value !== null ? round1(current.value - (prev.value as number)) : null,
          riseDelta: current.riseS !== null && prev.riseS !== null ? round1(current.riseS - prev.riseS) : null,
        }
      : null,
    best,
    isBest: current.value !== null && earlier.length > 0 && current.value === best && earlier.every((a) => (a.value as number) < current.value!),
  };
}
