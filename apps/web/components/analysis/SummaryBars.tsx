import type { ExerciseId } from "@/types/analysis";
import type { SessionSummary } from "@/lib/history";
import type { Dict } from "@/lib/i18n";
import { panelClass } from "@/components/ui/Card";

// SummaryBars — карточка «Результаты повторений»: сколько повторений каждого исхода, полоска и доля (если нужна)
export function SummaryBars({ summary, exercise, showShare, title, t }: { summary: SessionSummary; exercise: ExerciseId | null; showShare?: boolean; title?: string; t: Dict }) {
  const rows = [
    { key: "complete", text: t.label_complete, value: summary.complete, bar: "bg-accent-strong" },
    { key: "incomplete", text: exercise === "E02" ? t.label_incomplete : exercise === null ? t.label_incomplete_generic : t.verdict_check_instructions, value: summary.incomplete, bar: "bg-brand" },
    { key: "uncertain", text: t.label_uncertain, value: summary.uncertain, bar: "bg-line-strong" },
  ];
  return (
    <figure className={`${panelClass} flex flex-col gap-6`}>
      <figcaption className="text-[22px] leading-[26px] font-bold tracking-[-0.01em] text-balance sm:text-2xl sm:leading-[29px]">{title ?? t.summary_chart_title}</figcaption>
      <dl className="flex flex-col gap-[22px]">
        {rows.map((r) => (
          <div key={r.key} className="flex flex-col gap-2.5">
            <div className="flex items-baseline justify-between gap-4">
              <dt className="min-w-0 text-lg leading-[1.3] font-semibold text-ink">{r.text}</dt>
              <dd className="whitespace-nowrap">
                <span className="text-[26px] leading-none font-extrabold text-ink">{r.value}</span>
                {showShare && summary.total > 0 && <span className="ml-2 text-base leading-none font-medium text-muted">· {Math.round((r.value / summary.total) * 100)}%</span>}
              </dd>
            </div>
            <div className="h-[18px] w-full overflow-hidden rounded-[9px] bg-track" aria-hidden>
              <div className={`h-full rounded-[9px] ${r.bar}`} style={{ width: summary.total === 0 ? 0 : `${(r.value / summary.total) * 100}%` }} />
            </div>
          </div>
        ))}
      </dl>
    </figure>
  );
}
