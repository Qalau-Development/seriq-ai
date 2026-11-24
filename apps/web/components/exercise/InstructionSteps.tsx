import type { Dict, TextKey } from "@/lib/i18n";

// InstructionSteps — нумерованные шаги выполнения упражнения: оранжевый кружок с тёмной цифрой и крупный текст
export function InstructionSteps({ t, keys }: { t: Dict; keys: TextKey[] }) {
  return (
    <ol className="flex flex-col gap-2.5 sm:gap-3">
      {keys.map((key, i) => (
        <li key={key} className="flex items-start gap-3.5 rounded-[22px] border border-line bg-surface px-[18px] py-4 shadow-card sm:gap-5 sm:rounded-3xl sm:px-6 sm:py-5">
          <span className="flex size-11 shrink-0 sm:size-12 items-center justify-center rounded-full bg-accent text-[22px] leading-none font-extrabold text-on-accent">
            {i + 1}
          </span>
          <span className="pt-2 text-lg leading-[27px] font-medium text-ink sm:pt-[9px] sm:text-xl sm:leading-[30px]">{t[key]}</span>
        </li>
      ))}
    </ol>
  );
}
