import { CircleCheck, RotateCcw } from "lucide-react";
import type { AnalysisResult } from "@/types/analysis";
import type { Dict } from "@/lib/i18n";
import { ButtonLink } from "@/components/ui/Button";
import { ConfidenceMeter } from "@/components/analysis/ConfidenceMeter";
import { MockBadge } from "@/components/analysis/MockBadge";
import { WarningList } from "@/components/analysis/WarningList";

// VerdictCard — результат анализа: вердикт, метка цикла, уверенность и подсказки
export function VerdictCard({ result, t }: { result: AnalysisResult; t: Dict }) {
  const done = result.verdict === "completed";
  const cycle = result.cycles[0];
  return (
    <div className="space-y-5">
      {result.source === "mock" && <MockBadge t={t} />}
      <div
        className={`flex items-center gap-4 rounded-2xl p-6 ${done ? "bg-accent-soft text-accent" : "bg-neutral-soft text-neutral-ink"}`}
      >
        {done ? (
          <CircleCheck aria-hidden className="size-14 shrink-0" />
        ) : (
          <RotateCcw aria-hidden className="size-14 shrink-0" />
        )}
        <div>
          <p className="text-3xl font-bold">{t[`verdict_${result.verdict}`]}</p>
          {cycle && <p className="mt-1 text-lg text-ink">{t[`label_${cycle.label}`]}</p>}
        </div>
      </div>
      {cycle && <ConfidenceMeter confidence={cycle.confidence} t={t} />}
      {!done && (
        <div className="space-y-3">
          <p className="text-lg">{t.verdict_check_instructions_hint}</p>
          <ButtonLink href="/exercise" variant="secondary" className="w-full sm:w-auto">
            {t.watch_instruction}
          </ButtonLink>
        </div>
      )}
      <WarningList warnings={result.warnings} t={t} />
    </div>
  );
}
