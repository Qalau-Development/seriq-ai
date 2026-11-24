import { ru, type Dict, type TextKey } from "@/lib/i18n/ru";

export type { Dict, TextKey };

// useLang — возвращает словарь текущего языка (казахский добавляется следующим шагом)
export function useLang() {
  return { lang: "ru" as const, locale: "ru-RU", t: ru as Dict };
}

// textOr — возвращает текст по ключу или запасной текст, если ключа нет
export function textOr(t: Dict, key: string, fallback: TextKey): string {
  return key in t ? t[key as TextKey] : t[fallback];
}
