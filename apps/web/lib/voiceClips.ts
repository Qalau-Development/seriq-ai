import type { ExerciseDef } from "@/lib/exercises";
import type { CueKey } from "@/lib/liveCoach";
import type { Dict } from "@/lib/i18n";
import type { VoiceItem } from "@/lib/voice";

// instructionItems — инструкция по порядку: название упражнения, шаги, «Как снимать», советы; id клипа = ключ словаря
export function instructionItems(t: Dict, def: ExerciseDef): VoiceItem[] {
  return [def.titleKey, ...def.stepKeys, "tips_title" as const, ...def.tipKeys].map((key) => ({ id: key, text: t[key] }));
}

// Подсказки живого режима, у которых есть записанные клипы; остальные пока не озвучиваются
const CUE_IDS: Partial<Record<CueKey, "live_show_hand" | "live_lost">> = { show_hand: "live_show_hand", lost: "live_lost" };

// cueItem — фрагмент озвучки для подсказки живого режима; null, если клипа нет и озвучивать не нужно
export function cueItem(t: Dict, key: CueKey, pose: boolean): VoiceItem | null {
  if (key === "show_hand" && pose) return { id: "live_show_arm", text: t.live_show_arm };
  const id = CUE_IDS[key];
  return id ? { id, text: t[id] } : null;
}

// LIVE_CLIP_IDS — клипы, которые предзагружаются при входе в живой режим
export const LIVE_CLIP_IDS = ["live_show_hand", "live_show_arm", "live_lost", "live_unstable", "verdict_completed", "verdict_check_instructions"];
