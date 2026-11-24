import { confidenceLevel } from "@/lib/confidence";
import type { Dict } from "@/lib/i18n";

// ConfidenceMeter — уверенность модели словами и мелко в процентах
export function ConfidenceMeter({ confidence, t }: { confidence: number; t: Dict }) {
  const level = confidenceLevel(confidence);
  return (
    <p className="text-lg">
      {t.confidence_title}: <strong>{t[`confidence_${level}`]}</strong>{" "}
      <span className="text-base text-muted">({Math.round(confidence * 100)}%)</span>
    </p>
  );
}
