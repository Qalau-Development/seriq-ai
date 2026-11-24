"use client";

import { useEffect, useRef, useState } from "react";
import Link from "next/link";
import { AlertCircle, Info, Loader2, RotateCcw } from "lucide-react";
import type { AnalysisResult } from "@/types/analysis";
import { AnalysisError, analyzeVideo, checkVideoFile } from "@/lib/api";
import { textOr, useLang } from "@/lib/i18n";
import { Button, ButtonLink } from "@/components/ui/Button";
import { VideoUpload } from "@/components/video/VideoUpload";
import { VerdictCard } from "@/components/analysis/VerdictCard";

const INSTRUCTION_ERRORS = ["no_pose_detected", "video_too_short", "video_too_long", "recording_too_short"];

type State =
  | { kind: "idle" }
  | { kind: "analyzing" }
  | { kind: "result"; result: AnalysisResult }
  | { kind: "error"; code: string };

// SessionPage — занятие: загрузка видео, анализ и результат
export default function SessionPage() {
  const { t } = useLang();
  const [state, setState] = useState<State>({ kind: "idle" });
  const outcome = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (state.kind === "result" || state.kind === "error") {
      outcome.current?.focus();
      outcome.current?.scrollIntoView({ block: "start", behavior: "smooth" });
    }
  }, [state.kind]);

  // handleFile — проверяет файл и отправляет его на анализ
  async function handleFile(file: File) {
    const localError = checkVideoFile(file);
    if (localError) {
      setState({ kind: "error", code: localError });
      return;
    }
    setState({ kind: "analyzing" });
    const scenario = new URLSearchParams(window.location.search).get("mock_scenario") ?? undefined;
    try {
      const result = await analyzeVideo(file, scenario);
      setState({ kind: "result", result });
    } catch (e) {
      setState({ kind: "error", code: e instanceof AnalysisError ? e.code : "internal_error" });
    }
  }

  return (
    <div className="space-y-8">
      <section className="space-y-2">
        <h1 className="text-3xl font-bold">{t.session_title}</h1>
        {state.kind === "idle" && <p className="text-lg">{t.session_hint}</p>}
      </section>

      {state.kind === "idle" && (
        <div className="flex gap-3 rounded-2xl bg-neutral-soft p-5 text-lg text-neutral-ink">
          <Info aria-hidden className="mt-1 size-6 shrink-0" />
          <p>
            {t.session_reminder}{" "}
            <Link href="/exercise" className="font-semibold underline underline-offset-4">
              {t.watch_instruction}
            </Link>
          </p>
        </div>
      )}

      <div aria-live="polite" ref={outcome} tabIndex={-1} className="scroll-mt-6 space-y-6 outline-none">
        {state.kind === "analyzing" && (
          <div className="space-y-2 rounded-2xl bg-surface p-6">
            <p className="flex items-center gap-3 text-xl font-semibold">
              <Loader2 aria-hidden className="size-7 animate-spin text-accent" />
              {t.analyzing}
            </p>
            <p className="text-lg text-muted">{t.analyzing_hint}</p>
          </div>
        )}

        {state.kind === "result" && <VerdictCard result={state.result} t={t} />}

        {state.kind === "error" && (
          <div className="space-y-4">
            <div className="flex gap-3 rounded-2xl bg-error-soft p-5 text-lg text-error-ink">
              <AlertCircle aria-hidden className="mt-1 size-6 shrink-0" />
              <p>{textOr(t, `error_${state.code}`, "error_internal_error")}</p>
            </div>
            {INSTRUCTION_ERRORS.includes(state.code) && (
              <ButtonLink href="/exercise" variant="secondary" className="w-full sm:w-auto">
                {t.watch_instruction}
              </ButtonLink>
            )}
          </div>
        )}
      </div>

      {state.kind === "idle" && <VideoUpload onFile={handleFile} t={t} />}

      {(state.kind === "result" || state.kind === "error") && (
        <Button onClick={() => setState({ kind: "idle" })} className="w-full sm:w-auto">
          <RotateCcw aria-hidden className="size-6" />
          {state.kind === "result" ? t.another_attempt : t.try_again}
        </Button>
      )}
    </div>
  );
}
