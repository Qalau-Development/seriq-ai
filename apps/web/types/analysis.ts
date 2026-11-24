export type Verdict = "completed" | "check_instructions";
export type CycleLabel = "complete" | "incomplete" | "uncertain";

export interface CycleResult {
  index: number;
  start_s: number;
  end_s: number;
  label: CycleLabel;
  confidence: number;
  verdict: Verdict;
}

export type ExerciseId = "E01" | "E02" | "E03" | "E04";
export type MeasureName = "elbow_angle" | "wrist_lift" | "hand_openness" | "lift_height";
export type MeasureUnit = "deg" | "percent" | "hand_lengths";

export interface Series {
  fps: number;
  values: (number | null)[];
}

export interface Measure {
  name: MeasureName;
  unit: MeasureUnit;
  value: number | null;
  series: Series;
}

export interface AnalysisResult {
  status: "ok";
  analysis_id: string;
  source: "mock" | "model";
  model_version: string;
  exercise: ExerciseId;
  verdict: Verdict;
  summary: { total: number; complete: number; incomplete: number; uncertain: number };
  cycles: CycleResult[];
  angle_series?: { fps: number; unit: "deg"; values: (number | null)[] };
  measure?: Measure;
  warnings: string[];
  processing_ms: number;
  pose?: Pose;
}

export type Point = [number, number];

export interface PoseFrame {
  t: number;
  wrist: Point;
  hand: Point[];
}

export interface Pose {
  fps: number;
  elbow?: Point;
  frames: (PoseFrame | null)[];
}

export interface ApiError {
  status: "error";
  error: { code: string; message: string };
}
