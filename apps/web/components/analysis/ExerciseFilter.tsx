import { EXERCISES } from "@/lib/exercises";
import type { Dict } from "@/lib/i18n";
import type { ExerciseId } from "@/types/analysis";

export type ExerciseFilterValue = ExerciseId | "all";

// ExerciseFilter — кнопки выбора упражнения: все или одно из четырёх
export function ExerciseFilter({ value, onChange, t }: { value: ExerciseFilterValue; onChange: (v: ExerciseFilterValue) => void; t: Dict }) {
  const options = [{ id: "all" as const, text: t.history_filter_all }, ...EXERCISES.map((e) => ({ id: e.id, text: t[e.titleKey] }))];
  return (
    <div role="group" aria-label={t.history_filter_label} className="flex flex-wrap gap-2">
      {options.map((o) => (
        <button
          key={o.id}
          type="button"
          aria-pressed={value === o.id}
          onClick={() => onChange(o.id)}
          className={`min-h-12 rounded-xl border-2 border-accent px-4 text-lg font-semibold ${value === o.id ? "bg-accent text-white" : "bg-page text-accent hover:bg-accent-soft"}`}
        >
          {o.text}
        </button>
      ))}
    </div>
  );
}
