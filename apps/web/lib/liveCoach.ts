export type Point = [number, number];
export type CueKey = "show_hand" | "start" | "more" | "hold" | "slower" | "lost" | "back";
export type CoachState = "wait" | "extend" | "hold" | "return";
export type ElbowMode = "arc" | "pose";

const WRIST = 0;
const MIDDLE_MCP = 9;
const K_FOREARM = 3.56;
const MIN_POINTS = 10;
export const SAMPLE_FPS = 10;
export const TARGET_EXT = 65;
const STALL_DEG = 4;
const STALL_S = 1.5;
const FAST_SPEED = 150;
const LOST_S = 0.8;
const STILL_S = 1.0;
const HOLD_S = 1.0;
const REPEAT_S = 3;
const REPEAT_LONG_S = 8;
const SPEED_WINDOW = 4;
const REFIT_GROWTH = 1.1;
const MAX_JUMP_HAND_LENS = 2.0;
const MAX_SIZE_CHANGE = 0.4;
const MAX_GAP = 3;
export const MIN_VISIBILITY = 0.5;

// median — медиана массива чисел
function median(values: number[]): number {
  const s = [...values].sort((a, b) => a - b);
  const m = Math.floor(s.length / 2);
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2;
}

// smooth3 — скользящее среднее по 3 значениям без учёта пропусков, как smooth в движке
export function smooth3(values: number[]): number[] {
  return values.map((v, i) => {
    if (Number.isNaN(v)) return NaN;
    const window = [values[i - 1], v, values[i + 1]].filter((x) => x !== undefined && !Number.isNaN(x));
    return window.reduce((a, b) => a + b, 0) / window.length;
  });
}

// fillGaps — линейно заполняет внутренние пропуски не длиннее MAX_GAP значений, как fill_gaps в движке
export function fillGaps(values: number[]): number[] {
  const out = [...values];
  let i = 0;
  while (i < out.length) {
    if (!Number.isNaN(out[i])) {
      i++;
      continue;
    }
    let j = i;
    while (j < out.length && Number.isNaN(out[j])) j++;
    if (i > 0 && j < out.length && j - i <= MAX_GAP) {
      for (let k = i; k < j; k++) out[k] = out[i - 1] + ((out[j] - out[i - 1]) * (k - i + 1)) / (j - i + 1);
    }
    i = j;
  }
  return out;
}

// jointAngle — угол в локте между плечом и запястьем по трём точкам, 180° — рука прямая
export function jointAngle(arm: [Point, Point, Point]): number {
  const [shoulder, elbow, wrist] = arm;
  const a = [shoulder[0] - elbow[0], shoulder[1] - elbow[1]];
  const b = [wrist[0] - elbow[0], wrist[1] - elbow[1]];
  const cos = (a[0] * b[0] + a[1] * b[1]) / (Math.hypot(a[0], a[1]) * Math.hypot(b[0], b[1]) + 1e-9);
  return (Math.acos(Math.max(-1, Math.min(1, cos))) * 180) / Math.PI;
}

// OneEuro — фильтр One Euro для точек кисти: убирает дрожание в покое и почти не запаздывает при движении
export class OneEuro {
  private x: Point[] | null = null;
  private dx: Point[] | null = null;
  private t = 0;
  private minCutoff = 1.5;
  private beta = 0.01;
  private dCutoff = 1.0;

  // alpha — коэффициент сглаживания для частоты среза и шага времени
  private static alpha(cutoff: number, dt: number) {
    const tau = 1 / (2 * Math.PI * cutoff);
    return 1 / (1 + tau / dt);
  }

  // filter — сглаженные точки для нового кадра
  filter(t: number, points: Point[]): Point[] {
    if (!this.x || !this.dx || t <= this.t || t - this.t > 0.5) {
      this.x = points.map((p) => [...p] as Point);
      this.dx = points.map(() => [0, 0] as Point);
      this.t = t;
      return points.map((p) => [...p] as Point);
    }
    const dt = t - this.t;
    const aD = OneEuro.alpha(this.dCutoff, dt);
    this.x = this.x.map((prev, i) => {
      const d = this.dx![i];
      const out: Point = [0, 0];
      for (const k of [0, 1] as const) {
        const raw = (points[i][k] - prev[k]) / dt;
        d[k] = d[k] + aD * (raw - d[k]);
        const a = OneEuro.alpha(this.minCutoff + this.beta * Math.abs(d[k]), dt);
        out[k] = prev[k] + a * (points[i][k] - prev[k]);
      }
      return out;
    });
    this.t = t;
    return this.x.map((p) => [...p] as Point);
  }

