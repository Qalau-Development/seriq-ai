import type { ExerciseId } from "@/types/analysis";
import { textForExercise, type Dict } from "@/lib/i18n";
import { Notice } from "@/components/ui/Notice";

// WarningList — нейтральные подсказки по съёмке из warnings
export function WarningList({ warnings, exercise, t }: { warnings: string[]; exercise: ExerciseId; t: Dict }) {
  if (warnings.length === 0) return null;
  return (
    <Notice kind="warn">
      <p className="mb-1 font-bold">{t.warnings_title}</p>
      <ul className="space-y-1">
        {warnings.map((code) => (
          <li key={code} className="font-semibold">
            {textForExercise(t, `warning_${code}`, exercise, "warning_arm_not_visible")}
          </li>
        ))}
      </ul>
    </Notice>
  );
}
