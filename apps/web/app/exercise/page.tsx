"use client";

import { Suspense } from "react";
import { useSearchParams } from "next/navigation";
import { useLang } from "@/lib/i18n";
import { useCatalog } from "@/lib/catalog";
import { exerciseAvailability, exerciseDef, parseExercise } from "@/lib/exercises";
import { ButtonLink } from "@/components/ui/Button";
import { SpeakButton } from "@/components/ui/SpeakButton";
import { InstructionVideo } from "@/components/exercise/InstructionVideo";
import { InstructionSteps } from "@/components/exercise/InstructionSteps";
import { FilmingTips } from "@/components/exercise/FilmingTips";

// ExercisePage — инструкция к упражнению; код упражнения читается из адреса (?e=E04), без него E02
export default function ExercisePage() {
  return (
    <Suspense>
      <ExerciseView />
    </Suspense>
  );
}

// ExerciseView — шаги, советы по съёмке и кнопка перехода к записи
function ExerciseView() {
  const { t } = useLang();
  const id = parseExercise(useSearchParams().get("e"));
  const def = exerciseDef(id);
  const state = exerciseAvailability(useCatalog(), id);
  return (
    <div className="space-y-8">
      <h1 className="text-3xl font-bold">
        {t[def.titleKey]}: {t.instruction_title.toLowerCase()}
      </h1>
      <SpeakButton
        text={[t[def.titleKey], ...def.stepKeys.map((k) => t[k]), t.tips_title, ...def.tipKeys.map((k) => t[k])].join(". ")}
      />
      {def.hasVideo && <InstructionVideo t={t} />}
      <InstructionSteps t={t} keys={def.stepKeys} />
      <FilmingTips t={t} keys={def.tipKeys} />
      {state === "ready" && (
        <ButtonLink href={`/session?e=${id}`} className="w-full sm:w-auto">
          {t.ready}
        </ButtonLink>
      )}
      {state === "soon" && (
        <div className="space-y-4">
          <p className="rounded-2xl bg-neutral-soft p-5 text-lg font-semibold text-neutral-ink">{t.exercise_soon_hint}</p>
          <ButtonLink href="/" variant="secondary" className="w-full sm:w-auto">
            {t.back_to_exercises}
          </ButtonLink>
        </div>
      )}
      {state === "loading" && <p className="text-lg text-muted">{t.loading}</p>}
    </div>
  );
}
