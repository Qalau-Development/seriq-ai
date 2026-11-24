import { Check, RotateCcw } from "lucide-react";
import type { ExerciseId } from "@/types/analysis";
import type { LocalAttempt } from "@/lib/history";
import { resultTitle } from "@/lib/resultText";
import { confidenceLevel } from "@/lib/confidence";
import { formatTime, type Dict } from "@/lib/i18n";

// AttemptList — плитки повторений занятия: номер и время, итог как на экране результата, уверенность
export function AttemptList({ attempts, exercise, t }: { attempts: LocalAttempt[]; exercise: ExerciseId; t: Dict }) {
  return (
    <ol className="grid gap-3 sm:grid-cols-2 sm:gap-5 lg:grid-cols-3 lg:gap-6">
      {attempts.map((a, i) => {
        const done = a.verdict === "completed";
        return (
          <li key={a.analysis_id} className="flex items-start gap-3.5 rounded-[22px] border border-line bg-surface p-[18px] shadow-card sm:gap-4 sm:rounded-3xl sm:p-[22px]">
            <span
              aria-hidden
              className={`flex size-11 shrink-0 items-center justify-center rounded-full sm:size-12 ${done ? "bg-accent text-on-accent" : "bg-brand text-white"}`}
            >
              {done ? <Check className="size-[26px]" strokeWidth={3.2} /> : <RotateCcw className="size-6" strokeWidth={2.6} />}
            </span>
            <div className="flex min-w-0 flex-col gap-0.5">
              <span className="text-base leading-[22px] font-semibold text-muted">
                {t.attempt_n} {i + 1} · {formatTime(a.at)}
              </span>
              <span className="text-lg leading-[26px] font-bold text-ink">{resultTitle(t, a.label, exercise)}</span>
              <span className="text-base leading-6 font-medium text-muted">
                {t.confidence_title}: {t[`confidence_${confidenceLevel(a.confidence)}`]}
              </span>
            </div>
          </li>
        );
      })}
    </ol>
  );
}
