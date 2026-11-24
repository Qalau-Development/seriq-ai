import { Camera } from "lucide-react";
import type { Dict } from "@/lib/i18n";
import { Card } from "@/components/ui/Card";

const tips = ["tip_1", "tip_2", "tip_3", "tip_4"] as const;

// FilmingTips — советы, как снять упражнение
export function FilmingTips({ t }: { t: Dict }) {
  return (
    <Card className="space-y-3">
      <h2 className="flex items-center gap-3 text-2xl font-bold">
        <Camera aria-hidden className="size-7 text-accent" />
        {t.tips_title}
      </h2>
      <ul className="list-disc space-y-2 pl-6 text-lg">
        {tips.map((key) => (
          <li key={key}>{t[key]}</li>
        ))}
      </ul>
    </Card>
  );
}
