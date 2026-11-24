"use client";

import { useEffect, useRef } from "react";
import type { Point, Pose } from "@/types/analysis";
import type { Dict } from "@/lib/i18n";

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

// drawPose — рисует точки кисти и, если локоть известен, линию локоть → запястье для текущего кадра видео
function drawPose(video: HTMLVideoElement, canvas: HTMLCanvasElement, pose: Pose) {
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

  const i = Math.round(video.currentTime * pose.fps);
  const frame = i >= 0 && i < pose.frames.length ? pose.frames[i] : null;
  if (!frame || !video.videoWidth) return;

  const r = contentRect(video);
  const at = ([x, y]: Point) => [r.x + x * r.w, r.y + y * r.h] as const;
  const elbow = pose.elbow ? at(pose.elbow) : null;
  const [wx, wy] = at(frame.wrist);

  ctx.save();
  ctx.beginPath();
  ctx.rect(r.x, r.y, r.w, r.h);
  ctx.clip();
  ctx.lineCap = "round";
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

  for (const p of frame.hand.slice(1)) {
    const [x, y] = at(p);
    ctx.beginPath();
    ctx.arc(x, y, POSE_STYLE.handRadius, 0, Math.PI * 2);
    ctx.fillStyle = POSE_STYLE.handFill;
    ctx.fill();
  }
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
export function PoseVideo({ src, pose, t }: { src: string; pose: Pose; t: Dict }) {
  const video = useRef<HTMLVideoElement>(null);
  const canvas = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const v = video.current;
    const c = canvas.current;
    if (!v || !c) return;
    let frameId = 0;
    const draw = () => drawPose(v, c, pose);
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
  }, [pose, src]);

  return (
    <figure className="space-y-3">
      <figcaption className="text-xl font-bold">{t.pose_title}</figcaption>
      <div className="relative overflow-hidden rounded-2xl bg-ink">
        <video
          ref={video}
          src={src}
          controls
          muted
          playsInline
          preload="auto"
          className="block max-h-[70vh] w-full object-contain"
        />
        <canvas ref={canvas} aria-hidden className="pointer-events-none absolute top-0 left-0 h-full w-full" />
      </div>
      <p className="text-base text-muted">{t.pose_hint}</p>
    </figure>
  );
}
