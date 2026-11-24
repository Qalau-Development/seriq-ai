import { confidenceLevel } from "@/lib/confidence";
import type { Dict } from "@/lib/i18n";

// ConfidenceMeter — мелкая строка «Уверенность оценки: высокая», без процентов
export function ConfidenceMeter({ confidence, t }: { confidence: number; t: Dict }) {
  return (
    <p className="text-base text-muted">
      {t.confidence_title}: {t[`confidence_${confidenceLevel(confidence)}`]}
    </p>
  );
}
