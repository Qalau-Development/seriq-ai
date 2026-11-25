"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { AlertCircle, CheckCircle2, Circle, Info, Loader2, Upload, X } from "lucide-react";
import type { HandLandmarker, PoseLandmarker } from "@mediapipe/tasks-vision";
import { useLang, type Dict } from "@/lib/i18n";
import { LiveCoach, MIN_VISIBILITY, SAMPLE_FPS, TARGET_EXT, type CoachState, type CueKey, type ElbowMode, type Point } from "@/lib/liveCoach";
import { voice } from "@/lib/voice";
import { cueItem, LIVE_CLIP_IDS } from "@/lib/voiceClips";
import { Button } from "@/components/ui/Button";
import { POSE_STYLE } from "@/components/analysis/PoseVideo";

const WASM_URL = "https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@1.2.3/wasm";
const HAND_MODEL_URL = "https://storage.googleapis.com/mediapipe-models/hand_landmarker/hand_landmarker/float16/1/hand_landmarker.task";
const POSE_MODEL_URL = "https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_full/float16/1/pose_landmarker_full.task";
const POSE_ARMS: [number, number, number][] = [
  [11, 13, 15],
  [12, 14, 16],
];
const ELBOW_BAD = "#ef4444";
const MAX_SECONDS = 30;
const BITRATE = 2_500_000;
const CUE_TEXT: Record<CueKey, "live_show_hand" | "live_start" | "live_more" | "live_hold" | "live_slower" | "live_lost" | "live_back"> = {
  show_hand: "live_show_hand",
  start: "live_start",
  more: "live_more",
  hold: "live_hold",
  slower: "live_slower",
  lost: "live_lost",
  back: "live_back",
};

export type RepOutcome = { verdict: "completed" | "check_instructions" } | { error: string };
type Rep = { n: number; status: "analyzing" } | { n: number; status: "done"; outcome: RepOutcome };

// STATE_CUE — какую подсказку вернуть на экран, когда кисть снова видна после «Рука не видна»
const STATE_CUE: Record<CoachState, CueKey> = { wait: "show_hand", extend: "start", hold: "hold", return: "back" };

type Facing = "user" | "environment";
type Orientation = "portrait" | "landscape";

// cameraConstraints — какую камеру открыть: фронтальную или заднюю, кадр вертикальный или горизонтальный
function cameraConstraints(facing: Facing, orientation: Orientation): MediaStreamConstraints {
  const [width, height] = orientation === "landscape" ? [1280, 720] : [720, 1280];
  return {
    video: { facingMode: { ideal: facing }, width: { ideal: width }, height: { ideal: height }, aspectRatio: { ideal: width / height } },
    audio: false,
  };
}

type Phase = { kind: "loading" } | { kind: "live" } | { kind: "error"; code: "camera_denied" | "live_model_failed" };

// createLandmarker — загружает MediaPipe HandLandmarker в браузере, ту же модель кисти, что на сервере
async function createLandmarker(): Promise<HandLandmarker> {
  const { FilesetResolver, HandLandmarker } = await import("@mediapipe/tasks-vision");
  const fileset = await FilesetResolver.forVisionTasks(WASM_URL);
  const options = {
    numHands: 1,
    runningMode: "VIDEO" as const,
    minHandDetectionConfidence: 0.3,
    minHandPresenceConfidence: 0.3,
    minTrackingConfidence: 0.3,
  };
  try {
    return await HandLandmarker.createFromOptions(fileset, { ...options, baseOptions: { modelAssetPath: HAND_MODEL_URL, delegate: "GPU" } });
  } catch {
    return HandLandmarker.createFromOptions(fileset, { ...options, baseOptions: { modelAssetPath: HAND_MODEL_URL, delegate: "CPU" } });
  }
}

// createPoseLandmarker — загружает MediaPipe PoseLandmarker: плечо, локоть и запястье для режима без стола
async function createPoseLandmarker(): Promise<PoseLandmarker> {
  const { FilesetResolver, PoseLandmarker } = await import("@mediapipe/tasks-vision");
  const fileset = await FilesetResolver.forVisionTasks(WASM_URL);
  const options = { numPoses: 1, runningMode: "VIDEO" as const, minPoseDetectionConfidence: 0.5, minPosePresenceConfidence: 0.5, minTrackingConfidence: 0.5 };
  try {
    return await PoseLandmarker.createFromOptions(fileset, { ...options, baseOptions: { modelAssetPath: POSE_MODEL_URL, delegate: "GPU" } });
  } catch {
    return PoseLandmarker.createFromOptions(fileset, { ...options, baseOptions: { modelAssetPath: POSE_MODEL_URL, delegate: "CPU" } });
  }
}

