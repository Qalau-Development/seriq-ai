import { Camera } from "lucide-react";
import type { Dict, TextKey } from "@/lib/i18n";
import { Card } from "@/components/ui/Card";

// FilmingTips — карточка «Как снимать»: иконка камеры, заголовок и список советов с оранжевыми точками
export function FilmingTips({ t, keys }: { t: Dict; keys: TextKey[] }) {
  return (
    <Card className="flex flex-col gap-5">
      <div className="flex items-center gap-3.5">
        <span aria-hidden className="flex size-12 shrink-0 items-center justify-center rounded-full bg-brand-soft text-brand">
          <Camera className="size-6" />
        </span>
        <h2 className="text-2xl leading-[30px] font-bold tracking-[-0.01em] text-balance lg:text-[28px] lg:leading-[34px]">{t.tips_title}</h2>
      </div>
      <ul className="flex flex-col gap-3.5">
        {keys.map((key) => (
          <li key={key} className="flex gap-3.5">
            <span aria-hidden className="mt-[9px] size-2.5 shrink-0 rounded-full bg-accent-strong" />
            <span className="text-lg leading-7 font-medium text-ink">{t[key]}</span>
          </li>
        ))}
      </ul>
    </Card>
  );
}
