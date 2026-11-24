import { EXERCISES } from "@/lib/exercises";
import type { Dict } from "@/lib/i18n";
import type { ExerciseId } from "@/types/analysis";
import { Chip } from "@/components/ui/Chip";

export type ExerciseFilterValue = ExerciseId | "all";

// ExerciseFilter — фильтр упражнения: подпись и кнопки-чипы «Все» и четыре упражнения
export function ExerciseFilter({ value, onChange, t }: { value: ExerciseFilterValue; onChange: (v: ExerciseFilterValue) => void; t: Dict }) {
  const options = [{ id: "all" as const, text: t.history_filter_all }, ...EXERCISES.map((e) => ({ id: e.id, text: t[e.titleKey] }))];
  return (
    <div role="group" aria-label={t.history_filter_label} className="flex flex-col gap-2.5 sm:flex-row sm:flex-wrap sm:items-center sm:gap-3">
      <span aria-hidden className="text-lg leading-[1.2] font-bold text-muted sm:mr-1">
        {t.history_filter_label}
      </span>
      <div className="flex flex-wrap gap-2.5 sm:gap-3">
        {options.map((o) => (
          <Chip key={o.id} selected={value === o.id} onClick={() => onChange(o.id)}>
            {o.text}
          </Chip>
        ))}
      </div>
    </div>
  );
}
