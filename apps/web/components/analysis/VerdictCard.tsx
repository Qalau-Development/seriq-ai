import { Check, RotateCcw } from "lucide-react";
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
import { LiftSummary } from "@/components/analysis/LiftSummary";
import { liftStart } from "@/lib/liftStats";

// VerdictCard — результат анализа: итог и измеренное значение, кнопки, видео с точками рядом с графиком, уверенность
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
  const [main, ...rest] = lines.filter(Boolean) as string[];

  return (
    <div className="flex flex-col gap-6 lg:gap-7">
      {result.source === "mock" && <MockBadge t={t} />}
      <section
        className={`flex flex-col gap-3 rounded-[28px] border-2 p-6 sm:flex-row sm:items-center sm:gap-8 sm:rounded-[32px] sm:px-10 sm:py-9 ${
          done ? "border-accent-line bg-accent-soft" : "border-brand-soft-2 bg-neutral-soft"
        }`}
      >
        <span
          aria-hidden
          className={`flex size-16 shrink-0 items-center justify-center rounded-full sm:size-24 ${done ? "bg-accent text-on-accent" : "bg-brand text-white"}`}
        >
          {done ? <Check className="size-8 sm:size-12" strokeWidth={3.4} /> : <RotateCcw className="size-8 sm:size-11" strokeWidth={2.6} />}
        </span>
        <div className="flex min-w-0 flex-col gap-2">
          <h2 className={`text-[32px] leading-[38px] font-extrabold tracking-[-0.01em] text-balance sm:text-[40px] sm:leading-12 ${done ? "text-ink" : "text-neutral-ink"}`}>
            {resultTitle(t, label, exercise)}
          </h2>
          {main && <p className="text-xl leading-[30px] font-semibold text-pretty text-ink sm:text-[22px] sm:leading-8">{main}</p>}
          {rest.map((line) => (
            <p key={line} className="text-lg leading-[27px] font-medium text-pretty text-neutral-ink sm:text-xl sm:leading-[30px]">
              {line}
            </p>
          ))}
        </div>
      </section>
      <div className="flex flex-col gap-3 sm:flex-row sm:flex-wrap sm:gap-4">
        <SpeakButton className="max-sm:order-2" text={[resultTitle(t, label, exercise), ...lines].filter(Boolean).join(". ")} />
        <Button onClick={onAnother}>
          <RotateCcw aria-hidden className="size-6" />
          {t.another_attempt}
        </Button>
        <ButtonLink href={`/exercise?e=${exercise}`} variant="secondary">
          {t.watch_instruction}
        </ButtonLink>
      </div>
      <WarningList warnings={result.warnings} exercise={exercise} t={t} />
      <div className="grid items-stretch gap-6 lg:grid-cols-2 [&>:only-child]:col-span-full">
        {videoUrl && result.pose && <PoseVideo src={videoUrl} pose={result.pose} liftStart={exercise === "E01" ? liftStart(result.pose) : null} t={t} />}
        <AngleChart result={result} t={t} />
      </div>
      <LiftSummary result={result} t={t} />
      {cycle && <ConfidenceMeter confidence={cycle.confidence} t={t} />}
    </div>
  );
}
