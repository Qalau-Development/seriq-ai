"use client";

import { Suspense, useEffect, useRef, useState } from "react";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { Flag, RotateCcw } from "lucide-react";
import type { AnalysisResult, ExerciseId } from "@/types/analysis";
import { AnalysisError, analyzeVideo, checkVideoFile } from "@/lib/api";
import { toPlayableVideo } from "@/lib/playableVideo";
import { exerciseAvailability, exerciseDef, parseExercise } from "@/lib/exercises";
import { useCatalog } from "@/lib/catalog";
import { useAccountMode } from "@/lib/historyView";
import { syncNow } from "@/lib/syncRuntime";
import { SyncNotice } from "@/components/account/SyncNotice";
import { addAttempt, startSession, type LocalSession } from "@/lib/history";
import { textForExercise, useLang } from "@/lib/i18n";
import { Button, ButtonLink } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";
import { Notice } from "@/components/ui/Notice";
import { VideoUpload } from "@/components/video/VideoUpload";
import type { RepOutcome } from "@/components/video/LiveCoachRecorder";
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
  const sessionRef = useRef<LocalSession | null>(null);

  useEffect(() => {
    sessionRef.current = session;
  }, [session]);

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
      videoUrl.current = URL.createObjectURL(await toPlayableVideo(file));
      setState({ kind: "result", result, videoUrl: videoUrl.current });
    } catch (e) {
      setState({ kind: "error", code: e instanceof AnalysisError ? e.code : "internal_error" });
    }
  }

  // handleLiveRep — повтор из живого режима: анализ в фоне и попытка в занятии, экран живого режима не закрывается
  async function handleLiveRep(file: File): Promise<RepOutcome> {
    const localError = checkVideoFile(file);
    if (localError) return { error: localError };
    try {
      const result = await analyzeVideo(file, exercise);
      const updated = addAttempt(sessionRef.current ?? startSession(exercise, mode.kind === "account" ? mode.userId : undefined), result);
      sessionRef.current = updated;
      setSession(updated);
      if (mode.kind === "account") void syncNow();
      return { verdict: result.verdict };
    } catch (e) {
      return { error: e instanceof AnalysisError ? e.code : "internal_error" };
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

  const header = (
    <div className="flex flex-col gap-1.5">
      <h1 className="text-[32px] leading-[38px] font-extrabold tracking-[-0.01em] text-balance sm:text-[38px] sm:leading-[46px] lg:text-[44px] lg:leading-[53px]">{t.session_title}</h1>
      <p className="text-xl leading-[30px] font-bold text-pretty text-link sm:text-[26px] sm:leading-[34px]">{t[def.titleKey]}</p>
    </div>
  );

  if (availability !== "ready") {
    return (
      <div className="flex flex-col gap-7">
        {header}
        {availability === "loading" ? (
          <p className="text-lg text-muted">{t.loading}</p>
        ) : (
          <div className="flex max-w-[880px] flex-col gap-5">
            <Notice kind="info">{t.exercise_soon_hint}</Notice>
            <div>
              <ButtonLink href="/" variant="secondary">
                {t.back_to_exercises}
              </ButtonLink>
            </div>
          </div>
        )}
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-7 lg:gap-8">
      {header}

      {state.kind === "idle" && (
        <div className="group mx-auto w-full max-w-[880px] has-[[data-camera]]:max-w-none">
          <Card className="flex flex-col gap-6 group-has-[[data-camera]]:border-0 group-has-[[data-camera]]:bg-transparent group-has-[[data-camera]]:p-0 group-has-[[data-camera]]:shadow-none">
            {attempts.length === 0 && <p className="text-[22px] leading-[33px] font-semibold text-pretty group-has-[[data-camera]]:hidden">{t.session_hint}</p>}
            <Notice kind="info">
              {t[def.reminderKey]}{" "}
              <Link href={`/exercise?e=${exercise}`} className="font-bold whitespace-nowrap underline underline-offset-4">
                {t.watch_instruction}
              </Link>
            </Notice>
            <VideoUpload
              onFile={handleFile}
              onLiveRep={handleLiveRep}
              liveErrorText={(code) => textForExercise(t, `error_${code}`, exercise, "error_internal_error")}
              exercise={exercise}
              t={t}
            />
          </Card>
        </div>
      )}

      <div aria-live="polite" ref={outcome} tabIndex={-1} className="scroll-mt-6" style={{ outline: "none" }}>
        {state.kind === "analyzing" && <AnalyzingNotice t={t} />}

        {state.kind === "result" && <VerdictCard result={state.result} videoUrl={state.videoUrl} onAnother={() => setState({ kind: "idle" })} t={t} />}

        {state.kind === "error" && (
          <div className="mx-auto flex w-full max-w-[880px] flex-col gap-6">
            <Notice kind="error">{textForExercise(t, `error_${state.code}`, exercise, "error_internal_error")}</Notice>
            <div className="flex flex-col gap-3 sm:flex-row sm:flex-wrap sm:gap-4">
              {INSTRUCTION_ERRORS.includes(state.code) && (
                <ButtonLink href={`/exercise?e=${exercise}`} variant="secondary">
                  {t.watch_instruction}
                </ButtonLink>
              )}
              <Button onClick={() => setState({ kind: "idle" })}>
                <RotateCcw aria-hidden className="size-6" />
                {t.try_again}
              </Button>
            </div>
          </div>
        )}
      </div>

      {attempts.length > 0 && state.kind !== "analyzing" && (
        <section className="flex flex-col gap-5 lg:gap-6">
          <h2 className="text-[26px] leading-[31px] font-extrabold tracking-[-0.01em] text-balance sm:text-[32px] sm:leading-[38px]">{t.attempts_title}</h2>
          <SyncNotice />
          <AttemptList attempts={attempts} exercise={exercise} t={t} />
          <Button variant="secondary" onClick={finish}>
            <Flag aria-hidden className="size-6" />
            {t.finish_session}
          </Button>
        </section>
      )}
    </div>
  );
}
