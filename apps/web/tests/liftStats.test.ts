import { describe, expect, it } from "vitest";
import { compareWithHistory, liftLine, liftStart, riseTime } from "@/lib/liftStats";
import type { Pose, PoseFrame } from "@/types/analysis";

// frame — кадр позы с запястьем в точке (x, y)
const frame = (x: number, y: number): PoseFrame => ({ t: 0, wrist: [x, y], hand: [[x, y]] });

describe("liftStats", () => {
  it("liftStart — среднее запястье первых 10% кадров с кистью", () => {
    const pose: Pose = { fps: 10, frames: [null, ...Array.from({ length: 20 }, (_, i) => frame(0.5, 0.8 - i * 0.01))] };
    expect(liftStart(pose)).toEqual([0.5, 0.795]);
    expect(liftStart({ fps: 10, frames: [null, null] })).toBeNull();
  });

  it("liftLine — вертикаль от уровня старта до запястья, null без кисти", () => {
    const pose: Pose = { fps: 10, frames: [frame(0.5, 0.8), frame(0.5, 0.8), frame(0.6, 0.4), null] };
    expect(liftLine(pose, 2)).toEqual({ start: [0.5, 0.8], foot: [0.6, 0.8], wrist: [0.6, 0.4] });
    expect(liftLine(pose, 3)).toBeNull();
  });

  it("riseTime — от 10% до 90% подъёма, пропуски не мешают", () => {
    expect(riseTime({ fps: 10, values: [0, 0, 0.5, 1, null, 2, 3, 4, 4, 3, 1] })).toBe(0.5);
    expect(riseTime({ fps: 10, values: [1, 1, 1] })).toBeNull();
    expect(riseTime({ fps: 10, values: [] })).toBeNull();
  });

  it("compareWithHistory — разница с прошлой попыткой и лучший результат", () => {
    const history = [
      { at: "2026-11-20T10:00:00Z", value: 2.0, riseS: 1.5 },
      { at: "2026-11-22T10:00:00Z", value: 3.1, riseS: 1.2 },
      { at: "2026-11-23T10:00:00Z", value: null, riseS: null },
    ];
    const r = compareWithHistory({ at: "2026-11-24T10:00:00Z", value: 3.5, riseS: 1.0 }, history);
    expect(r.previous).toEqual({ at: "2026-11-22T10:00:00Z", valueDelta: 0.4, riseDelta: -0.2 });
    expect(r.best).toBe(3.5);
    expect(r.isBest).toBe(true);
    const first = compareWithHistory({ at: "2026-11-19T10:00:00Z", value: 1.0, riseS: null }, history);
    expect(first.previous).toBeNull();
    expect(first.isBest).toBe(false);
  });
});
