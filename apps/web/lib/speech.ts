import { useSyncExternalStore } from "react";
import type { Lang } from "@/lib/i18n";

const LOCALES: Record<Lang, string> = { ru: "ru-RU", kk: "kk-KZ", en: "en-US" };
const NATURAL_LANGS: Lang[] = ["ru", "kk"];

// hasVoice — есть ли в браузере голос для языка интерфейса
export function hasVoice(lang: Lang, voices: { lang: string }[]): boolean {
  return voices.some((v) => v.lang.toLowerCase().replace("_", "-").startsWith(lang));
}

// hasNaturalVoice — озвучивает ли язык свой голос: русский Silero, казахский ISSAI
export function hasNaturalVoice(lang: Lang): boolean {
  return NATURAL_LANGS.includes(lang);
}

// canSpeak — можно ли озвучить текст на этом языке прямо сейчас
export function canSpeak(lang: Lang): boolean {
  if (hasNaturalVoice(lang)) return true;
  return typeof speechSynthesis !== "undefined" && hasVoice(lang, speechSynthesis.getVoices());
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
    () => hasNaturalVoice(lang) || (typeof speechSynthesis !== "undefined" && hasVoice(lang, speechSynthesis.getVoices())),
    () => false,
  );
}

// cleanText — убирает двойные точки на стыках предложений
export function cleanText(text: string): string {
  return text.replace(/([.!?…])\s*\.+/g, "$1");
}

let player: HTMLAudioElement | null = null;

// playNatural — озвучивает текст своим голосом через сервер синтеза; без сервера — голосом браузера, если он есть
function playNatural(text: string, lang: Lang, onEnd: () => void) {
  const audio = new Audio(`/tts?lang=${lang}&text=${encodeURIComponent(cleanText(text))}`);
  player = audio;
  const end = () => {
    if (player === audio) player = null;
    onEnd();
  };
  const fallback = () => {
    if (player !== audio) return;
    player = null;
    if (typeof speechSynthesis !== "undefined" && hasVoice(lang, speechSynthesis.getVoices())) speak(text, lang, onEnd);
    else onEnd();
  };
  audio.onended = end;
  audio.onerror = fallback;
  audio.play().catch(fallback);
}

// speak — читает вслух голосом браузера только переданный текст; onEnd вызывается по окончании или остановке
export function speak(text: string, lang: Lang, onEnd: () => void) {
  speechSynthesis.cancel();
  const utterance = new SpeechSynthesisUtterance(cleanText(text));
  utterance.lang = LOCALES[lang];
  utterance.voice = speechSynthesis.getVoices().find((v) => v.lang.toLowerCase().replace("_", "-").startsWith(lang)) ?? null;
  utterance.onend = onEnd;
  utterance.onerror = onEnd;
  speechSynthesis.speak(utterance);
}

// speakNatural — читает текст с экрана: ru и kk своим голосом, остальные языки голосом браузера
export function speakNatural(text: string, lang: Lang, onEnd: () => void) {
  stopSpeaking();
  if (hasNaturalVoice(lang)) playNatural(text, lang, onEnd);
  else speak(text, lang, onEnd);
}

// stopSpeaking — останавливает озвучивание: и свой голос, и голос браузера
export function stopSpeaking() {
  if (player) {
    player.pause();
    player = null;
  }
  if (typeof speechSynthesis !== "undefined") speechSynthesis.cancel();
}
