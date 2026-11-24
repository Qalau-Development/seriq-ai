import { Info } from "lucide-react";
import { textOr, type Dict } from "@/lib/i18n";

// WarningList — нейтральные подсказки по съёмке из warnings
export function WarningList({ warnings, t }: { warnings: string[]; t: Dict }) {
  if (warnings.length === 0) return null;
  return (
    <div className="rounded-xl bg-neutral-soft p-4 text-neutral-ink">
      <p className="mb-2 font-semibold">{t.warnings_title}</p>
      <ul className="space-y-2">
        {warnings.map((code) => (
          <li key={code} className="flex gap-3">
            <Info aria-hidden className="mt-1 size-5 shrink-0" />
            <span>{textOr(t, `warning_${code}`, "warning_arm_not_visible")}</span>
          </li>
        ))}
      </ul>
    </div>
  );
}
