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

export interface AnalysisResult {
  status: "ok";
  analysis_id: string;
  source: "mock" | "model";
  model_version: string;
  exercise: "E02";
  verdict: Verdict;
  summary: { total: number; complete: number; incomplete: number; uncertain: number };
  cycles: CycleResult[];
  angle_series: { fps: number; unit: "deg"; values: (number | null)[] };
  warnings: string[];
  processing_ms: number;
}

export interface ApiError {
  status: "error";
  error: { code: string; message: string };
}
