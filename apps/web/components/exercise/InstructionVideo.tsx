"use client";

import { useState } from "react";
import type { Dict } from "@/lib/i18n";
import { Notice } from "@/components/ui/Notice";

// InstructionVideo — видеоинструкция к E02; если файла ещё нет, показывает пояснение
export function InstructionVideo({ t }: { t: Dict }) {
  const [missing, setMissing] = useState(false);
  if (missing) {
    return <Notice kind="info">{t.instruction_video_missing}</Notice>;
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
      className="aspect-video w-full rounded-[20px] bg-[#0b1e33]"
    />
  );
}
