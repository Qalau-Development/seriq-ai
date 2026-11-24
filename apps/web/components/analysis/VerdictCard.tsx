import { CircleCheck, RotateCcw } from "lucide-react";
import type { AnalysisResult } from "@/types/analysis";
import { fill, type Dict } from "@/lib/i18n";
import { Button, ButtonLink } from "@/components/ui/Button";
import { ConfidenceMeter } from "@/components/analysis/ConfidenceMeter";
import { MockBadge } from "@/components/analysis/MockBadge";
import { WarningList } from "@/components/analysis/WarningList";
import { AngleChart } from "@/components/analysis/AngleChart";

// maxAngle — наибольший угол локтя в записи без пропусков, округлённый до целого
function maxAngle(values: (number | null)[]): number | null {
  const known = values.filter((v): v is number => v !== null);
  return known.length > 0 ? Math.round(Math.max(...known)) : null;
}

// VerdictCard — результат анализа: что получилось, на сколько разогнулась рука, кнопки, график и уверенность
export function VerdictCard({ result, onAnother, t }: { result: AnalysisResult; onAnother: () => void; t: Dict }) {
  const cycle = result.cycles[0];
  const label = cycle?.label ?? "uncertain";
  const done = label === "complete";
  const max = maxAngle(result.angle_series.values);
  const line = max === null ? t[`result_hint_${label}`] : fill(t[`result_line_${label}`], { max });

  return (
    <div className="space-y-6">
      {result.source === "mock" && <MockBadge t={t} />}
      <div
        className={`flex items-start gap-4 rounded-2xl p-6 ${done ? "bg-accent-soft text-accent" : "bg-neutral-soft text-neutral-ink"}`}
      >
        {done ? (
          <CircleCheck aria-hidden className="size-12 shrink-0 sm:size-14" />
        ) : (
          <RotateCcw aria-hidden className="size-12 shrink-0 sm:size-14" />
        )}
        <div className="min-w-0 space-y-2">
          <p className="text-2xl font-bold break-words hyphens-auto sm:text-3xl">{t[`result_title_${label}`]}</p>
          {line && <p className="text-lg text-ink">{line}</p>}
        </div>
      </div>
      <div className="flex flex-col gap-3 sm:flex-row">
        <Button onClick={onAnother}>
          <RotateCcw aria-hidden className="size-6" />
          {t.another_attempt}
        </Button>
        <ButtonLink href="/exercise" variant="secondary">
          {t.watch_instruction}
        </ButtonLink>
      </div>
      <AngleChart result={result} t={t} />
      <WarningList warnings={result.warnings} t={t} />
      {cycle && <ConfidenceMeter confidence={cycle.confidence} t={t} />}
    </div>
  );
}
