"use client";

import { Suspense, useEffect, useRef, useState } from "react";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { AlertCircle, Flag, Info, RotateCcw } from "lucide-react";
import type { AnalysisResult, ExerciseId } from "@/types/analysis";
import { AnalysisError, analyzeVideo, checkVideoFile } from "@/lib/api";
import { exerciseAvailability, exerciseDef, parseExercise } from "@/lib/exercises";
import { useCatalog } from "@/lib/catalog";
import { useAccountMode } from "@/lib/historyView";
import { syncNow } from "@/lib/syncRuntime";
import { SyncNotice } from "@/components/account/SyncNotice";
import { addAttempt, startSession, type LocalSession } from "@/lib/history";
import { textForExercise, useLang } from "@/lib/i18n";
import { Button, ButtonLink } from "@/components/ui/Button";
import { VideoUpload } from "@/components/video/VideoUpload";
import { AnalyzingNotice } from "@/components/analysis/AnalyzingNotice";
import { VerdictCard } from "@/components/analysis/VerdictCard";
import { AttemptList } from "@/components/analysis/AttemptList";

const INSTRUCTION_ERRORS = ["no_pose_detected", "video_too_short", "video_too_long", "recording_too_short"];

type State =
  | { kind: "idle" }
  | { kind: "analyzing" }
  | { kind: "result"; result: AnalysisResult; videoUrl: string }
  | { kind: "error"; code: string };

// SessionPage — страница занятия; упражнение читается из адреса (?e=E04), без него E02
export default function SessionPage() {
  return (
    <Suspense>
      <SessionRoute />
    </Suspense>
  );
}

// SessionRoute — пересоздаёт занятие при смене упражнения в адресе, чтобы старый результат и попытки не остались
function SessionRoute() {
  const exercise = parseExercise(useSearchParams().get("e"));
  return <SessionView key={exercise} exercise={exercise} />;
}

// SessionView — занятие: загрузка видео, анализ, результат и список повторений
function SessionView({ exercise }: { exercise: ExerciseId }) {
  const { t } = useLang();
  const router = useRouter();
  const def = exerciseDef(exercise);
  const availability = exerciseAvailability(useCatalog(), exercise);
  const mode = useAccountMode();
  const [state, setState] = useState<State>({ kind: "idle" });
  const [session, setSession] = useState<LocalSession | null>(null);
  const outcome = useRef<HTMLDivElement>(null);
  const videoUrl = useRef<string | null>(null);

  useEffect(() => {
    return () => {
      if (videoUrl.current) URL.revokeObjectURL(videoUrl.current);
    };
  }, []);

  useEffect(() => {
    if (state.kind === "result" || state.kind === "error") {
      outcome.current?.focus();
      outcome.current?.scrollIntoView({ block: "start", behavior: "smooth" });
    }
  }, [state.kind]);

  // handleFile — проверяет файл, отправляет его на анализ и добавляет результат в занятие
  async function handleFile(file: File) {
    const localError = checkVideoFile(file);
    if (localError) {
      setState({ kind: "error", code: localError });
      return;
    }
    setState({ kind: "analyzing" });
    const scenario = new URLSearchParams(window.location.search).get("mock_scenario") ?? undefined;
    try {
      const result = await analyzeVideo(file, exercise, scenario);
      setSession(addAttempt(session ?? startSession(exercise, mode.kind === "account" ? mode.userId : undefined), result));
      if (mode.kind === "account") void syncNow();
      if (videoUrl.current) URL.revokeObjectURL(videoUrl.current);
      videoUrl.current = URL.createObjectURL(file);
      setState({ kind: "result", result, videoUrl: videoUrl.current });
    } catch (e) {
      setState({ kind: "error", code: e instanceof AnalysisError ? e.code : "internal_error" });
    }
  }

  // finish — завершает занятие и открывает его итоги
  function finish() {
    if (!session) return;
    const id = session.id;
    setSession(null);
    setState({ kind: "idle" });
    router.push(`/summary?id=${id}`);
  }

  const attempts = session?.attempts ?? [];

  if (availability !== "ready") {
    return (
      <div className="space-y-6">
        <h1 className="text-3xl font-bold">{t.session_title}</h1>
        <p className="text-xl font-semibold">{t[def.titleKey]}</p>
        {availability === "loading" ? (
          <p className="text-lg text-muted">{t.loading}</p>
        ) : (
          <>
            <p className="rounded-2xl bg-neutral-soft p-5 text-lg font-semibold text-neutral-ink">{t.exercise_soon_hint}</p>
            <ButtonLink href="/" variant="secondary" className="w-full sm:w-auto">
              {t.back_to_exercises}
            </ButtonLink>
          </>
        )}
      </div>
    );
  }

  return (
    <div className="space-y-8">
      <section className="space-y-2">
        <h1 className="text-3xl font-bold">{t.session_title}</h1>
        <p className="text-xl font-semibold">{t[def.titleKey]}</p>
        {state.kind === "idle" && attempts.length === 0 && <p className="text-lg">{t.session_hint}</p>}
      </section>

      {state.kind === "idle" && (
        <div className="flex gap-3 rounded-2xl bg-neutral-soft p-5 text-lg text-neutral-ink">
          <Info aria-hidden className="mt-1 size-6 shrink-0" />
          <p>
            {t[def.reminderKey]}{" "}
            <Link href={`/exercise?e=${exercise}`} className="font-semibold underline underline-offset-4">
              {t.watch_instruction}
            </Link>
          </p>
        </div>
      )}

      <div aria-live="polite" ref={outcome} tabIndex={-1} className="scroll-mt-6 space-y-6 outline-none">
        {state.kind === "analyzing" && <AnalyzingNotice t={t} />}

        {state.kind === "result" && <VerdictCard result={state.result} videoUrl={state.videoUrl} onAnother={() => setState({ kind: "idle" })} t={t} />}

        {state.kind === "error" && (
          <div className="space-y-4">
            <div className="flex gap-3 rounded-2xl bg-error-soft p-5 text-lg text-error-ink">
              <AlertCircle aria-hidden className="mt-1 size-6 shrink-0" />
              <p>{textForExercise(t, `error_${state.code}`, exercise, "error_internal_error")}</p>
            </div>
            {INSTRUCTION_ERRORS.includes(state.code) && (
              <ButtonLink href={`/exercise?e=${exercise}`} variant="secondary" className="w-full sm:w-auto">
                {t.watch_instruction}
              </ButtonLink>
            )}
          </div>
        )}
      </div>

      {state.kind === "idle" && <VideoUpload onFile={handleFile} t={t} />}

      {state.kind === "error" && (
        <Button onClick={() => setState({ kind: "idle" })} className="w-full sm:w-auto">
          <RotateCcw aria-hidden className="size-6" />
          {t.try_again}
        </Button>
      )}

      {attempts.length > 0 && state.kind !== "analyzing" && (
        <section className="space-y-4 border-t border-line pt-8">
          <h2 className="text-2xl font-bold">{t.attempts_title}</h2>
          <SyncNotice />
          <AttemptList attempts={attempts} exercise={exercise} t={t} />
          <Button variant="secondary" onClick={finish} className="w-full sm:w-auto">
            <Flag aria-hidden className="size-6" />
            {t.finish_session}
          </Button>
        </section>
      )}
    </div>
  );
}
