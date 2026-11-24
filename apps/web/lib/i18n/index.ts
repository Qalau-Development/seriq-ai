import { useSyncExternalStore } from "react";
import { ru, type Dict, type TextKey } from "@/lib/i18n/ru";
import { kk } from "@/lib/i18n/kk";
import { en } from "@/lib/i18n/en";

export type { Dict, TextKey };
export type Lang = "ru" | "kk" | "en";

export const LANGS: Lang[] = ["ru", "kk", "en"];

const STORAGE_KEY = "seriq.lang";
const CHANGE_EVENT = "seriq-lang-change";
const DICTS: Record<Lang, Dict> = { ru, kk, en };

// parseLang — язык из сохранённого значения; всё неизвестное — ru
export function parseLang(value: string | null | undefined): Lang {
  return LANGS.find((l) => l === value) ?? "ru";
}

// readLang — читает язык из localStorage, по умолчанию ru
function readLang(): Lang {
  try {
    return parseLang(localStorage.getItem(STORAGE_KEY));
  } catch {
    return "ru";
  }
}

// subscribe — следит за сменой языка в этой и других вкладках
function subscribe(onChange: () => void) {
  window.addEventListener("storage", onChange);
  window.addEventListener(CHANGE_EVENT, onChange);
  return () => {
    window.removeEventListener("storage", onChange);
    window.removeEventListener(CHANGE_EVENT, onChange);
  };
}

// setLang — сохраняет выбранный язык и сообщает об изменении
export function setLang(lang: Lang) {
  localStorage.setItem(STORAGE_KEY, lang);
  window.dispatchEvent(new Event(CHANGE_EVENT));
}

// useLang — текущий язык и его словарь
export function useLang() {
  const lang = useSyncExternalStore(subscribe, readLang, () => "ru" as Lang);
  return { lang, t: DICTS[lang] };
}

// textOr — возвращает текст по ключу или запасной текст, если ключа нет
export function textOr(t: Dict, key: string, fallback: TextKey): string {
  return key in t ? t[key as TextKey] : t[fallback];
}

// textForExercise — текст по ключу; для упражнений кроме E02 берётся вариант с суффиксом _other, если он есть
export function textForExercise(t: Dict, key: string, exercise: string, fallback: TextKey): string {
  const other = `${key}_other`;
  if (exercise !== "E02" && other in t) return t[other as TextKey];
  return textOr(t, key, fallback);
}

// num — число с десятичным разделителем языка: запятая в русском и казахском, точка в английском
export function num(t: Dict, text: string): string {
  return text.replace(".", t.decimal_sep);
}

// fill — подставляет значения в текст вида «Выполнено {done} из {total}»
export function fill(text: string, values: Record<string, string | number>): string {
  return text.replace(/\{(\w+)\}/g, (_, name) => String(values[name] ?? ""));
}

const KK_MONTHS = ["қаңтар", "ақпан", "наурыз", "сәуір", "мамыр", "маусым", "шілде", "тамыз", "қыркүйек", "қазан", "қараша", "желтоқсан"];

// formatDateTime — дата и время занятия; казахские месяцы свои, потому что не во всех браузерах они есть
export function formatDateTime(iso: string, lang: Lang): string {
  const d = new Date(iso);
  if (lang === "kk") return `${d.getFullYear()} ж. ${d.getDate()} ${KK_MONTHS[d.getMonth()]}, ${formatTime(iso)}`;
  return new Intl.DateTimeFormat(lang === "en" ? "en-GB" : "ru-RU", { dateStyle: "long", timeStyle: "short" }).format(d);
}

// formatTime — время попытки в виде 14:03
export function formatTime(iso: string): string {
  const d = new Date(iso);
  return `${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`;
}
