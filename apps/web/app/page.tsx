"use client";

import { History, Play } from "lucide-react";
import { useLang } from "@/lib/i18n";
import { useCatalog } from "@/lib/catalog";
import { EXERCISES, exerciseAvailability } from "@/lib/exercises";
import { Card } from "@/components/ui/Card";
import { ButtonLink } from "@/components/ui/Button";

// HomePage — главная: что такое SerIQ и четыре упражнения
export default function HomePage() {
  const { t } = useLang();
  const catalog = useCatalog();
  return (
    <div className="space-y-8">
      <section className="space-y-3">
        <h1 className="text-4xl font-bold">SerIQ</h1>
        <p className="text-xl">{t.app_tagline}</p>
      </section>
      <section className="space-y-4">
        <h2 className="text-2xl font-bold">{t.exercises_title}</h2>
        <p className="text-lg">{t.exercises_hint}</p>
        <div className="grid gap-4 sm:grid-cols-2">
          {EXERCISES.map((e) => {
            const state = exerciseAvailability(catalog, e.id);
            return (
              <Card key={e.id} className="flex flex-col gap-3">
                <h3 className="text-2xl font-bold">{t[e.titleKey]}</h3>
                <p className="text-lg">{t[e.descKey]}</p>
                <p className="text-lg text-muted">{t[e.measuresKey]}</p>
                <div className="mt-auto pt-2">
                  {state === "ready" && (
                    <ButtonLink href={`/exercise?e=${e.id}`} className="w-full">
                      <Play aria-hidden className="size-6" />
                      {t.start_session}
                      <span className="sr-only">: {t[e.titleKey]}</span>
                    </ButtonLink>
                  )}
                  {state === "soon" && (
                    <span className="inline-flex min-h-14 items-center rounded-xl border-2 border-neutral-ink bg-neutral-soft px-6 text-lg font-semibold text-neutral-ink">
                      {t.exercise_soon}
                    </span>
                  )}
                  {state === "loading" && <p className="text-lg text-muted">{t.loading}</p>}
                </div>
              </Card>
            );
          })}
        </div>
      </section>
      <ButtonLink href="/history" variant="secondary" className="w-full sm:w-auto">
        <History aria-hidden className="size-6" />
        {t.nav_history}
      </ButtonLink>
    </div>
  );
}