// armFromPose — плечо, локоть и запястье более заметной руки в пикселях кадра и наименьшая видимость из трёх точек
function armFromPose(landmarks: { x: number; y: number; visibility?: number }[], w: number, h: number): { arm: [Point, Point, Point]; visibility: number } {
  let best: { arm: [Point, Point, Point]; visibility: number } | null = null;
  for (const ids of POSE_ARMS) {
    const visibility = Math.min(...ids.map((i) => landmarks[i].visibility ?? 0));
    if (!best || visibility > best.visibility) {
      best = { arm: ids.map((i) => [landmarks[i].x * w, landmarks[i].y * h] as Point) as [Point, Point, Point], visibility };
    }
  }
  return best!;
}

// pickMimeType — выбирает формат записи, который поддерживает браузер
function pickMimeType(): string {
  const types = ["video/mp4", "video/webm;codecs=vp9", "video/webm"];
  return types.find((t) => MediaRecorder.isTypeSupported(t)) ?? "";
}

// Кости кисти и кончики пальцев — как на экране результата (PoseVideo)
const HAND_LINKS: [number, number][] = [
  [0, 1], [1, 2], [2, 3], [3, 4],
  [0, 5], [5, 6], [6, 7], [7, 8],
  [5, 9], [9, 10], [10, 11], [11, 12],
  [9, 13], [13, 14], [14, 15], [15, 16],
  [13, 17], [17, 18], [18, 19], [19, 20],
  [0, 17],
];
const FINGERTIPS = [4, 8, 12, 16, 20];
const SKELETON = { bone: "rgba(34, 197, 94, 0.95)", width: 3, tipRadius: 5.5, tipFill: "#facc15" };
const HOLD_MS = 300;

type Drawn = { hand: Point[] | null; elbow: Point | null; arm: { points: [Point, Point, Point]; ok: boolean } | null; at: number };

