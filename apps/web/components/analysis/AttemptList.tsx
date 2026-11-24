import { CircleCheck, RotateCcw } from "lucide-react";
import type { ExerciseId } from "@/types/analysis";
import type { LocalAttempt } from "@/lib/history";
import { resultTitle } from "@/lib/resultText";
import { confidenceLevel } from "@/lib/confidence";
import { formatTime, type Dict } from "@/lib/i18n";

// AttemptList — список повторений занятия: номер, время, итог как на экране результата и уверенность
export function AttemptList({ attempts, exercise, t }: { attempts: LocalAttempt[]; exercise: ExerciseId; t: Dict }) {
  return (
    <ol className="space-y-3">
      {attempts.map((a, i) => {
        const done = a.verdict === "completed";
        return (
          <li key={a.analysis_id} className="flex items-start gap-4 rounded-2xl bg-surface p-4">
            {done ? (
              <CircleCheck aria-hidden className="mt-1 size-8 shrink-0 text-accent" />
            ) : (
              <RotateCcw aria-hidden className="mt-1 size-8 shrink-0 text-neutral-ink" />
            )}
            <div className="min-w-0 flex-1">
              <p className="text-base text-muted">
                {t.attempt_n} {i + 1} · {formatTime(a.at)}
              </p>
              <p className="text-lg font-semibold">{resultTitle(t, a.label, exercise)}</p>
              <p className="text-base text-muted">
                {t.confidence_title}: {t[`confidence_${confidenceLevel(a.confidence)}`]}
              </p>
            </div>
          </li>
        );
      })}
    </ol>
  );
}
