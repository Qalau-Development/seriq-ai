"use client";

import { useEffect, useRef, useState } from "react";
import type { Point, Pose } from "@/types/analysis";
import type { Dict } from "@/lib/i18n";
import { panelClass } from "@/components/ui/Card";
import { Notice } from "@/components/ui/Notice";

// Общие для сайта и приложения: цвет и толщина линии руки (в CSS-пикселях)
export const POSE_STYLE = {
  line: "#22c55e",
  lineWidth: 6,
  outline: "rgba(0, 0, 0, 0.55)",
  jointRadius: 8,
  jointFill: "#ffffff",
  handRadius: 3,
  handFill: "rgba(255, 255, 255, 0.9)",
};

// Кости кисти: пары точек MediaPipe Hand Landmarker
const HAND_LINKS: [number, number][] = [
  [0, 1], [1, 2], [2, 3], [3, 4],
  [0, 5], [5, 6], [6, 7], [7, 8],
  [5, 9], [9, 10], [10, 11], [11, 12],
  [9, 13], [13, 14], [14, 15], [15, 16],
  [13, 17], [17, 18], [18, 19], [19, 20],
  [0, 17],
];
const FINGERTIPS = [4, 8, 12, 16, 20];

// Стиль скелета кисти (только сайт)
const SKELETON = { bone: "rgba(34, 197, 94, 0.95)", width: 3, tipRadius: 5.5, tipFill: "#facc15" };

// handAt — 21 точка кисти на момент времени: между двумя соседними кадрами ответа точки плавно сдвигаются
function handAt(pose: Pose, time: number): Point[] | null {
  const pos = time * pose.fps;
  const i0 = Math.floor(pos);
  const a = pose.frames[i0] ?? null;
  const b = pose.frames[i0 + 1] ?? null;
  if (a && b) {
    const k = pos - i0;
    return a.hand.map(([x, y], n) => [x + (b.hand[n][0] - x) * k, y + (b.hand[n][1] - y) * k] as Point);
  }
  const near = pose.frames[Math.round(pos)] ?? null;
  return near ? near.hand : null;
}

// contentRect — где на элементе <video> лежит сама картинка при object-fit: contain
function contentRect(video: HTMLVideoElement) {
  const cw = video.clientWidth;
  const ch = video.clientHeight;
  const vw = video.videoWidth || cw;
  const vh = video.videoHeight || ch;
  const scale = Math.min(cw / vw, ch / vh);
  const w = vw * scale;
  const h = vh * scale;
  return { x: (cw - w) / 2, y: (ch - h) / 2, w, h };
}

