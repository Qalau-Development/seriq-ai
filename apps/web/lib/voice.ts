import { useEffect, useSyncExternalStore } from "react";
import type { Lang } from "@/lib/i18n";
import { hasVoice, speak as synthSpeak, stopSpeaking } from "@/lib/speech";

// Фрагмент озвучки: id клипа в манифесте и текст для запасного голоса браузера
export interface VoiceItem {
  id: string;
  text: string;
}

export interface Manifest {
  v: number;
  clips: Record<string, Partial<Record<Lang, string>>>;
}

// Минимум от аудиоэлемента, который нужен плееру; в тестах подменяется заглушкой
export interface AudioLike {
  onended: ((ev: Event) => unknown) | null;
  onerror: ((ev: Event | string) => unknown) | null;
  currentTime: number;
  play(): Promise<void> | void;
  pause(): void;
}

export interface VoiceEnv {
  fetchManifest(): Promise<Manifest | null>;
  createAudio(url: string): AudioLike;
  speak(text: string, lang: Lang, onEnd: () => void): void;
  stopSpeak(): void;
  later(fn: () => void, ms: number): () => void;
  now(): number;
}

export const VOICE_BASE = "/voice";
export const PAUSE_MS = 250;
export const CUE_REPEAT_MS = 4000;
const CUE_STALE_MS = 15000;
const POOL_LIMIT = 60;

// clamp — целое число, прижатое к краям диапазона
export function clampInt(n: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, Math.round(n)));
}

// parseManifest — проверяет форму манифеста; всё лишнее считается его отсутствием
export function parseManifest(data: unknown): Manifest | null {
  if (!data || typeof data !== "object") return null;
  const { v, clips } = data as { v?: unknown; clips?: unknown };
  if (v !== 1 || !clips || typeof clips !== "object") return null;
  return { v, clips: clips as Manifest["clips"] };
}

// clipAvailable — есть ли в манифесте хотя бы один клип из списка на языке
export function clipAvailable(manifest: Manifest | null | undefined, items: VoiceItem[], lang: Lang): boolean {
  return !!manifest && items.some((i) => !!manifest.clips[i.id]?.[lang]);
}

