import { useEffect, useMemo, useState } from "react";
import type { ExerciseId } from "@/types/analysis";
import { useSessions } from "@/lib/history";
import { useAccountMode, useHistoryVersion } from "@/lib/historyView";
import { computeProgress, localUtcOffsetMinutes, type ProgressSummary } from "@/lib/progress";
import { fetchProgress } from "@/lib/serverHistory";
import { syncNow } from "@/lib/syncRuntime";

// useProgress — счёт повторений: у гостя считается из занятий на устройстве, у вошедшего приходит с сервера (GET /progress/summary); без связи берутся занятия аккаунта с устройства
export function useProgress(exercise: ExerciseId | null): { summary: ProgressSummary | null; failed: boolean } {
  const mode = useAccountMode();
  const sessions = useSessions();
  const v = useHistoryVersion();
  const userId = mode.kind === "account" ? mode.userId : null;
  const key = `${userId}:${exercise}:${v}`;
  const [remote, setRemote] = useState<{ key: string; summary: ProgressSummary | null; failed: boolean } | null>(null);

  useEffect(() => {
    if (!userId) return;
    let alive = true;
    (async () => {
      await syncNow();
      try {
        const summary = await fetchProgress(exercise, localUtcOffsetMinutes());
        if (alive) setRemote({ key, summary, failed: false });
      } catch {
        if (alive) setRemote({ key, summary: null, failed: true });
      }
    })();
    return () => {
      alive = false;
    };
  }, [userId, exercise, key]);

  const local = useMemo(() => {
    if (sessions === null || mode.kind === "loading") return null;
    return computeProgress(
      sessions.filter((s) => (userId ? s.owner === userId : !s.owner)),
      exercise,
      localUtcOffsetMinutes(),
    );
  }, [sessions, exercise, userId, mode.kind]);

  if (!userId) return { summary: local, failed: false };
  if (remote?.key === key) return remote.failed ? { summary: local, failed: true } : { summary: remote.summary, failed: false };
  return { summary: null, failed: false };
}