// drawOverlay — скелет кисти и линия локоть → запястье в стиле экрана результата; при коротком пропуске держит прошлый рисунок
function drawOverlay(canvas: HTMLCanvasElement, video: HTMLVideoElement, drawn: Drawn | null, now: number) {
  const dpr = window.devicePixelRatio || 1;
  const cw = video.clientWidth;
  const ch = video.clientHeight;
  if (canvas.width !== Math.round(cw * dpr) || canvas.height !== Math.round(ch * dpr)) {
    canvas.width = Math.round(cw * dpr);
    canvas.height = Math.round(ch * dpr);
  }
  const ctx = canvas.getContext("2d");
  if (!ctx) return;
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  ctx.clearRect(0, 0, cw, ch);
  if (!drawn || now - drawn.at > HOLD_MS || !video.videoWidth) return;

  const vw = video.videoWidth;
  const vh = video.videoHeight;
  const scale = Math.min(cw / vw, ch / vh);
  const ox = (cw - vw * scale) / 2;
  const oy = (ch - vh * scale) / 2;
  const at = ([x, y]: Point) => [ox + x * scale, oy + y * scale] as const;

  ctx.save();
  ctx.lineCap = "round";
  if (drawn.arm) {
    const [s, e, w] = drawn.arm.points.map(at);
    const color = drawn.arm.ok ? POSE_STYLE.line : ELBOW_BAD;
    for (const [from, to] of [[s, e], [e, w]] as const) {
      ctx.strokeStyle = POSE_STYLE.outline;
      ctx.lineWidth = POSE_STYLE.lineWidth + 4;
      ctx.beginPath();
      ctx.moveTo(from[0], from[1]);
      ctx.lineTo(to[0], to[1]);
      ctx.stroke();
      ctx.strokeStyle = color;
      ctx.lineWidth = POSE_STYLE.lineWidth;
      ctx.stroke();
    }
    for (const [[x, y], r] of [[s, POSE_STYLE.jointRadius], [w, POSE_STYLE.jointRadius], [e, POSE_STYLE.jointRadius * 1.8]] as const) {
      ctx.beginPath();
      ctx.arc(x, y, r, 0, Math.PI * 2);
      ctx.fillStyle = r > POSE_STYLE.jointRadius ? color : POSE_STYLE.jointFill;
      ctx.fill();
      ctx.lineWidth = 3;
      ctx.strokeStyle = r > POSE_STYLE.jointRadius ? POSE_STYLE.jointFill : color;
      ctx.stroke();
    }
  }
  if (!drawn.hand) {
    ctx.restore();
    return;
  }
  const joints = drawn.hand.map(at);
  const [wx, wy] = joints[0];
  const elbow = drawn.elbow ? at(drawn.elbow) : null;

  if (elbow) {
    ctx.strokeStyle = POSE_STYLE.outline;
    ctx.lineWidth = POSE_STYLE.lineWidth + 4;
    ctx.beginPath();
    ctx.moveTo(elbow[0], elbow[1]);
    ctx.lineTo(wx, wy);
    ctx.stroke();
    ctx.strokeStyle = POSE_STYLE.line;
    ctx.lineWidth = POSE_STYLE.lineWidth;
    ctx.stroke();
  }
  for (const [style, width] of [
    [POSE_STYLE.outline, SKELETON.width + 3],
    [SKELETON.bone, SKELETON.width],
  ] as const) {
    ctx.strokeStyle = style;
    ctx.lineWidth = width;
    ctx.beginPath();
    for (const [a, b] of HAND_LINKS) {
      ctx.moveTo(joints[a][0], joints[a][1]);
      ctx.lineTo(joints[b][0], joints[b][1]);
    }
    ctx.stroke();
  }
  joints.slice(1).forEach(([x, y], n) => {
    const tip = FINGERTIPS.includes(n + 1);
    ctx.beginPath();
    ctx.arc(x, y, tip ? SKELETON.tipRadius : POSE_STYLE.handRadius, 0, Math.PI * 2);
    ctx.fillStyle = tip ? SKELETON.tipFill : POSE_STYLE.handFill;
    ctx.fill();
  });
  for (const [x, y] of elbow ? [elbow, [wx, wy]] : [[wx, wy]]) {
    ctx.beginPath();
    ctx.arc(x, y, POSE_STYLE.jointRadius, 0, Math.PI * 2);
    ctx.fillStyle = POSE_STYLE.jointFill;
    ctx.fill();
    ctx.lineWidth = 3;
    ctx.strokeStyle = POSE_STYLE.line;
    ctx.stroke();
  }
  ctx.restore();
}

