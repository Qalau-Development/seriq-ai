"use client";

import { useLang } from "@/lib/i18n";
import { ButtonLink } from "@/components/ui/Button";
import { InstructionVideo } from "@/components/exercise/InstructionVideo";
import { InstructionSteps } from "@/components/exercise/InstructionSteps";
import { FilmingTips } from "@/components/exercise/FilmingTips";

// ExercisePage — инструкция к упражнению E02
export default function ExercisePage() {
  const { t } = useLang();
  return (
    <div className="space-y-8">
      <h1 className="text-3xl font-bold">
        {t.exercise_e02_title}: {t.instruction_title.toLowerCase()}
      </h1>
      <InstructionVideo t={t} />
      <InstructionSteps t={t} />
      <FilmingTips t={t} />
      <ButtonLink href="/session" className="w-full sm:w-auto">
        {t.ready}
      </ButtonLink>
    </div>
  );
}
