import type { ExerciseId } from "@/types/analysis";
import type { TextKey } from "@/lib/i18n/ru";

export interface InstructionClip {
  name: string;
  captionKey: TextKey;
}

export interface InstructionClips {
  correct: InstructionClip[];
  wrong: InstructionClip[];
}

// INSTRUCTION_CLIPS — видео «правильно» и «неправильно» к каждому упражнению; файлы в public/media/instruction-<name>.mp4
export const INSTRUCTION_CLIPS: Record<ExerciseId, InstructionClips> = {
  E01: {
    correct: [{ name: "e01-correct", captionKey: "clip_e01_correct" }],
    wrong: [
      { name: "e01-wrong-out-of-frame", captionKey: "clip_e01_out_of_frame" },
      { name: "e01-wrong-top", captionKey: "clip_e01_top" },
      { name: "e01-wrong-not-returned", captionKey: "clip_e01_not_returned" },
    ],
  },
  E02: {
    correct: [{ name: "e02-correct", captionKey: "clip_e02_correct" }],
    wrong: [
      { name: "e02-wrong-fist-hidden", captionKey: "clip_e02_fist_hidden" },
      { name: "e02-wrong-top", captionKey: "clip_e02_top" },
    ],
  },
  E03: {
    correct: [{ name: "e03-correct", captionKey: "clip_e03_correct" }],
    wrong: [
      { name: "e03-wrong-dropped", captionKey: "clip_e03_dropped" },
      { name: "e03-wrong-far", captionKey: "clip_e03_far" },
      { name: "e03-wrong-top", captionKey: "clip_e03_top" },
    ],
  },
  E04: {
    correct: [{ name: "e04-correct", captionKey: "clip_e04_correct" }],
    wrong: [
      { name: "e04-wrong-out-of-frame", captionKey: "clip_e04_out_of_frame" },
      { name: "e04-wrong-not-open", captionKey: "clip_e04_not_open" },
    ],
  },
};

// clipSrc — адрес видео ролика инструкции
export function clipSrc(clip: InstructionClip): string {
  return `/media/instruction-${clip.name}.mp4`;
}

// clipPoster — адрес первого кадра ролика, пока видео грузится
export function clipPoster(clip: InstructionClip): string {
  return `/media/instruction-${clip.name}.jpg`;
}

// nextIndex — следующий ролик по кругу
export function nextIndex(current: number, total: number): number {
  return total > 0 ? (current + 1) % total : 0;
}
