import { CircleCheck, RotateCcw } from "lucide-react";
import type { AnalysisResult } from "@/types/analysis";
import { fill, type Dict } from "@/lib/i18n";
import { resultMeasure } from "@/lib/measure";
import { measureLine } from "@/lib/measureText";
import { parseExercise } from "@/lib/exercises";
import { resultHint, resultTitle } from "@/lib/resultText";
import { Button, ButtonLink } from "@/components/ui/Button";
import { SpeakButton } from "@/components/ui/SpeakButton";
import { ConfidenceMeter } from "@/components/analysis/ConfidenceMeter";
import { MockBadge } from "@/components/analysis/MockBadge";
import { WarningList } from "@/components/analysis/WarningList";
import { AngleChart } from "@/components/analysis/AngleChart";
import { PoseVideo } from "@/components/analysis/PoseVideo";

// VerdictCard — результат анализа: что получилось, на сколько разогнулась рука, кнопки, график и уверенность
export function VerdictCard({
  result,
  videoUrl,
  onAnother,
  t,
}: {
  result: AnalysisResult;
  videoUrl?: string;
  onAnother: () => void;
  t: Dict;
}) {
  const cycle = result.cycles[0];
  const label = cycle?.label ?? "uncertain";
  const done = label === "complete";
  const measure = resultMeasure(result);
  const max = measure?.name === "elbow_angle" && measure.value !== null ? Math.round(measure.value) : null;
  const exercise = parseExercise(result.exercise);
  const elbow = measure?.name === "elbow_angle" || exercise === "E02";
  const lines = elbow
    ? [max === null ? resultHint(t, label, exercise) : fill(t[`result_line_${label}`], { max })]
    : [measure ? measureLine(t, measure) : null, done ? "" : resultHint(t, label, exercise)];

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
          <p className="text-2xl font-bold break-words hyphens-auto sm:text-3xl">{resultTitle(t, label, exercise)}</p>
          {lines.map((line) => line && <p key={line} className="text-lg text-ink">{line}</p>)}
        </div>
      </div>
      <SpeakButton
        text={[resultTitle(t, label, exercise), ...lines].filter(Boolean).join(". ")}
      />
      <div className="flex flex-col gap-3 sm:flex-row">
        <Button onClick={onAnother}>
          <RotateCcw aria-hidden className="size-6" />
          {t.another_attempt}
        </Button>
        <ButtonLink href={`/exercise?e=${exercise}`} variant="secondary">
          {t.watch_instruction}
        </ButtonLink>
      </div>
      {videoUrl && result.pose && <PoseVideo src={videoUrl} pose={result.pose} t={t} />}
      <AngleChart result={result} t={t} />
      <WarningList warnings={result.warnings} exercise={exercise} t={t} />
      {cycle && <ConfidenceMeter confidence={cycle.confidence} t={t} />}
    </div>
  );
}
