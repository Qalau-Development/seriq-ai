"use client";

import { Suspense } from "react";
import { useSearchParams } from "next/navigation";
import { useLang } from "@/lib/i18n";
import { useCatalog } from "@/lib/catalog";
import { exerciseAvailability, exerciseDef, parseExercise } from "@/lib/exercises";
import { ButtonLink } from "@/components/ui/Button";
import { Notice } from "@/components/ui/Notice";
import { instructionItems } from "@/lib/voiceClips";
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
    <div className="flex flex-col gap-8">
      <div className="flex flex-col gap-5">
        <h1 className="text-[30px] leading-9 font-extrabold tracking-[-0.01em] text-balance sm:text-[34px] sm:leading-[42px] lg:text-[40px] lg:leading-[48px]">
          {t[def.titleKey]}: {t.instruction_title.toLowerCase()}
        </h1>
        <SpeakButton items={instructionItems(t, def)} />
      </div>
      <div className="grid items-start gap-8 lg:grid-cols-[7fr_5fr]">
        <div className="flex flex-col gap-5">
          {def.hasVideo && <InstructionVideo t={t} />}
          <InstructionSteps t={t} keys={def.stepKeys} />
        </div>
        <div className="flex flex-col gap-5">
          <FilmingTips t={t} keys={def.tipKeys} />
          {state === "ready" && <ButtonLink href={`/session?e=${id}`}>{t.ready}</ButtonLink>}
          {state === "soon" && (
            <>
              <Notice kind="info">{t.exercise_soon_hint}</Notice>
              <ButtonLink href="/" variant="secondary">
                {t.back_to_exercises}
              </ButtonLink>
            </>
          )}
          {state === "loading" && <p className="text-lg text-muted">{t.loading}</p>}
        </div>
      </div>
    </div>
  );
}
