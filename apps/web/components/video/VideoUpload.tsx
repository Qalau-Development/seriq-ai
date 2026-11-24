"use client";

import { useRef, useState } from "react";
import { Activity, Upload, Video } from "lucide-react";
import type { ExerciseId } from "@/types/analysis";
import type { Dict } from "@/lib/i18n";
import { Button } from "@/components/ui/Button";
import { CameraRecorder } from "@/components/video/CameraRecorder";
import { LiveCoachRecorder, type RepOutcome } from "@/components/video/LiveCoachRecorder";

const ACCEPT = "video/mp4,video/quicktime,video/webm,.mp4,.mov,.webm";

// VideoUpload — выбор видео: запись с веб-камеры на компьютере, системная камера на телефоне, файл, живой режим для E02
export function VideoUpload({
  onFile,
  onLiveRep,
  liveErrorText,
  disabled,
  exercise,
  t,
}: {
  onFile: (file: File) => void;
  onLiveRep?: (file: File) => Promise<RepOutcome>;
  liveErrorText?: (code: string) => string;
  disabled?: boolean;
  exercise?: ExerciseId;
  t: Dict;
}) {
  const fileInput = useRef<HTMLInputElement>(null);
  const cameraInput = useRef<HTMLInputElement>(null);
  const [recording, setRecording] = useState(false);
  const [live, setLive] = useState(false);

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
      {live && onLiveRep ? (
        <LiveCoachRecorder
          onRep={onLiveRep}
          errorText={liveErrorText ?? (() => t.error_internal_error)}
          onCancel={() => setLive(false)}
          onUploadInstead={() => {
            setLive(false);
            fileInput.current?.click();
          }}
          t={t}
        />
      ) : recording ? (
        <CameraRecorder
          onFile={onFile}
          onCancel={() => setRecording(false)}
          onUploadInstead={() => {
            setRecording(false);
            fileInput.current?.click();
          }}
          t={t}
        />
      ) : (
        <>
          <div className="flex flex-col gap-3 sm:flex-row">
            <div className="contents pointer-coarse:hidden">
              <Button onClick={() => setRecording(true)} disabled={disabled}>
                <Video aria-hidden className="size-6" />
                {t.record_camera}
              </Button>
            </div>
            <div className="hidden pointer-coarse:contents">
              <Button onClick={() => cameraInput.current?.click()} disabled={disabled}>
                <Video aria-hidden className="size-6" />
                {t.record_on_phone}
              </Button>
            </div>
            <Button variant="secondary" onClick={() => fileInput.current?.click()} disabled={disabled}>
              <Upload aria-hidden className="size-6" />
              {t.upload_video}
            </Button>
          </div>
          {exercise === "E02" && onLiveRep && (
            <Button variant="secondary" onClick={() => setLive(true)} disabled={disabled}>
              <Activity aria-hidden className="size-6" />
              {t.live_button}
            </Button>
          )}
          <p className="text-base text-muted">{t.upload_formats}</p>
        </>
      )}
    </div>
  );
}
