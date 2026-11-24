import { confidenceLevel } from "@/lib/confidence";
import type { Dict } from "@/lib/i18n";

// ConfidenceMeter — плашка «Уверенность оценки: высокая», без процентов
export function ConfidenceMeter({ confidence, t }: { confidence: number; t: Dict }) {
  return (
    <div className="flex">
      <p className="flex min-h-16 w-full items-center justify-between gap-3 rounded-[22px] border border-line bg-surface px-5 shadow-card sm:inline-flex sm:min-h-[72px] sm:w-auto sm:justify-start sm:rounded-3xl sm:px-7">
        <span className="text-base leading-[22px] font-semibold text-muted sm:text-lg sm:leading-[1.3]">{t.confidence_title}:</span>
        <span className="text-xl leading-[1.3] font-extrabold text-ink">{t[`confidence_${confidenceLevel(confidence)}`]}</span>
      </p>
    </div>
  );
}
