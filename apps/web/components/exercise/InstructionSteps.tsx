import type { Dict } from "@/lib/i18n";

const steps = ["instruction_step_1", "instruction_step_2", "instruction_step_3", "instruction_step_4"] as const;

// InstructionSteps — нумерованные шаги выполнения упражнения
export function InstructionSteps({ t }: { t: Dict }) {
  return (
    <ol className="space-y-4">
      {steps.map((key, i) => (
        <li key={key} className="flex gap-4">
          <span className="flex size-10 shrink-0 items-center justify-center rounded-full bg-accent text-lg font-bold text-white">
            {i + 1}
          </span>
          <span className="pt-1 text-lg">{t[key]}</span>
        </li>
      ))}
    </ol>
  );
}