// createVoice — плеер заранее записанных клипов; для фрагмента без клипа или с ошибкой загрузки читает текст голосом браузера
export function createVoice(env: VoiceEnv) {
  let manifest: Manifest | null | undefined;
  let loading: Promise<Manifest | null> | null = null;
  const listeners = new Set<() => void>();
  const pool = new Map<string, AudioLike>();
  const lastCue = new Map<string, number>();
  let run = 0;
  let playing: number | null = null;
  let current: AudioLike | null = null;
  let cancelTimer: (() => void) | null = null;

  // load — загружает манифест один раз; при ошибке дальше работает только голос браузера
  function load(): Promise<Manifest | null> {
    loading ??= env
      .fetchManifest()
      .catch(() => null)
      .then((m) => {
        manifest = m;
        listeners.forEach((l) => l());
        return m;
      });
    return loading;
  }

  // subscribe — подписка на момент, когда манифест загрузился
  function subscribe(fn: () => void) {
    listeners.add(fn);
    return () => void listeners.delete(fn);
  }

  // urlFor — адрес клипа или null, если его нет в манифесте
  function urlFor(id: string, lang: Lang): string | null {
    const path = manifest?.clips[id]?.[lang];
    return path ? `${VOICE_BASE}/${path}` : null;
  }

  // audioFor — аудиоэлемент для адреса: предзагруженный или новый
  function audioFor(url: string): AudioLike {
    let audio = pool.get(url);
    if (!audio) {
      audio = env.createAudio(url);
      pool.set(url, audio);
      if (pool.size > POOL_LIMIT) pool.delete(pool.keys().next().value as string);
    }
    return audio;
  }

  // preload — предзагружает клипы, чтобы подсказки играли мгновенно
  function preload(ids: string[], lang: Lang) {
    void load().then(() => {
      for (const id of ids) {
        const url = urlFor(id, lang);
        if (url) audioFor(url);
      }
    });
  }

  // stop — останавливает клипы и запасной голос; onEnd прерванного вызова не вызывается
  function stop() {
    run++;
    playing = null;
    cancelTimer?.();
    cancelTimer = null;
    if (current) {
      current.onended = null;
      current.onerror = null;
      current.pause();
      current = null;
    }
    env.stopSpeak();
  }

  // playClips — играет фрагменты по очереди с паузой; новый вызов прерывает предыдущий
  function playClips(items: VoiceItem[], lang: Lang, onEnd: () => void = () => {}) {
    stop();
    const mine = run;
    playing = env.now();

    const finish = () => {
      if (run !== mine) return;
      playing = null;
      onEnd();
    };
    const next = (i: number) => {
      if (run !== mine) return;
      if (i + 1 >= items.length) return finish();
      cancelTimer = env.later(() => step(i + 1), PAUSE_MS);
    };
    const step = (i: number) => {
      if (run !== mine) return;
      const item = items[i];
      const url = urlFor(item.id, lang);
      const fallback = () => env.speak(item.text, lang, () => next(i));
      if (!url) return fallback();
      const audio = audioFor(url);
      const following = items[i + 1] && urlFor(items[i + 1].id, lang);
      if (following) audioFor(following);
      current = audio;
      let settled = false;
      const settle = (ok: boolean) => {
        if (settled || run !== mine) return;
        settled = true;
        current = null;
        if (ok) next(i);
        else fallback();
      };
      audio.onended = () => settle(true);
      audio.onerror = () => settle(false);
      try {
        audio.currentTime = 0;
        const started = audio.play();
        if (started) started.catch(() => settle(false));
      } catch {
        settle(false);
      }
    };

    if (items.length === 0) return finish();
    if (manifest !== undefined) step(0);
    else void load().then(() => run === mine && step(0));
  }

  // playCue — короткая подсказка живого режима: не чаще раза в 4 секунды одна и та же, на играющую не накладывается; force прерывает играющую
  function playCue(item: VoiceItem, lang: Lang, force = false): boolean {
    const now = env.now();
    if (!force) {
      const busy = playing !== null && now - playing < CUE_STALE_MS;
      const last = lastCue.get(item.id);
      if (busy || (last !== undefined && now - last < CUE_REPEAT_MS)) return false;
    }
    lastCue.set(item.id, now);
    playClips([item], lang);
    return true;
  }

  return { load, subscribe, preload, playClips, playCue, stop, getManifest: () => manifest, isPlaying: () => playing !== null };
}

// browserEnv — настоящее окружение: fetch, Audio, голос браузера, таймеры; только свой сайт
function browserEnv(): VoiceEnv {
  return {
    fetchManifest: async () => {
      const res = await fetch(`${VOICE_BASE}/manifest.json`);
      return res.ok ? parseManifest(await res.json()) : null;
    },
    createAudio: (url) => {
      const audio = new Audio();
      audio.preload = "auto";
      audio.src = url;
      return audio;
    },
    speak: (text, lang, onEnd) => {
      if (typeof speechSynthesis === "undefined" || !hasVoice(lang, speechSynthesis.getVoices())) return onEnd();
      synthSpeak(text, lang, onEnd);
    },
    stopSpeak: stopSpeaking,
    later: (fn, ms) => {
      const id = window.setTimeout(fn, ms);
      return () => window.clearTimeout(id);
    },
    now: () => Date.now(),
  };
}

export const voice = createVoice(browserEnv());

// useManifest — манифест клипов: undefined, пока не загружен, null, если его нет; загрузка один раз
export function useManifest(): Manifest | null | undefined {
  useEffect(() => {
    void voice.load();
  }, []);
  return useSyncExternalStore(voice.subscribe, voice.getManifest, () => undefined);
}
