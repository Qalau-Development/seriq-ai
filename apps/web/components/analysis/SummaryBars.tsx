import type { ExerciseId } from "@/types/analysis";
import type { SessionSummary } from "@/lib/history";
import type { Dict } from "@/lib/i18n";

// SummaryBars — простая диаграмма: сколько повторений каждого исхода
export function SummaryBars({ summary, exercise, showShare, title, t }: { summary: SessionSummary; exercise: ExerciseId | null; showShare?: boolean; title?: string; t: Dict }) {
  const rows = [
    { key: "complete", text: t.label_complete, value: summary.complete, bar: "bg-accent" },
    { key: "incomplete", text: exercise === "E02" ? t.label_incomplete : exercise === null ? t.label_incomplete_generic : t.verdict_check_instructions, value: summary.incomplete, bar: "bg-neutral-ink" },
    { key: "uncertain", text: t.label_uncertain, value: summary.uncertain, bar: "bg-muted" },
  ];
  const max = Math.max(1, summary.total);
  return (
    <figure className="space-y-4">
      <figcaption className="text-xl font-bold">{title ?? t.summary_chart_title}</figcaption>
      <dl className="space-y-4">
        {rows.map((r) => (
          <div key={r.key} className="space-y-1">
            <div className="flex items-baseline justify-between gap-4 text-lg">
              <dt className="min-w-0">{r.text}</dt>
              <dd className="whitespace-nowrap text-2xl font-bold">
                {r.value}
                {showShare && summary.total > 0 && <span className="ml-2 text-lg font-semibold text-muted">· {Math.round((r.value / summary.total) * 100)}%</span>}
              </dd>
            </div>
            <div className="h-4 w-full rounded-full bg-surface" aria-hidden>
              <div
                className={`h-4 rounded-full ${r.bar}`}
                style={{ width: r.value === 0 ? 0 : `max(${(r.value / max) * 100}%, 1rem)` }}
              />
            </div>
          </div>
        ))}
      </dl>
    </figure>
  );
}