  // reset — сброс после пропажи кисти
  reset() {
    this.x = this.dx = null;
  }
}

// elbowCenter — локоть как центр окружности радиуса K_FOREARM × длина кисти через точки запястья, как в движке
export function elbowCenter(hands: Point[][]): Point | null {
  const ok = hands.filter((p) => !Number.isNaN(p[WRIST][0]));
  const wrists = ok.map((p) => p[WRIST]);
  const lens = ok.map((p) => Math.hypot(p[MIDDLE_MCP][0] - p[WRIST][0], p[MIDDLE_MCP][1] - p[WRIST][1]));
  const keep = lens.map((l) => l > 0);
  if (keep.filter(Boolean).length < MIN_POINTS) return null;
  const w = wrists.filter((_, i) => keep[i]);
  const l = lens.filter((_, i) => keep[i]);
  const radius = K_FOREARM * median(l);
  const starts = ok
    .filter((_, i) => keep[i])
    .map((p, i) => {
      const dx = (p[MIDDLE_MCP][0] - p[WRIST][0]) / l[i];
      const dy = (p[MIDDLE_MCP][1] - p[WRIST][1]) / l[i];
      return [p[WRIST][0] - radius * dx, p[WRIST][1] - radius * dy] as Point;
    });
  let c: Point = [median(starts.map((s) => s[0])), median(starts.map((s) => s[1]))];
  let lambda = 1e-3;
  const cost = (cc: Point) => w.reduce((sum, p) => sum + (Math.hypot(p[0] - cc[0], p[1] - cc[1]) - radius) ** 2, 0);
  for (let iter = 0; iter < 30; iter++) {
    let a = 0, b = 0, d = 0, g0 = 0, g1 = 0;
    for (const p of w) {
      const dist = Math.hypot(p[0] - c[0], p[1] - c[1]) || 1e-9;
      const r = dist - radius;
      const j0 = -(p[0] - c[0]) / dist;
      const j1 = -(p[1] - c[1]) / dist;
      a += j0 * j0; b += j0 * j1; d += j1 * j1; g0 += j0 * r; g1 += j1 * r;
    }
    const a2 = a * (1 + lambda), d2 = d * (1 + lambda);
    const det = a2 * d2 - b * b;
    if (Math.abs(det) < 1e-12) break;
    const step: Point = [-(d2 * g0 - b * g1) / det, -(a2 * g1 - b * g0) / det];
    const next: Point = [c[0] + step[0], c[1] + step[1]];
    if (cost(next) < cost(c)) {
      c = next;
      lambda /= 10;
      if (Math.hypot(step[0], step[1]) < 1e-3) break;
    } else {
      lambda *= 10;
    }
  }
  return c;
}

// LiveCoach — живой повтор E02 по точкам кисти: подсказки и момент, когда повтор закончен
export class LiveCoach {
  state: CoachState = "wait";
  angle: number | null = null;
  ext = 0;
  peakExt = 0;
  elbow: Point | null = null;
  finished = false;
  private points: Point[][] = [];
  private times: number[] = [];
  private filterer = new OneEuro();
  private lastSeen: number | null = null;
  private lastCue: Partial<Record<CueKey, number>> = {};
  private repFrom = 0;
  private startN = 0;
  private fitN = 0;
  private fitSpan = 0;
  private side = 1;
  private holdSince: number | null = null;
  private poseAngles: number[] = [];
  private armFilter = new OneEuro();
  arm: [Point, Point, Point] | null = null;
  readonly mode: ElbowMode;

  // constructor — arc: локоть по дуге кулака (рука на столе), pose: настоящий локоть из MediaPipe Pose (без стола)
  constructor(mode: ElbowMode = "arc") {
    this.mode = mode;
  }

