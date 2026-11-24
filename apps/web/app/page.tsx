"use client";

import { ChartColumn, History, Play } from "lucide-react";
import { useLang } from "@/lib/i18n";
import { useCatalog } from "@/lib/catalog";
import { EXERCISES, exerciseAvailability } from "@/lib/exercises";
import { Card } from "@/components/ui/Card";
import { ButtonLink } from "@/components/ui/Button";
import { RecentSessions } from "@/components/analysis/RecentSessions";

// HomePage — главная: hero с названием, последние занятия и карточки четырёх упражнений
export default function HomePage() {
  const { t } = useLang();
  const catalog = useCatalog();
  return (
    <div className="flex flex-col gap-8 lg:gap-12">
      <div className="grid gap-6 lg:grid-cols-[7fr_5fr] lg:items-stretch [&>:only-child]:col-span-full">
        <section className="relative min-h-64 overflow-hidden rounded-[32px] bg-brand px-6 py-8 sm:px-10 sm:py-12 lg:min-h-[524px] lg:rounded-[36px] lg:px-16 lg:py-14 lg:[:only-child]:min-h-[340px]">
          <div aria-hidden className="absolute -top-[50px] -right-10 size-[150px] rounded-full bg-secondary lg:-top-[70px] lg:-right-[60px] lg:size-[220px]" />
          <div aria-hidden className="absolute -right-[70px] -bottom-[120px] size-[220px] rounded-full bg-link lg:right-[30px] lg:-bottom-[130px] lg:size-[270px]" />
          <div aria-hidden className="absolute top-[34px] right-[66px] size-14 rounded-full border-[12px] border-brand-soft-2 lg:top-auto lg:right-14 lg:bottom-[46px] lg:size-24" />
          <div className="relative max-w-[440px]">
            <h1 className="mb-3 text-[56px] leading-[60px] font-extrabold tracking-[-0.02em] text-white lg:mb-4 lg:text-[72px] lg:leading-[76px]">SerIQ</h1>
            <p className="text-xl leading-[30px] font-medium text-pretty text-white lg:text-2xl lg:leading-9">{t.app_tagline}</p>
          </div>
        </section>
        <RecentSessions catalog={catalog} />
      </div>

      <section id="exercises" className="flex scroll-mt-6 flex-col gap-6 lg:gap-7">
        <div className="flex flex-col gap-2">
          <h2 className="text-[30px] leading-9 font-extrabold tracking-[-0.01em] text-balance lg:text-4xl lg:leading-[43px]">{t.exercises_title}</h2>
          <p className="text-lg leading-[27px] text-pretty text-muted">{t.exercises_hint}</p>
        </div>
        <div className="grid gap-5 sm:grid-cols-2 lg:grid-cols-4">
          {EXERCISES.map((e) => {
            const state = exerciseAvailability(catalog, e.id);
            return (
              <Card key={e.id} className="flex flex-col gap-3 lg:p-7!">
                <h3 className="text-2xl leading-[29px] font-bold tracking-[-0.01em] text-balance">{t[e.titleKey]}</h3>
                <p className="text-lg leading-[27px] font-medium text-pretty text-ink">{t[e.descKey]}</p>
                <p className="rounded-2xl bg-tile px-4 py-3 text-base leading-6 font-medium text-muted">{t[e.measuresKey]}</p>
                <div className="mt-auto pt-2">
                  {state === "ready" && (
                    <ButtonLink href={`/exercise?e=${e.id}`} className="w-full">
                      <Play aria-hidden className="size-6" />
                      {t.start_session}
                      <span className="sr-only">: {t[e.titleKey]}</span>
                    </ButtonLink>
                  )}
                  {state === "soon" && (
                    <span className="flex min-h-14 items-center justify-center rounded-full bg-neutral-soft text-lg leading-none font-bold text-neutral-ink">{t.exercise_soon}</span>
                  )}
                  {state === "loading" && <p className="flex min-h-14 items-center justify-center text-lg leading-none font-semibold text-muted">{t.loading}</p>}
                </div>
              </Card>
            );
          })}
        </div>
      </section>

      <div className="flex flex-col gap-3 sm:flex-row sm:flex-wrap sm:gap-4">
        <ButtonLink href="/history" variant="secondary">
          <History aria-hidden className="size-6" />
          {t.nav_history}
        </ButtonLink>
        <ButtonLink href="/progress" variant="secondary">
          <ChartColumn aria-hidden className="size-6" />
          {t.nav_progress}
        </ButtonLink>
      </div>
    </div>
  );
}
