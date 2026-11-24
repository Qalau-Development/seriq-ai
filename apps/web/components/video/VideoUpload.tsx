"use client";

import { useRef } from "react";
import { Upload, Video } from "lucide-react";
import type { Dict } from "@/lib/i18n";
import { Button } from "@/components/ui/Button";

const ACCEPT = "video/mp4,video/quicktime,video/webm,.mp4,.mov,.webm";

// VideoUpload — выбор видео: на телефоне ещё и съёмка системной камерой
export function VideoUpload({
  onFile,
  disabled,
  t,
}: {
  onFile: (file: File) => void;
  disabled?: boolean;
  t: Dict;
}) {
  const fileInput = useRef<HTMLInputElement>(null);
  const cameraInput = useRef<HTMLInputElement>(null);

  // pick — передаёт выбранный файл и сбрасывает поле, чтобы можно было выбрать тот же файл снова
  function pick(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    e.target.value = "";
    if (file) onFile(file);
  }

  return (
    <div className="space-y-3">
      <input ref={fileInput} type="file" accept={ACCEPT} className="hidden" onChange={pick} />
      <input ref={cameraInput} type="file" accept="video/*" capture="environment" className="hidden" onChange={pick} />
      <div className="flex flex-col gap-3 sm:flex-row">
        <div className="hidden pointer-coarse:contents">
          <Button onClick={() => cameraInput.current?.click()} disabled={disabled}>
            <Video aria-hidden className="size-6" />
            {t.record_on_phone}
          </Button>
        </div>
        <Button
          onClick={() => fileInput.current?.click()}
          disabled={disabled}
          className="pointer-coarse:border-2 pointer-coarse:border-accent pointer-coarse:bg-page pointer-coarse:text-accent pointer-coarse:hover:bg-accent-soft"
        >
          <Upload aria-hidden className="size-6" />
          {t.upload_video}
        </Button>
      </div>
      <p className="text-base text-muted">{t.upload_formats}</p>
    </div>
  );
}