  // updatePose — кадр в режиме pose: плечо, локоть, запястье и их наименьшая видимость; угол в локте и псевдоточки кисти для общей логики
  updatePose(t: number, arm: [Point, Point, Point] | null, visibility: number): CueKey[] {
    if (!arm || visibility < MIN_VISIBILITY) {
      this.arm = null;
      this.poseAngles.push(NaN);
      return this.update(t, null);
    }
    const smooth = this.armFilter.filter(t, arm) as [Point, Point, Point];
    this.arm = smooth;
    this.poseAngles.push(jointAngle(smooth));
    const [, elbow, wrist] = smooth;
    const hand: Point[] = Array.from({ length: 21 }, () => [wrist[0], wrist[1]] as Point);
    hand[MIDDLE_MCP] = [wrist[0] + (wrist[0] - elbow[0]) / K_FOREARM, wrist[1] + (wrist[1] - elbow[1]) / K_FOREARM];
    return this.update(t, hand);
  }
  private lastGood: { t: number; wrist: Point; handLen: number } | null = null;
  unstable = false;

  // smoothed — последние сглаженные точки кисти для рисования
  get smoothed(): Point[] | null {
    const last = this.points[this.points.length - 1];
    return last && !Number.isNaN(last[WRIST][0]) ? last : null;
  }

  // cue — подсказка, не чаще раза в несколько секунд для одного ключа
  private cue(key: CueKey, t: number, out: CueKey[], force = false) {
    const repeat = key === "show_hand" ? REPEAT_LONG_S : REPEAT_S;
    if (force || t - (this.lastCue[key] ?? -1e9) >= repeat) {
      this.lastCue[key] = t;
      out.push(key);
    }
  }

  // repAngles — угол по сглаженным точкам повтора; локоть уточняется, только пока дуга запястья растёт
  private repAngles(): number[] | null {
    if (this.mode === "pose") {
      const series = smooth3(fillGaps(this.poseAngles.slice(this.repFrom)));
      if (this.arm) this.elbow = this.arm[1];
      return series.every((v) => Number.isNaN(v)) ? null : series;
    }
    const pts = this.points.slice(this.repFrom);
    const wrists = pts.filter((p) => !Number.isNaN(p[WRIST][0])).map((p) => p[WRIST]);
    if (wrists.length === 0) return null;
    const xs = wrists.map((p) => p[0]);
    const ys = wrists.map((p) => p[1]);
    const span = Math.max(Math.max(...xs) - Math.min(...xs), Math.max(...ys) - Math.min(...ys));
    if (!this.elbow || (pts.length - this.fitN >= 5 && span > this.fitSpan * REFIT_GROWTH)) {
      const c = elbowCenter(pts);
      if (!c) return null;
      this.elbow = c;
      this.fitN = pts.length;
      this.fitSpan = span;
      this.side = median(wrists.map((p) => p[0] - c[0])) >= 0 ? 1 : -1;
    }
    const e = this.elbow;
    return smooth3(
      pts.map((p) => {
        if (Number.isNaN(p[WRIST][0])) return NaN;
        const dx = (p[WRIST][0] - e[0]) * this.side;
        const dy = e[1] - p[WRIST][1];
        return 180 - (Math.atan2(dy, dx) * 180) / Math.PI;
      }),
    );
  }

  // startAngle — угол в начале повтора: медиана первых кадров покоя
  private startAngle(series: number[]): number {
    return median(series.slice(0, Math.max(this.startN, 5)).filter((v) => !Number.isNaN(v)));
  }

  // isOutlier — выброс: запястье прыгнуло дальше, чем рука успевает за это время, или размер кисти резко изменился
  private isOutlier(t: number, raw: Point[]): boolean {
    const handLen = Math.hypot(raw[MIDDLE_MCP][0] - raw[WRIST][0], raw[MIDDLE_MCP][1] - raw[WRIST][1]);
    const prev = this.lastGood;
    if (!prev || t - prev.t > 0.5) return false;
    const jump = Math.hypot(raw[WRIST][0] - prev.wrist[0], raw[WRIST][1] - prev.wrist[1]);
    const steps = Math.max(1, (t - prev.t) * SAMPLE_FPS);
    return jump > MAX_JUMP_HAND_LENS * prev.handLen * steps || Math.abs(handLen - prev.handLen) > MAX_SIZE_CHANGE * prev.handLen;
  }