// LiveCoachRecorder — живой режим E02: подсказки по ходу повторов; каждый повтор уходит на анализ в фоне, режим работает до закрытия
export function LiveCoachRecorder({
  onRep,
  onCancel,
  onUploadInstead,
  errorText,
  t,
}: {
  onRep: (file: File) => Promise<RepOutcome>;
  onCancel: () => void;
  onUploadInstead: () => void;
  errorText: (code: string) => string;
  t: Dict;
}) {
  const { lang } = useLang();
  const [phase, setPhase] = useState<Phase>({ kind: "loading" });
  const [message, setMessage] = useState<string>(t.live_show_hand);
  const [progress, setProgress] = useState(0);
  const [angle, setAngle] = useState<number | null>(null);
  const [unstable, setUnstable] = useState(false);
  const [cameraOn, setCameraOn] = useState(false);
  const [recording, setRecording] = useState(false);
  const [reps, setReps] = useState<Rep[]>([]);
  const [mode, setMode] = useState<ElbowMode>("pose");
  const modeRef = useRef<ElbowMode>(mode);
  const [facing, setFacing] = useState<Facing>("user");
  const [orientation, setOrientation] = useState<Orientation>("landscape");
  const [aspect, setAspect] = useState(16 / 9);
  const [manyCameras, setManyCameras] = useState(false);
  const [switching, setSwitching] = useState(false);
  const facingRef = useRef<Facing>(facing);
  const orientationRef = useRef<Orientation>(orientation);
  const cameraGen = useRef(0);
  const poseLandmarker = useRef<PoseLandmarker | null>(null);
  const onRepRef = useRef(onRep);
  const queue = useRef<Promise<void>>(Promise.resolve());
  const repCount = useRef(0);
  const video = useRef<HTMLVideoElement>(null);
  const canvas = useRef<HTMLCanvasElement>(null);
  const stream = useRef<MediaStream | null>(null);
  const recorder = useRef<MediaRecorder | null>(null);
  const landmarker = useRef<HandLandmarker | null>(null);
  const frame = useRef<number | null>(null);
  const stopTimer = useRef<number | null>(null);
  const tRef = useRef(t);

  useEffect(() => {
    voice.preload(LIVE_CLIP_IDS, lang);
    return () => voice.stop();
  }, [lang]);

  useEffect(() => {
    tRef.current = t;
    onRepRef.current = onRep;
  }, [t, onRep]);

  // shutdown — останавливает цикл распознавания, запись, камеру и модель
  const shutdown = useCallback((keepRecording: boolean) => {
    cameraGen.current++;
    if (frame.current !== null) cancelAnimationFrame(frame.current);
    frame.current = null;
    if (stopTimer.current !== null) window.clearTimeout(stopTimer.current);
    if (!keepRecording && recorder.current?.state === "recording") {
      recorder.current.onstop = null;
      recorder.current.stop();
    }
    stream.current?.getTracks().forEach((track) => track.stop());
    stream.current = null;
    landmarker.current?.close();
    landmarker.current = null;
    poseLandmarker.current?.close();
    poseLandmarker.current = null;
  }, []);

  // cueText — текст подсказки; в режиме без стола просьба показать руку своя
  const cueText = useCallback((key: CueKey) => (key === "show_hand" && modeRef.current === "pose" ? tRef.current.live_show_arm : tRef.current[CUE_TEXT[key]]), []);

  // say — показывает подсказку и озвучивает её, если в браузере есть голос для языка
  const say = useCallback(
    (key: CueKey) => {
      const text = cueText(key);
      setMessage(text);
      const item = cueItem(tRef.current, key, modeRef.current === "pose");
      if (item) voice.playCue(item, lang);
    },
    [lang, cueText],
  );

  // analyzeRep — ставит запись повтора в очередь анализа: по одному, чтобы сервер не отвечал «занят»
  const analyzeRep = useCallback(
    (file: File) => {
      const n = ++repCount.current;
      setReps((list) => [...list, { n, status: "analyzing" }]);
      queue.current = queue.current.then(async () => {
        const outcome = await onRepRef.current(file).catch(() => ({ error: "internal_error" }) as RepOutcome);
        setReps((list) => list.map((r) => (r.n === n ? { n, status: "done", outcome } : r)));
        if ("verdict" in outcome) {
          const id = outcome.verdict === "completed" ? "verdict_completed" : "verdict_check_instructions";
          voice.playCue({ id, text: tRef.current[id] }, lang, true);
        }
      });
    },
    [lang],
  );

  // startRecording — запись повтора с момента подсказки «Разогните руку»; по остановке запись уходит на анализ
  const startRecording = useCallback(
    (media: MediaStream) => {
      const mimeType = pickMimeType();
      const rec = new MediaRecorder(media, { ...(mimeType && { mimeType }), videoBitsPerSecond: BITRATE });
      const chunks: Blob[] = [];
      rec.ondataavailable = (e) => e.data.size > 0 && chunks.push(e.data);
      rec.onstop = () => {
        if (stopTimer.current !== null) window.clearTimeout(stopTimer.current);
        recorder.current = null;
        setRecording(false);
        const type = rec.mimeType || mimeType || "video/webm";
        const ext = type.startsWith("video/mp4") ? ".mp4" : ".webm";
        analyzeRep(new File(chunks, `live${ext}`, { type }));
      };
      recorder.current = rec;
      rec.start(250);
      setRecording(true);
      stopTimer.current = window.setTimeout(() => rec.state === "recording" && rec.stop(), MAX_SECONDS * 1000);
    },
    [analyzeRep],
  );

  useEffect(() => {
    let cancelled = false;
    modeRef.current = mode;
    const coach = new LiveCoach(mode);
    let last = -Infinity;
    let drawn: Drawn | null = null;
    let lastCue: CueKey = "show_hand";

    // loop — 10 раз в секунду: точки кисти, подсказки, рисование; по окончании повтора останавливает запись
    const loop = (now: number) => {
      frame.current = requestAnimationFrame(loop);
      const v = video.current;
      const lm = landmarker.current;
      const pl = poseLandmarker.current;
      if (!v || !lm || (mode === "pose" && !pl) || v.readyState < 2 || now - last < 1000 / SAMPLE_FPS) return;
      last = now;
      const res = lm.detectForVideo(v, now);
      const hand = res.landmarks[0];
      const handPoints = hand ? hand.map((q) => [q.x * v.videoWidth, q.y * v.videoHeight] as Point) : null;
      let armSeen: { arm: [Point, Point, Point]; visibility: number } | null = null;
      let cues: CueKey[];
      if (mode === "pose" && pl) {
        const pose = pl.detectForVideo(v, now).landmarks[0];
        armSeen = pose ? armFromPose(pose, v.videoWidth, v.videoHeight) : null;
        cues = coach.updatePose(now / 1000, armSeen?.arm ?? null, armSeen?.visibility ?? 0);
      } else {
        cues = coach.update(now / 1000, handPoints);
      }
      const points = mode === "pose" ? coach.arm : handPoints;
      if (cues.includes("start") && stream.current && !recorder.current) startRecording(stream.current);
      if (cues.length) {
        lastCue = cues[cues.length - 1];
        say(lastCue);
      } else if (lastCue === "lost" && points) {
        lastCue = STATE_CUE[coach.state];
        setMessage(cueText(lastCue));
      }
      const active = coach.state === "extend" || coach.state === "hold";
      setProgress(active ? Math.max(0, Math.min(1, coach.ext / TARGET_EXT)) : 0);
      setUnstable(active && coach.unstable);
      setAngle(active && !coach.unstable && coach.angle !== null ? Math.round(Math.min(180, Math.max(0, coach.angle))) : null);
      if (mode === "pose") {
        if (armSeen || handPoints) {
          drawn = {
            hand: handPoints,
            elbow: null,
            arm: armSeen ? { points: coach.arm ?? armSeen.arm, ok: armSeen.visibility >= MIN_VISIBILITY } : null,
            at: now,
          };
        }
      } else {
        const shown = coach.smoothed;
        if (shown) drawn = { hand: shown, elbow: active ? coach.elbow : null, arm: null, at: now };
      }
      if (canvas.current) drawOverlay(canvas.current, v, drawn, now);
      if (coach.finished) {
        if (recorder.current?.state === "recording") recorder.current.stop();
        coach.nextRep();
      }
    };

    const cameraReady = navigator.mediaDevices
      .getUserMedia(cameraConstraints(facingRef.current, orientationRef.current))
      .then((media) => {
        if (cancelled) {
          media.getTracks().forEach((track) => track.stop());
          return null;
        }
        stream.current = media;
        if (video.current) video.current.srcObject = media;
        setCameraOn(true);
        navigator.mediaDevices
          .enumerateDevices()
          .then((devices) => !cancelled && setManyCameras(devices.filter((d) => d.kind === "videoinput").length > 1))
          .catch(() => {});
        return media;
      })
      .catch(() => {
        if (!cancelled) setPhase({ kind: "error", code: "camera_denied" });
        return null;
      });
    const modelReady = createLandmarker().catch(() => null);
    const poseReady = mode === "pose" ? createPoseLandmarker().catch(() => null) : Promise.resolve(null);

    Promise.all([cameraReady, modelReady, poseReady]).then(([media, lm, pl]) => {
      if (cancelled || !media) {
        lm?.close();
        pl?.close();
        return;
      }
      if (!lm || (mode === "pose" && !pl)) {
        media.getTracks().forEach((track) => track.stop());
        lm?.close();
        pl?.close();
        setPhase({ kind: "error", code: "live_model_failed" });
        return;
      }
      landmarker.current = lm;
      poseLandmarker.current = pl;
      setPhase({ kind: "live" });
      say("show_hand");
      frame.current = requestAnimationFrame(loop);
    });

    return () => {
      cancelled = true;
      shutdown(false);
    };
  }, [mode, say, cueText, shutdown, startRecording]);

  // switchMode — меняет способ найти локоть; камера и распознавание перезапускаются
  function switchMode(next: ElbowMode) {
    if (next === mode) return;
    setPhase({ kind: "loading" });
    setCameraOn(false);
    setRecording(false);
    setMessage(next === "pose" ? t.live_show_arm : t.live_show_hand);
    setMode(next);
  }

  // switchCamera — открывает другую камеру или меняет форму кадра; модели и подсказки продолжают работать, недописанный повтор не отправляется
  async function switchCamera(nextFacing: Facing, nextOrientation: Orientation) {
    if (switching || (nextFacing === facing && nextOrientation === orientation)) return;
    const gen = cameraGen.current;
    const prev = { facing: facingRef.current, orientation: orientationRef.current };
    setSwitching(true);
    if (stopTimer.current !== null) window.clearTimeout(stopTimer.current);
    if (recorder.current?.state === "recording") {
      recorder.current.onstop = null;
      recorder.current.stop();
    }
    recorder.current = null;
    setRecording(false);
    stream.current?.getTracks().forEach((track) => track.stop());
    stream.current = null;
    let media: MediaStream | null = null;
    let applied = { facing: nextFacing, orientation: nextOrientation };
    try {
      media = await navigator.mediaDevices.getUserMedia(cameraConstraints(nextFacing, nextOrientation));
    } catch {
      applied = prev;
      media = await navigator.mediaDevices.getUserMedia(cameraConstraints(prev.facing, prev.orientation)).catch(() => null);
    }
    if (gen !== cameraGen.current) {
      media?.getTracks().forEach((track) => track.stop());
      setSwitching(false);
      return;
    }
    setSwitching(false);
    if (!media) {
      shutdown(false);
      setPhase({ kind: "error", code: "camera_denied" });
      return;
    }
    stream.current = media;
    if (video.current) video.current.srcObject = media;
    facingRef.current = applied.facing;
    orientationRef.current = applied.orientation;
    setFacing(applied.facing);
    setOrientation(applied.orientation);
  }

  // readAspect — форма кадра по настоящему размеру видео с камеры
  function readAspect() {
    const v = video.current;
    if (v && v.videoWidth > 0 && v.videoHeight > 0) setAspect(v.videoWidth / v.videoHeight);
  }

  // cancel — закрывает живой режим без отправки
  function cancel() {
    shutdown(false);
    onCancel();
  }

  if (phase.kind === "error") {
    return (
      <div className="space-y-4">
        <div className="flex gap-3 rounded-[20px] border-2 border-error-line bg-error-soft px-[18px] py-4 text-lg leading-[27px] font-bold text-error-ink sm:px-6" role="alert">
          <AlertCircle aria-hidden className="mt-1 size-6 shrink-0" />
          <p>{t[`error_${phase.code}`]}</p>
        </div>
        <div className="flex flex-col gap-3 sm:flex-row">
          <Button onClick={onUploadInstead}>
            <Upload aria-hidden className="size-6" />
            {t.camera_upload_instead}
          </Button>
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
      <div className="flex flex-col gap-2 sm:flex-row" role="group" aria-label={t.live_mode_label}>
        {(["pose", "arc"] as const).map((m) => (
          <Button key={m} variant={mode === m ? "primary" : "secondary"} aria-pressed={mode === m} onClick={() => switchMode(m)}>
            {m === "pose" ? t.live_mode_free : t.live_mode_table}
          </Button>
        ))}
      </div>
      <p className="text-base text-muted">{mode === "pose" ? t.live_mode_free_hint : t.live_mode_table_hint}</p>
      <div className="grid gap-2 sm:grid-cols-2">
        {manyCameras && (
          <div className="grid grid-cols-2 gap-2" role="group" aria-label={t.live_camera_label}>
            {(["user", "environment"] as const).map((f) => (
              <Button
                key={f}
                variant={facing === f ? "primary" : "secondary"}
                className="px-2!"
                aria-pressed={facing === f}
                disabled={!cameraOn || switching}
                onClick={() => switchCamera(f, orientation)}
              >
                {f === "user" ? t.live_camera_front : t.live_camera_back}
              </Button>
            ))}
          </div>
        )}
        <div className="grid grid-cols-2 gap-2" role="group" aria-label={t.live_orientation_label}>
          {(["portrait", "landscape"] as const).map((o) => (
            <Button
              key={o}
              variant={orientation === o ? "primary" : "secondary"}
              className="px-2!"
              aria-pressed={orientation === o}
              disabled={!cameraOn || switching}
              onClick={() => switchCamera(facing, o)}
            >
              {o === "portrait" ? t.live_orientation_portrait : t.live_orientation_landscape}
            </Button>
          ))}
        </div>
      </div>
      <div
        className="relative mx-auto w-full overflow-hidden rounded-[20px] bg-[#0b1e33]"
        style={{ aspectRatio: aspect, maxHeight: "70vh", maxWidth: `calc(70vh * ${aspect.toFixed(4)})` }}
      >
        <video ref={video} autoPlay muted playsInline onLoadedMetadata={readAspect} onResize={readAspect} className="size-full object-contain" />
        <canvas ref={canvas} aria-hidden className="pointer-events-none absolute inset-0 size-full" />
        {((phase.kind === "loading" && !cameraOn) || switching) && (
          <p className="absolute inset-0 flex items-center justify-center gap-3 text-xl font-semibold text-white">
            <Loader2 aria-hidden className="size-7 animate-spin" />
            {t.camera_starting}
          </p>
        )}
        {phase.kind === "loading" && cameraOn && (
          <p className="absolute top-3 right-3 flex items-center gap-2 rounded-full bg-[rgb(7_20_36/0.78)] px-4 py-2 text-base font-bold text-white sm:text-lg">
            <Loader2 aria-hidden className="size-5 animate-spin" />
            {t.live_loading}
          </p>
        )}
        {recording && (
          <p className="absolute top-3 left-3 flex items-center gap-2 rounded-full bg-[rgb(7_20_36/0.78)] px-4 py-2 text-base font-bold text-white sm:text-lg">
            <Circle aria-hidden className="size-4 animate-pulse fill-secondary text-secondary" />
            {t.camera_recording}
          </p>
        )}
      </div>

      {phase.kind === "live" && (
        <div className="space-y-3 rounded-3xl border-2 border-brand-soft-2 bg-neutral-soft p-5">
          <div className="flex flex-wrap items-start justify-between gap-4">
            <p className="text-2xl font-bold text-neutral-ink" aria-live="assertive">
              {message}
            </p>
            <div className="text-right">
              <p className="text-base text-muted">{t.live_angle}</p>
              {unstable ? (
                <p className="rounded-xl bg-warn-soft px-3 py-1 text-lg font-semibold text-warn-ink">{t.live_unstable}</p>
              ) : (
                <p className="text-5xl font-bold tabular-nums text-neutral-ink">{angle === null ? "—" : `${angle}°`}</p>
              )}
            </div>
          </div>
          <div>
            <p className="mb-2 text-base text-muted">{t.live_progress}</p>
            <div
              className="h-4 w-full overflow-hidden rounded-full bg-track"
              role="progressbar"
              aria-valuemin={0}
              aria-valuemax={100}
              aria-valuenow={Math.round(progress * 100)}
            >
              <div className="h-full rounded-full bg-accent-strong transition-[width] duration-150" style={{ width: `${progress * 100}%` }} />
            </div>
          </div>
        </div>
      )}

      <p className="text-base text-muted">{t.live_hint}</p>

      {reps.length > 0 && (
        <ol className="space-y-2" aria-live="polite">
          {[...reps].reverse().map((r) => (
            <li key={r.n} className="flex items-center gap-3 rounded-2xl border border-line bg-surface p-3.5 text-lg shadow-card">
              <span className="font-semibold">{t.live_rep.replace("{n}", String(r.n))}</span>
              {r.status === "analyzing" ? (
                <span className="flex items-center gap-2 text-muted">
                  <Loader2 aria-hidden className="size-5 animate-spin" />
                  {t.live_rep_analyzing}
                </span>
              ) : "verdict" in r.outcome ? (
                r.outcome.verdict === "completed" ? (
                  <span className="flex items-center gap-2 font-semibold text-brand">
                    <CheckCircle2 aria-hidden className="size-5" />
                    {t.verdict_completed}
                  </span>
                ) : (
                  <span className="flex items-center gap-2 font-semibold text-neutral-ink">
                    <Info aria-hidden className="size-5" />
                    {t.verdict_check_instructions}
                  </span>
                )
              ) : (
                <span className="text-error-ink">{errorText(r.outcome.error)}</span>
              )}
            </li>
          ))}
        </ol>
      )}

      <Button variant="secondary" onClick={cancel}>
        <X aria-hidden className="size-6" />
        {t.live_close}
      </Button>
    </div>
  );
}
