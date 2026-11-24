import { useSyncExternalStore } from "react";
import type { Lang } from "@/lib/i18n";

const LOCALES: Record<Lang, string> = { ru: "ru-RU", kk: "kk-KZ" };

// hasVoice — есть ли в браузере голос для языка интерфейса
export function hasVoice(lang: Lang, voices: { lang: string }[]): boolean {
  return voices.some((v) => v.lang.toLowerCase().replace("_", "-").startsWith(lang));
}

// subscribe — голоса в браузере загружаются не сразу, поэтому слушаем voiceschanged
function subscribe(onChange: () => void) {
  if (typeof speechSynthesis === "undefined") return () => {};
  speechSynthesis.addEventListener("voiceschanged", onChange);
  return () => speechSynthesis.removeEventListener("voiceschanged", onChange);
}

// useVoiceAvailable — true, только если озвучивание поддерживается и есть голос для языка
export function useVoiceAvailable(lang: Lang): boolean {
  return useSyncExternalStore(
    subscribe,
    () => typeof speechSynthesis !== "undefined" && hasVoice(lang, speechSynthesis.getVoices()),
    () => false,
  );
}

// cleanText — убирает двойные точки на стыках предложений
export function cleanText(text: string): string {
  return text.replace(/([.!?…])\s*\.+/g, "$1");
}

// speak — читает вслух только переданный текст голосом нужного языка; onEnd вызывается по окончании или остановке
export function speak(text: string, lang: Lang, onEnd: () => void) {
  speechSynthesis.cancel();
  const utterance = new SpeechSynthesisUtterance(cleanText(text));
  utterance.lang = LOCALES[lang];
  utterance.voice = speechSynthesis.getVoices().find((v) => v.lang.toLowerCase().replace("_", "-").startsWith(lang)) ?? null;
  utterance.onend = onEnd;
  utterance.onerror = onEnd;
  speechSynthesis.speak(utterance);
}

// stopSpeaking — останавливает озвучивание
export function stopSpeaking() {
  if (typeof speechSynthesis !== "undefined") speechSynthesis.cancel();
}