  // update — один кадр: 21 точка кисти в пикселях или null, возвращает подсказки; выброс считается пропуском
  update(t: number, raw: Point[] | null): CueKey[] {
    const out: CueKey[] = [];
    if (this.finished) return out;
    if (this.mode === "arc" && raw && this.isOutlier(t, raw)) raw = null;
    else if (raw && this.mode === "arc") {
      const handLen = Math.hypot(raw[MIDDLE_MCP][0] - raw[WRIST][0], raw[MIDDLE_MCP][1] - raw[WRIST][1]);
      this.lastGood = { t, wrist: raw[WRIST], handLen: this.lastGood && t - this.lastGood.t <= 0.5 ? 0.8 * this.lastGood.handLen + 0.2 * handLen : handLen };
    }
    this.unstable = raw === null;
    if (!raw) {
      this.points.push(Array.from({ length: 21 }, () => [NaN, NaN] as Point));
      this.times.push(t);
      if (this.state === "wait") this.cue("show_hand", t, out);
      else if (this.lastSeen !== null && t - this.lastSeen >= LOST_S) this.cue("lost", t, out);
      this.angle = null;
      return out;
    }
    const p = this.filterer.filter(t, raw);
    this.points.push(p);
    this.times.push(t);
    this.lastSeen = t;

    if (this.state === "return") {
      const back = this.repAngles();
      const last = back ? back[back.length - 1] : NaN;
      if (!Number.isNaN(last) && last - this.startAngle(back!) > 25) return out;
    }
    if (this.state === "wait" || this.state === "return") {
      const recent = this.points.slice(-Math.round(SAMPLE_FPS * STILL_S)).map((q) => q[WRIST]);
      const handLen = Math.hypot(p[MIDDLE_MCP][0] - p[WRIST][0], p[MIDDLE_MCP][1] - p[WRIST][1]);
      const xs = recent.map((q) => q[0]);
      const ys = recent.map((q) => q[1]);
      const moving =
        recent.some((q) => Number.isNaN(q[0])) ||
        Math.max(Math.max(...xs) - Math.min(...xs), Math.max(...ys) - Math.min(...ys)) > 0.15 * handLen;
      if (!moving && this.points.length >= SAMPLE_FPS * STILL_S) {
        this.repFrom = Math.max(0, this.points.length - Math.round(SAMPLE_FPS * STILL_S));
        this.startN = this.points.length - this.repFrom;
        this.elbow = null;
        this.fitN = 0;
        this.fitSpan = 0;
        this.ext = this.peakExt = 0;
        this.holdSince = null;
        this.state = "extend";
        this.cue("start", t, out, true);
      }
      return out;
    }

    const series = this.repAngles();
    if (!series || Number.isNaN(series[series.length - 1])) return out;
    const n = series.length;
    this.angle = series[n - 1];
    this.ext = this.angle - this.startAngle(series);
    const back = n > SPEED_WINDOW ? series[n - 1 - SPEED_WINDOW] : NaN;
    const speed = Number.isNaN(back) ? 0 : ((series[n - 1] - back) * SAMPLE_FPS) / SPEED_WINDOW;
    this.peakExt = Math.max(this.peakExt, this.ext);

    if (this.state === "extend") {
      if (speed > FAST_SPEED) this.cue("slower", t, out);
      if (this.ext >= TARGET_EXT) {
        this.state = "hold";
        this.holdSince = t;
        this.cue("hold", t, out, true);
      } else if (this.peakExt > 15 && t - this.times[this.repFrom] > 2 && this.ext < this.peakExt * 0.4) {
        this.finish(out);
      } else {
        const window = series.slice(-Math.round(SAMPLE_FPS * STALL_S)).filter((v) => !Number.isNaN(v));
        if (this.ext > 10 && window.length >= SAMPLE_FPS * STALL_S && Math.max(...window) - Math.min(...window) < STALL_DEG) {
          this.cue("more", t, out);
        }
      }
    } else if (this.state === "hold") {
      if (this.ext < this.peakExt - 15) this.holdSince = t;
      if (this.holdSince !== null && t - this.holdSince >= HOLD_S) this.finish(out);
    }
    return out;
  }

  // finish — повтор закончен: запись можно отправлять на анализ, человека просим вернуться
  private finish(out: CueKey[]) {
    this.finished = true;
    this.state = "return";
    out.push("back");
  }

  // nextRep — после отправки повтора ждём, пока рука вернётся вниз и замрёт, и начинаем следующий
  nextRep() {
    this.finished = false;
    this.state = "return";
  }
}
