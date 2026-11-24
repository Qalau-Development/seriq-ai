import { Camera } from "lucide-react";
import type { Dict, TextKey } from "@/lib/i18n";
import { Card } from "@/components/ui/Card";

// FilmingTips — советы, как снять упражнение
export function FilmingTips({ t, keys }: { t: Dict; keys: TextKey[] }) {
  return (
    <Card className="space-y-3">
      <h2 className="flex items-center gap-3 text-2xl font-bold">
        <Camera aria-hidden className="size-7 text-accent" />
        {t.tips_title}
      </h2>
      <ul className="list-disc space-y-2 pl-6 text-lg">
        {keys.map((key) => (
          <li key={key}>{t[key]}</li>
        ))}
      </ul>
    </Card>
  );
}
