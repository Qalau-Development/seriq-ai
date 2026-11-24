"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { AlertCircle, Circle, Loader2, Square, Upload, Video, X } from "lucide-react";
import type { Dict } from "@/lib/i18n";
import { Button } from "@/components/ui/Button";

const MAX_SECONDS = 30;
const MIN_SECONDS = 2;
const BITRATE = 2_500_000;

type Phase =
  | { kind: "starting" }
  | { kind: "preview" }
  | { kind: "countdown"; n: number }
  | { kind: "recording" }
  | { kind: "error"; code: "camera_denied" | "recording_too_short" };

// requestCamera — запрашивает камеру 1280×720 без звука
function requestCamera() {
  return navigator.mediaDevices.getUserMedia({
    video: { facingMode: "environment", width: { ideal: 1280 }, height: { ideal: 720 } },
    audio: false,
  });
}

// pickMimeType — выбирает формат записи, который поддерживает браузер
function pickMimeType(): string {
  const types = ["video/mp4", "video/webm;codecs=vp9", "video/webm"];
  return types.find((t) => MediaRecorder.isTypeSupported(t)) ?? "";
}

// formatClock — секунды в виде 0:07
function formatClock(seconds: number) {
  const s = Math.floor(seconds);
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
}

// CameraRecorder — запись одного повторения с камеры: превью, отсчёт, запись, автостоп
export function CameraRecorder({
  onFile,
  onCancel,
  onUploadInstead,
  t,
}: {
  onFile: (file: File) => void;
  onCancel: () => void;
  onUploadInstead: () => void;
  t: Dict;
}) {
  const [phase, setPhase] = useState<Phase>({ kind: "starting" });
  const [elapsed, setElapsed] = useState(0);
  const stream = useRef<MediaStream | null>(null);
  const recorder = useRef<MediaRecorder | null>(null);
  const timers = useRef<number[]>([]);

  // clearTimers — останавливает отсчёт, таймер записи и автостоп
  const clearTimers = useCallback(() => {
    timers.current.forEach((id) => window.clearTimeout(id));
    timers.current = [];
  }, []);

  // stopCamera — выключает камеру, чтобы индикатор погас
  const stopCamera = useCallback(() => {
    stream.current?.getTracks().forEach((track) => track.stop());
    stream.current = null;
  }, []);

  // showStream — запоминает поток камеры и показывает превью
  const showStream = useCallback((media: MediaStream) => {
    stream.current = media;
    setPhase({ kind: "preview" });
  }, []);

  useEffect(() => {
    let cancelled = false;
    requestCamera()
      .then((media) => {
        if (cancelled) media.getTracks().forEach((track) => track.stop());
        else showStream(media);
      })
      .catch(() => !cancelled && setPhase({ kind: "error", code: "camera_denied" }));
    return () => {
      cancelled = true;
      clearTimers();
      if (recorder.current?.state === "recording") {
        recorder.current.onstop = null;
        recorder.current.stop();
      }
      stopCamera();
    };
  }, [showStream, clearTimers, stopCamera]);

  // beginRecording — запускает MediaRecorder и автостоп через 30 секунд
  function beginRecording() {
    const media = stream.current;
    if (!media) return;
    const mimeType = pickMimeType();
    const rec = new MediaRecorder(media, { ...(mimeType && { mimeType }), videoBitsPerSecond: BITRATE });
    const chunks: Blob[] = [];
    const startedAt = Date.now();
    rec.ondataavailable = (e) => e.data.size > 0 && chunks.push(e.data);
    rec.onstop = () => {
      clearTimers();
      stopCamera();
      const seconds = (Date.now() - startedAt) / 1000;
      if (seconds < MIN_SECONDS) {
        setPhase({ kind: "error", code: "recording_too_short" });
        return;
      }
      const type = rec.mimeType || mimeType || "video/webm";
      const ext = type.startsWith("video/mp4") ? ".mp4" : ".webm";
      onFile(new File(chunks, `recording${ext}`, { type }));
    };
    recorder.current = rec;
    rec.start(250);
    setElapsed(0);
    setPhase({ kind: "recording" });
    const tick = () => {
      setElapsed((Date.now() - startedAt) / 1000);
      timers.current.push(window.setTimeout(tick, 250));
    };
    timers.current.push(window.setTimeout(tick, 250));
    timers.current.push(window.setTimeout(() => stop(), MAX_SECONDS * 1000));
  }

  // startCountdown — отсчёт 3-2-1 перед записью
  function startCountdown() {
    setPhase({ kind: "countdown", n: 3 });
    timers.current.push(window.setTimeout(() => setPhase({ kind: "countdown", n: 2 }), 1000));
    timers.current.push(window.setTimeout(() => setPhase({ kind: "countdown", n: 1 }), 2000));
    timers.current.push(window.setTimeout(beginRecording, 3000));
  }

  // stop — останавливает запись; файл передаётся в onstop
  function stop() {
    if (recorder.current?.state === "recording") recorder.current.stop();
  }

  // retry — снова включает камеру после ошибки
  function retry() {
    setPhase({ kind: "starting" });
    requestCamera()
      .then(showStream)
      .catch(() => setPhase({ kind: "error", code: "camera_denied" }));
  }

  // cancel — закрывает запись без отправки
  function cancel() {
    clearTimers();
    if (recorder.current?.state === "recording") {
      recorder.current.onstop = null;
      recorder.current.stop();
    }
    stopCamera();
    onCancel();
  }

  if (phase.kind === "error") {
    return (
      <div className="space-y-4">
        <div className="flex gap-3 rounded-2xl bg-error-soft p-5 text-lg text-error-ink" role="alert">
          <AlertCircle aria-hidden className="mt-1 size-6 shrink-0" />
          <p>{t[`error_${phase.code}`]}</p>
        </div>
        <div className="flex flex-col gap-3 sm:flex-row">
          {phase.code === "recording_too_short" ? (
            <Button onClick={retry}>
              <Video aria-hidden className="size-6" />
              {t.camera_retry}
            </Button>
          ) : (
            <Button onClick={onUploadInstead}>
              <Upload aria-hidden className="size-6" />
              {t.camera_upload_instead}
            </Button>
          )}
          <Button variant="secondary" onClick={cancel}>
            <X aria-hidden className="size-6" />
            {t.camera_cancel}
          </Button>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      <div className="relative overflow-hidden rounded-2xl bg-ink">
        <video
          ref={(video) => {
            if (video && stream.current && video.srcObject !== stream.current) video.srcObject = stream.current;
          }}
          autoPlay
          muted
          playsInline
          className="aspect-video w-full object-contain"
        />
        {phase.kind === "starting" && (
          <p className="absolute inset-0 flex items-center justify-center gap-3 text-xl font-semibold text-white">
            <Loader2 aria-hidden className="size-7 animate-spin" />
            {t.camera_starting}
          </p>
        )}
        {phase.kind === "countdown" && (
          <div className="absolute inset-0 flex flex-col items-center justify-center bg-ink/50 text-white">
            <p className="text-xl font-semibold">{t.camera_get_ready}</p>
            <p className="text-8xl font-bold" aria-live="assertive">
              {phase.n}
            </p>
          </div>
        )}
        {phase.kind === "recording" && (
          <p className="absolute top-3 left-3 flex items-center gap-2 rounded-xl bg-ink/70 px-3 py-2 text-lg font-semibold text-white">
            <Circle aria-hidden className="size-4 animate-pulse fill-red-500 text-red-500" />
            {t.camera_recording} {formatClock(elapsed)} / {formatClock(MAX_SECONDS)}
          </p>
        )}
      </div>

      {phase.kind === "preview" && <p className="text-lg">{t.camera_preview_hint}</p>}
      <p className="text-base text-muted">{t.camera_limit}</p>

      <div className="flex flex-col gap-3 sm:flex-row">
        {phase.kind === "recording" ? (
          <Button onClick={stop}>
            <Square aria-hidden className="size-6 fill-current" />
            {t.camera_stop}
          </Button>
        ) : (
          <Button onClick={startCountdown} disabled={phase.kind !== "preview"}>
            <Circle aria-hidden className="size-6 fill-current" />
            {t.camera_start}
          </Button>
        )}
        <Button variant="secondary" onClick={cancel}>
          <X aria-hidden className="size-6" />
          {t.camera_cancel}
        </Button>
      </div>
    </div>
  );
}
