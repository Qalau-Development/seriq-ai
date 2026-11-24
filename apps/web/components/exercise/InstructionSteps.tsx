import type { Dict, TextKey } from "@/lib/i18n";

// InstructionSteps — нумерованные шаги выполнения упражнения
export function InstructionSteps({ t, keys }: { t: Dict; keys: TextKey[] }) {
  return (
    <ol className="space-y-4">
      {keys.map((key, i) => (
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
