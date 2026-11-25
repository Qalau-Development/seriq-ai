"use client";

import { useEffect, useState } from "react";
import { CheckCircle2, XCircle } from "lucide-react";
import type { Dict } from "@/lib/i18n";
import type { ExerciseId } from "@/types/analysis";
import { INSTRUCTION_CLIPS, clipPoster, clipSrc, nextIndex, type InstructionClip } from "@/lib/instructionClips";

// useReducedMotion — true, если в системе включено «уменьшить движение»: тогда видео не играют сами
function useReducedMotion(): boolean {
  const [reduced, setReduced] = useState(false);
  useEffect(() => {
    const query = window.matchMedia("(prefers-reduced-motion: reduce)");
    const update = () => setReduced(query.matches);
    update();
    query.addEventListener("change", update);
    return () => query.removeEventListener("change", update);
  }, []);
  return reduced;
}

// ClipPanel — одна колонка: метка, вертикальное видео и подпись; несколько роликов сменяются по окончании
function ClipPanel({ t, kind, clips, reduced }: { t: Dict; kind: "correct" | "wrong"; clips: InstructionClip[]; reduced: boolean }) {
  const [index, setIndex] = useState(0);
  const clip = clips[index] ?? clips[0];
  const many = clips.length > 1;
  const correct = kind === "correct";
  if (!clip) return null;
  return (
    <figure className="flex flex-col gap-3">
      <div className="overflow-hidden rounded-[20px] bg-[#0b1e33]">
        <p
          className={`flex items-center justify-center gap-1.5 px-2 py-2 text-base font-bold sm:text-lg ${
            correct ? "bg-brand text-white" : "bg-error-soft text-error-ink"
          }`}
        >
          {correct ? <CheckCircle2 aria-hidden className="size-5 shrink-0" /> : <XCircle aria-hidden className="size-5 shrink-0" />}
          {correct ? t.clips_correct : t.clips_wrong}
        </p>
        <video
          key={clip.name}
          src={clipSrc(clip)}
          poster={clipPoster(clip)}
          muted
          playsInline
          autoPlay={!reduced}
          controls={reduced}
          loop={!many}
          preload="metadata"
          onEnded={() => many && setIndex((i) => nextIndex(i, clips.length))}
          className="aspect-[9/16] w-full object-cover transition-opacity duration-500 starting:opacity-0"
        />
      </div>
      <figcaption aria-live={many ? "polite" : undefined} className="text-base leading-6 font-medium text-ink sm:text-lg sm:leading-7">
        {t[clip.captionKey]}
      </figcaption>
      {many && (
        <div className="-mt-1 flex flex-wrap gap-1">
          {clips.map((c, i) => (
            <button
              key={c.name}
              type="button"
              aria-label={t.clips_example.replace("{n}", String(i + 1)).replace("{total}", String(clips.length))}
              aria-current={i === index}
              onClick={() => setIndex(i)}
              className="flex size-11 items-center justify-center rounded-full hover:bg-neutral-soft"
            >
              <span aria-hidden className={`size-3 rounded-full ${i === index ? "bg-error-ink" : "bg-line-strong"}`} />
            </button>
          ))}
        </div>
      )}
    </figure>
  );
}

// InstructionVideo — два вертикальных видео рядом: слева правильная съёмка, справа по очереди неправильные примеры с подписью
export function InstructionVideo({ t, id }: { t: Dict; id: ExerciseId }) {
  const reduced = useReducedMotion();
  const clips = INSTRUCTION_CLIPS[id];
  return (
    <section aria-labelledby="clips-title" className="flex flex-col gap-4">
      <h2 id="clips-title" className="text-2xl leading-[30px] font-bold tracking-[-0.01em] text-balance">
        {t.clips_title}
      </h2>
      <div className="grid w-full max-w-[600px] grid-cols-2 items-start gap-3 sm:gap-5">
        <ClipPanel key={`${id}-correct`} t={t} kind="correct" clips={clips.correct} reduced={reduced} />
        <ClipPanel key={`${id}-wrong`} t={t} kind="wrong" clips={clips.wrong} reduced={reduced} />
      </div>
    </section>
  );
}
