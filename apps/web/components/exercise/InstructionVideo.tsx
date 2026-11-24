"use client";

import { useState } from "react";
import type { Dict } from "@/lib/i18n";

// InstructionVideo — видеоинструкция к E02; если файла ещё нет, показывает пояснение
export function InstructionVideo({ t }: { t: Dict }) {
  const [missing, setMissing] = useState(false);
  if (missing) {
    return <p className="rounded-2xl bg-surface p-6 text-lg text-muted">{t.instruction_video_missing}</p>;
  }
  return (
    <video
      src="/media/instruction-e02.mp4"
      controls
      playsInline
      preload="metadata"
      ref={(video) => {
        if (video && (video.error || video.networkState === HTMLMediaElement.NETWORK_NO_SOURCE)) setMissing(true);
      }}
      onError={() => setMissing(true)}
      className="aspect-video w-full rounded-2xl bg-surface"
    />
  );
}
