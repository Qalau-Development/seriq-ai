import { CircleCheck, RotateCcw } from "lucide-react";
import type { LocalAttempt } from "@/lib/history";
import { confidenceLevel } from "@/lib/confidence";
import type { Dict } from "@/lib/i18n";

// AttemptList — список повторений занятия: номер, время, вердикт, метка и уверенность
export function AttemptList({ attempts, t, locale }: { attempts: LocalAttempt[]; t: Dict; locale: string }) {
  const time = new Intl.DateTimeFormat(locale, { hour: "2-digit", minute: "2-digit" });
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
                {t.attempt_n} {i + 1} · {time.format(new Date(a.at))}
              </p>
              <p className="text-lg font-semibold">{t[`verdict_${a.verdict}`]}</p>
              <p className="text-base text-muted">
                {!done && `${t[`label_${a.label}`]} · `}
                {t.confidence_title}: {t[`confidence_${confidenceLevel(a.confidence)}`]}
              </p>
            </div>
          </li>
        );
      })}
    </ol>
  );
}