// drawPose — рисует точки кисти и, если локоть известен, линию локоть → запястье; для E01 — уровень старта и линию подъёма
function drawPose(video: HTMLVideoElement, canvas: HTMLCanvasElement, pose: Pose, missing: string, liftStart: Point | null = null) {
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

  const hand = handAt(pose, video.currentTime);
  if (!video.videoWidth) return;
  if (!hand) {
    ctx.font = "600 16px system-ui, sans-serif";
    const w = ctx.measureText(missing).width + 24;
    ctx.fillStyle = "rgba(0, 0, 0, 0.6)";
    ctx.beginPath();
    ctx.roundRect(12, 12, w, 34, 10);
    ctx.fill();
    ctx.fillStyle = "#ffffff";
    ctx.fillText(missing, 24, 34);
    return;
  }

  const r = contentRect(video);
  const at = ([x, y]: Point) => [r.x + x * r.w, r.y + y * r.h] as const;
  const elbow = pose.elbow ? at(pose.elbow) : null;
  const [wx, wy] = at(hand[0]);

  ctx.save();
  ctx.beginPath();
  ctx.rect(r.x, r.y, r.w, r.h);
  ctx.clip();
  ctx.lineCap = "round";
  if (liftStart) {
    const [, sy] = at(liftStart);
    ctx.setLineDash([10, 8]);
    ctx.lineWidth = 3;
    ctx.strokeStyle = "rgba(255, 255, 255, 0.9)";
    ctx.beginPath();
    ctx.moveTo(r.x, sy);
    ctx.lineTo(r.x + r.w, sy);
    ctx.stroke();
    ctx.setLineDash([]);
    ctx.strokeStyle = POSE_STYLE.outline;
    ctx.lineWidth = POSE_STYLE.lineWidth + 4;
    ctx.beginPath();
    ctx.moveTo(wx, sy);
    ctx.lineTo(wx, wy);
    ctx.stroke();
    ctx.strokeStyle = SKELETON.tipFill;
    ctx.lineWidth = POSE_STYLE.lineWidth;
    ctx.stroke();
  }
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

  const joints = hand.map(at);
  ctx.strokeStyle = POSE_STYLE.outline;
  ctx.lineWidth = SKELETON.width + 3;
  ctx.beginPath();
  for (const [a, b] of HAND_LINKS) {
    ctx.moveTo(joints[a][0], joints[a][1]);
    ctx.lineTo(joints[b][0], joints[b][1]);
  }
  ctx.stroke();
  ctx.strokeStyle = SKELETON.bone;
  ctx.lineWidth = SKELETON.width;
  ctx.beginPath();
  for (const [a, b] of HAND_LINKS) {
    ctx.moveTo(joints[a][0], joints[a][1]);
    ctx.lineTo(joints[b][0], joints[b][1]);
  }
  ctx.stroke();
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

// PoseVideo — видео пользователя с линией руки поверх, синхронно с ответом сервера
export function PoseVideo({ src, pose, liftStart = null, t }: { src: string; pose: Pose; liftStart?: Point | null; t: Dict }) {
  const video = useRef<HTMLVideoElement>(null);
  const canvas = useRef<HTMLCanvasElement>(null);
  const [failedSrc, setFailedSrc] = useState<string | null>(null);
  const failed = failedSrc === src;
  const sx = liftStart?.[0] ?? null;
  const sy = liftStart?.[1] ?? null;

  useEffect(() => {
    const v = video.current;
    const c = canvas.current;
    if (!v || !c) return;
    let frameId = 0;
    const start: Point | null = sx !== null && sy !== null ? [sx, sy] : null;
    const draw = () => drawPose(v, c, pose, t.pose_no_hand, start);
    const loop = () => {
      draw();
      if (!v.paused && !v.ended) frameId = requestAnimationFrame(loop);
    };
    const onPlay = () => {
      cancelAnimationFrame(frameId);
      frameId = requestAnimationFrame(loop);
    };
    const events = ["loadeddata", "seeked", "timeupdate", "pause"] as const;
    events.forEach((e) => v.addEventListener(e, draw));
    v.addEventListener("play", onPlay);
    const resize = new ResizeObserver(draw);
    resize.observe(v);
    return () => {
      cancelAnimationFrame(frameId);
      events.forEach((e) => v.removeEventListener(e, draw));
      v.removeEventListener("play", onPlay);
      resize.disconnect();
    };
  }, [pose, src, t.pose_no_hand, sx, sy]);

  return (
    <figure className={`${panelClass} flex flex-col gap-3.5 sm:gap-4`}>
      <figcaption className="text-[22px] leading-[26px] font-bold tracking-[-0.01em] text-balance sm:text-2xl sm:leading-[29px]">{t.pose_title}</figcaption>
      <div className="relative overflow-hidden rounded-[20px] bg-[#0b1e33]">
        <video
          ref={video}
          src={src}
          controls
          muted
          playsInline
          preload="auto"
          onError={() => setFailedSrc(src)}
          className="block max-h-[70vh] w-full object-contain"
        />
        <canvas ref={canvas} aria-hidden className="pointer-events-none absolute top-0 left-0 h-full w-full" />
      </div>
      {failed && (
        <Notice kind="info">{t.pose_video_unsupported}</Notice>
      )}
      <p className="text-base leading-6 text-pretty text-muted">{pose.elbow ? t.pose_hint : t.pose_hint_hand}</p>
    </figure>
  );
}
