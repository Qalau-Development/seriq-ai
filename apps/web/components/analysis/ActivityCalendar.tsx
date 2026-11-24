import { fill, type Dict, type Lang } from "@/lib/i18n";
import { recentDays } from "@/lib/progress";

const DAYS = 28;
const KK_MONTHS = ["қаңтар", "ақпан", "наурыз", "сәуір", "мамыр", "маусым", "шілде", "тамыз", "қыркүйек", "қазан", "қараша", "желтоқсан"];
const EN_MONTHS = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
const RU_MONTHS = ["января", "февраля", "марта", "апреля", "мая", "июня", "июля", "августа", "сентября", "октября", "ноября", "декабря"];

// formatDay — «25 ноября» по дате YYYY-MM-DD
function formatDay(date: string, lang: Lang): string {
  const [, m, d] = date.split("-").map(Number);
  if (lang === "kk") return `${d} ${KK_MONTHS[m - 1]}`;
  return lang === "en" ? `${d} ${EN_MONTHS[m - 1]}` : `${d} ${RU_MONTHS[m - 1]}`;
}

// ActivityCalendar — последние 28 дней: закрашены дни, когда были повторения; под сеткой список таких дней
export function ActivityCalendar({
  activity,
  utcOffsetMinutes,
  lang,
  t,
}: {
  activity: { date: string; sessions: number; repetitions: number }[];
  utcOffsetMinutes: number;
  lang: Lang;
  t: Dict;
}) {
  const byDay = new Map(activity.map((a) => [a.date, a]));
  const days = recentDays(DAYS, utcOffsetMinutes);
  const active = days.filter((d) => byDay.has(d)).reverse();
  return (
    <figure className="space-y-3">
      <figcaption className="text-xl font-bold">{t.progress_days_title}</figcaption>
      <ol className="grid grid-cols-7 gap-2">
        {days.map((d) => {
          const a = byDay.get(d);
          const label = formatDay(d, lang);
          return (
            <li
              key={d}
              aria-label={a ? fill(t.progress_day_label, { date: label, n: a.repetitions }) : label}
              className={`flex aspect-square items-center justify-center rounded-lg text-lg font-semibold ${a ? "bg-brand text-white" : "border border-line bg-surface text-muted"}`}
            >
              {Number(d.slice(8))}
            </li>
          );
        })}
      </ol>
      <p className="text-base text-muted">{t.progress_days_hint}</p>
      {active.length > 0 && (
        <ul className="space-y-1 text-lg">
          {active.slice(0, 7).map((d) => (
            <li key={d}>{fill(t.progress_day_label, { date: formatDay(d, lang), n: byDay.get(d)?.repetitions ?? 0 })}</li>
          ))}
        </ul>
      )}
    </figure>
  );
}
