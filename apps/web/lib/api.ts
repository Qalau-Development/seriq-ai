import type { AnalysisResult, ApiError } from "@/types/analysis";
import { fallbackCatalog, parseCatalog, type CatalogEntry } from "@/lib/exercises";

export const MAX_UPLOAD_MB = 100;
export const ALLOWED_EXTENSIONS = [".mp4", ".mov", ".webm"];

// AnalysisError — ошибка анализа с кодом из контракта API
export class AnalysisError extends Error {
  constructor(public code: string, public httpStatus?: number) {
    super(code);
  }
}

// checkVideoFile — проверяет расширение и размер файла до отправки, возвращает код ошибки или null
export function checkVideoFile(file: File): string | null {
  const name = file.name.toLowerCase();
  if (!ALLOWED_EXTENSIONS.some((ext) => name.endsWith(ext))) return "unsupported_format";
  if (file.size === 0) return "empty_file";
  if (file.size > MAX_UPLOAD_MB * 1024 * 1024) return "file_too_large";
  return null;
}

// analyzeVideo — отправляет видео на анализ и возвращает результат
export async function analyzeVideo(file: File, mockScenario?: string): Promise<AnalysisResult> {
  const form = new FormData();
  form.append("video", file);
  form.append("exercise", "E02");
  const query = mockScenario ? `?mock_scenario=${encodeURIComponent(mockScenario)}` : "";

  let res: Response;
  try {
    res = await fetch(`/api/v1/analysis${query}`, { method: "POST", body: form });
  } catch {
    throw new AnalysisError("network_error");
  }
  const body = (await res.json().catch(() => null)) as AnalysisResult | ApiError | null;
  if (res.ok && body?.status === "ok") return body;
  throw new AnalysisError(body?.status === "error" ? body.error.code : "internal_error", res.status);
}

// fetchCatalog — каталог упражнений с сервера; при любой ошибке запасной список, где запись доступна только для E02
export async function fetchCatalog(): Promise<CatalogEntry[]> {
  try {
    const res = await fetch("/api/v1/exercises", { signal: AbortSignal.timeout(8000) });
    if (!res.ok) return fallbackCatalog();
    return parseCatalog(await res.json()) ?? fallbackCatalog();
  } catch {
    return fallbackCatalog();
  }
}
