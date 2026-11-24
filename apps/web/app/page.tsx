"use client";

import { Play } from "lucide-react";
import { useLang } from "@/lib/i18n";
import { Card } from "@/components/ui/Card";
import { ButtonLink } from "@/components/ui/Button";

// HomePage — главная: что такое SerIQ и вход в занятие
export default function HomePage() {
  const { t } = useLang();
  return (
    <div className="space-y-8">
      <section className="space-y-3">
        <h1 className="text-4xl font-bold">SerIQ</h1>
        <p className="text-xl">{t.app_tagline}</p>
      </section>
      <Card className="space-y-4">
        <h2 className="text-2xl font-bold">{t.exercise_e02_title}</h2>
        <p className="text-lg">{t.exercise_e02_desc}</p>
        <ButtonLink href="/exercise" className="w-full sm:w-auto">
          <Play aria-hidden className="size-6" />
          {t.start_session}
        </ButtonLink>
      </Card>
    </div>
  );
}
