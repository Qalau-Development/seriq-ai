import { useMemo } from "react";
import type { ExerciseId } from "@/types/analysis";
import { useSessions } from "@/lib/history";
import { computeProgress, localUtcOffsetMinutes, type ProgressSummary } from "@/lib/progress";

// useProgress — счёт повторений для страницы «Мой прогресс»; null, пока страница не загрузилась
export function useProgress(exercise: ExerciseId | null): { summary: ProgressSummary | null; fromDevice: boolean; failed: boolean } {
  const sessions = useSessions();
  const summary = useMemo(
    () => (sessions === null ? null : computeProgress(sessions, exercise, localUtcOffsetMinutes())),
    [sessions, exercise],
  );
  return { summary, fromDevice: true, failed: false };
}
