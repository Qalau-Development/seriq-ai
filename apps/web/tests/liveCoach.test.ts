import { describe, expect, it } from "vitest";
import { LiveCoach, OneEuro, elbowCenter, fillGaps, jointAngle, smooth3, type CueKey, type Point } from "@/lib/liveCoach";

const ELBOW: Point = [500, 500];
const HAND_LEN = 50;
const RADIUS = 3.56 * HAND_LEN;

// hand — 21 точка кисти: запястье на дуге вокруг локтя, середина ладони дальше по предплечью; elevation — подъём предплечья в градусах
function hand(elevation: number): Point[] {
  const e = (elevation * Math.PI) / 180;
  const dir: Point = [Math.cos(e), -Math.sin(e)];
  const wrist: Point = [ELBOW[0] + RADIUS * dir[0], ELBOW[1] + RADIUS * dir[1]];
  const mcp: Point = [wrist[0] + HAND_LEN * dir[0], wrist[1] + HAND_LEN * dir[1]];
  return Array.from({ length: 21 }, (_, i) => (i === 9 ? mcp : wrist));
}

// run — прогоняет повтор по подъёмам предплечья с шагом 0,1 с и собирает подсказки
function run(elevations: number[]): { coach: LiveCoach; cues: CueKey[] } {
  const coach = new LiveCoach();
  const cues: CueKey[] = [];
  elevations.forEach((e, i) => cues.push(...coach.update(i / 10, hand(e))));
  return { coach, cues };
}

// ramp — равномерное изменение подъёма за n кадров
function ramp(from: number, to: number, n: number): number[] {
  return Array.from({ length: n }, (_, i) => from + ((to - from) * (i + 1)) / n);
}

describe("liveCoach", () => {
  it("smooth3 усредняет по трём значениям и сохраняет пропуски", () => {
    expect(smooth3([0, 3, 6, NaN, 9])).toEqual([1.5, 3, 4.5, NaN, 9]);
  });

  it("OneEuro не сдвигает неподвижные точки", () => {
    const f = new OneEuro();
    const p: Point[] = [[10, 20]];
    f.filter(0, p);
    expect(f.filter(0.1, p)).toEqual([[10, 20]]);
  });

  it("elbowCenter находит локоть по дуге запястья", () => {
    const c = elbowCenter(ramp(80, 0, 30).map(hand));
    expect(c).not.toBeNull();
    expect(Math.hypot(c![0] - ELBOW[0], c![1] - ELBOW[1])).toBeLessThan(2);
  });

  it("полный повтор: разогните, задержите, вернитесь; повтор закончен", () => {
    const { coach, cues } = run([...Array(15).fill(80), ...ramp(80, 0, 30), ...Array(20).fill(0)]);
    expect(cues.filter((c) => c !== "slower")).toEqual(["start", "hold", "back"]);
    expect(coach.finished).toBe(true);
    expect(coach.peakExt).toBeGreaterThan(75);
  });

  it("неполный повтор: просьба разогнуть ещё и конец повтора при возврате", () => {
    const { coach, cues } = run([...Array(15).fill(80), ...ramp(80, 50, 20), ...Array(25).fill(50), ...ramp(50, 80, 20), ...Array(5).fill(80)]);
    expect(cues[0]).toBe("start");
    expect(cues).toContain("more");
    expect(cues).not.toContain("hold");
    expect(cues[cues.length - 1]).toBe("back");
    expect(coach.finished).toBe(true);
  });

  it("выброс точки считается нестабильным кадром и не ломает повтор", () => {
    const coach = new LiveCoach();
    const cues: CueKey[] = [];
    const frames = [...Array(15).fill(80), ...ramp(80, 0, 30), ...Array(20).fill(0)].map(hand);
    frames[25] = hand(40).map(([x, y]) => [x + 900, y + 400] as Point);
    let unstableAt = -1;
    frames.forEach((p, i) => {
      cues.push(...coach.update(i / 10, p));
      if (coach.unstable && unstableAt < 0) unstableAt = i;
    });
    expect(unstableAt).toBe(25);
    expect(cues.filter((c) => c !== "slower")).toEqual(["start", "hold", "back"]);
  });

  it("после nextRep следующий повтор начинается, только когда рука вернулась вниз и замерла", () => {
    const coach = new LiveCoach();
    const cues: CueKey[] = [];
    let i = 0;
    const feed = (elevations: number[]) => elevations.forEach((e) => cues.push(...coach.update(i++ / 10, hand(e))));
    feed([...Array(15).fill(80), ...ramp(80, 0, 30), ...Array(20).fill(0)]);
    expect(coach.finished).toBe(true);
    coach.nextRep();
    feed(Array(20).fill(0));
    expect(cues.filter((c) => c === "start")).toHaveLength(1);
    feed([...ramp(0, 80, 20), ...Array(15).fill(80), ...ramp(80, 0, 30), ...Array(20).fill(0)]);
    expect(cues.filter((c) => c !== "slower")).toEqual(["start", "hold", "back", "start", "hold", "back"]);
  });

  it("jointAngle — 180° для прямой руки, 90° для согнутой; fillGaps заполняет только короткие пропуски", () => {
    expect(jointAngle([[0, 0], [100, 0], [200, 0]])).toBeCloseTo(180);
    expect(jointAngle([[0, 0], [100, 0], [100, 100]])).toBeCloseTo(90);
    expect(fillGaps([1, NaN, 3, NaN, NaN, NaN, NaN, 8])).toEqual([1, 2, 3, NaN, NaN, NaN, NaN, 8]);
  });

  it("режим pose: рука без стола, угол в локте по плечу, локтю и запястью; полный повтор", () => {
    const coach = new LiveCoach("pose");
    const cues: CueKey[] = [];
    const shoulder: Point = [300, 200];
    const elbow: Point = [300, 450];
    // arm — запястье под углом angle в локте (90° — согнута, 180° — прямая)
    const arm = (angle: number): [Point, Point, Point] => {
      const a = ((180 - angle) * Math.PI) / 180;
      return [shoulder, elbow, [elbow[0] + 200 * Math.sin(a), elbow[1] + 200 * Math.cos(a)]];
    };
    const angles = [...Array(15).fill(90), ...ramp(90, 175, 30), ...Array(20).fill(175)];
    angles.forEach((g, i) => cues.push(...coach.updatePose(i / 10, arm(g), 0.9)));
    expect(cues.filter((c) => c !== "slower")).toEqual(["start", "hold", "back"]);
    expect(coach.peakExt).toBeGreaterThan(75);
  });

  it("режим pose: при низкой уверенности точек угол не считается, это пропуск", () => {
    const coach = new LiveCoach("pose");
    expect(coach.updatePose(0, [[0, 0], [100, 0], [200, 0]], 0.2)).toEqual(["show_hand"]);
    expect(coach.arm).toBeNull();
  });

  it("без кисти просит показать руку", () => {
    const coach = new LiveCoach();
    expect(coach.update(0, null)).toEqual(["show_hand"]);
  });
});
