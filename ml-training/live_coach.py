import argparse
import subprocess
import sys
import time
from pathlib import Path

import cv2
import mediapipe as mp
import numpy as np
from mediapipe.tasks import python as mp_python
from mediapipe.tasks.python import vision
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "ai-engine"))

from seriq_engine.angles import K_FOREARM, elbow_angle_series, elbow_center, fill_gaps, smooth  # noqa: E402
from seriq_engine.classifier import decide, load_bundle, predict_complete, signal_quality  # noqa: E402
from seriq_engine.errors import ArmNotFound  # noqa: E402
from seriq_engine.features import compute_features  # noqa: E402
from seriq_engine.hand import MIDDLE_MCP, WRIST  # noqa: E402

HAND_MODEL = ROOT / "data/processed/mp_models/hand_landmarker.task"
E02_MODEL = ROOT / "models/e02_classifier.joblib"
POSE_MODEL = ROOT / "data/processed/mp_models/pose_landmarker_full.task"
POSE_ARMS = ((11, 13, 15), (12, 14, 16))
MIN_VIS = 0.5
FONT = "/System/Library/Fonts/Supplemental/Arial Unicode.ttf"
SAMPLE_FPS = 10.0
TARGET_EXT = 65.0
STALL_DEG = 4.0
STALL_S = 1.5
FAST_SPEED = 150.0
LOST_S = 0.8
STILL_S = 1.0
HOLD_S = 1.0
REPEAT_S = 3.0
REPEAT_LONG_S = 8.0
SPEED_WINDOW = 4
REFIT_GROWTH = 1.1
MAX_JUMP_HAND_LENS = 2.0
MAX_SIZE_CHANGE = 0.4

TEXTS = {
    "ru": {
        "show_hand": "Положите руку на стол, кулак и предплечье в кадре",
        "show_arm": "Повернитесь боком: плечо, локоть и кулак в кадре",
        "start": "Разогните руку",
        "more": "Разогните ещё немного",
        "hold": "Хорошо, задержите",
        "slower": "Чуть медленнее",
        "lost": "Рука не видна",
        "completed": "Выполнено",
        "check_instructions": "Проверьте инструкцию",
        "back": "Теперь вернитесь в исходное положение",
    },
    "kk": {
        "show_hand": "Қолыңызды үстелге қойыңыз, жұдырық пен білек кадрда болсын",
        "show_arm": "Бүйіріңізбен бұрылыңыз: иық, шынтақ және жұдырық кадрда болсын",
        "start": "Қолыңызды жазыңыз",
        "more": "Тағы аздап жазыңыз",
        "hold": "Жақсы, ұстап тұрыңыз",
        "slower": "Баяуырақ",
        "lost": "Қол көрінбейді",
        "completed": "Орындалды",
        "check_instructions": "Нұсқаулықты тексеріңіз",
        "back": "Енді бастапқы қалпыңызға оралыңыз",
    },
}
VOICES = {"ru": "Milena", "kk": "Aru"}


# OneEuro — фильтр One Euro для 21 точки кисти: убирает дрожание в покое и почти не запаздывает при движении
class OneEuro:
    # __init__ — параметры фильтра: базовая частота среза и рост среза со скоростью
    def __init__(self, min_cutoff: float = 1.5, beta: float = 0.01, d_cutoff: float = 1.0):
        self.min_cutoff, self.beta, self.d_cutoff = min_cutoff, beta, d_cutoff
        self.x = self.dx = self.t = None

    # alpha — коэффициент сглаживания для частоты среза и шага времени
    @staticmethod
    def alpha(cutoff: np.ndarray | float, dt: float) -> np.ndarray | float:
        tau = 1.0 / (2 * np.pi * cutoff)
        return 1.0 / (1.0 + tau / dt)

    # __call__ — сглаженные точки для нового кадра
    def __call__(self, t: float, x: np.ndarray) -> np.ndarray:
        if self.x is None or t <= self.t or t - self.t > 0.5:
            self.x, self.dx, self.t = x.copy(), np.zeros_like(x), t
            return x.copy()
        dt = t - self.t
        dx = (x - self.x) / dt
        self.dx = self.dx + self.alpha(self.d_cutoff, dt) * (dx - self.dx)
        cutoff = self.min_cutoff + self.beta * np.abs(self.dx)
        self.x = self.x + self.alpha(cutoff, dt) * (x - self.x)
        self.t = t
        return self.x.copy()

    # reset — сброс после пропажи кисти
    def reset(self) -> None:
        self.x = self.dx = self.t = None


# arm_from_pose — плечо, локоть и запястье более заметной руки в пикселях и наименьшая видимость из трёх точек
def arm_from_pose(landmarks, w: int, h: int) -> tuple[np.ndarray, float]:
    best = None
    for ids in POSE_ARMS:
        vis = min(landmarks[i].visibility for i in ids)
        if best is None or vis > best[1]:
            best = (np.array([(landmarks[i].x * w, landmarks[i].y * h) for i in ids]), float(vis))
    return best


# joint_angle — угол в локте между плечом и запястьем, 180° — рука прямая
def joint_angle(arm: np.ndarray) -> float:
    a, b = arm[0] - arm[1], arm[2] - arm[1]
    cos = float(np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b) + 1e-9))
    return float(np.degrees(np.arccos(np.clip(cos, -1.0, 1.0))))


# Coach — состояние живого повтора E02: по точкам кисти выдаёт подсказки и вердикт модели
class Coach:
    # __init__ — пустое состояние, ожидание руки
    def __init__(self, bundle: dict, from_start: bool = False, mode: str = "arc"):
        self.bundle = bundle
        self.from_start = from_start
        self.mode = mode
        self.pose_angles: list[float] = []
        self.arm_filter = OneEuro()
        self.arm = None
        self.raw_arm = None
        self.last_good = None
        self.unstable = False
        self.arm_vis = 0.0
        self.state = "wait"
        self.points: list[np.ndarray] = []
        self.smoothed: list[np.ndarray] = []
        self.filter = OneEuro()
        self.fit_n = 0
        self.fit_span = 0.0
        self.side = 1
        self.times: list[float] = []
        self.last_seen = None
        self.still_since = None
        self.stall_since = None
        self.hold_since = None
        self.start_n = 0
        self.rep_from = 0
        self.elbow = None
        self.last_cue: dict[str, float] = {}
        self.angle = None
        self.ext = 0.0
        self.peak_ext = 0.0
        self.result = None
        self.reps = 0

    # cue — подсказка, не чаще раза в REPEAT_S секунд для одного ключа, просьба показать руку реже
    def cue(self, key: str, t: float, out: list[str], force: bool = False) -> None:
        repeat = REPEAT_LONG_S if key in ("show_hand", "show_arm") else REPEAT_S
        if force or t - self.last_cue.get(key, -1e9) >= repeat:
            self.last_cue[key] = t
            out.append(key)

    # rep_angles — угол по сглаженным точкам повтора; локоть уточняется, только пока дуга запястья растёт
    def rep_angles(self) -> np.ndarray | None:
        if self.mode == "pose":
            series = smooth(fill_gaps(np.array(self.pose_angles[self.rep_from:], dtype=float)))
            return None if np.all(np.isnan(series)) else series
        pts = np.array(self.smoothed[self.rep_from:])
        wrist = pts[~np.isnan(pts[:, WRIST, 0]), WRIST]
        if len(wrist) == 0:
            return None
        span = float(np.ptp(wrist, axis=0).max())
        if self.elbow is None or (len(pts) - self.fit_n >= 5 and span > self.fit_span * REFIT_GROWTH):
            try:
                self.elbow = elbow_center(pts)[0]
            except ArmNotFound:
                return None
            self.fit_n, self.fit_span = len(pts), span
            self.side = 1 if np.nanmedian(pts[:, WRIST, 0] - self.elbow[0]) >= 0 else -1
        dx = (pts[:, WRIST, 0] - self.elbow[0]) * self.side
        dy = self.elbow[1] - pts[:, WRIST, 1]
        return smooth(180.0 - np.degrees(np.arctan2(dy, dx)))

    # reset_rep — начало нового повтора от неподвижной руки
    def reset_rep(self) -> None:
        self.rep_from = len(self.points) - 1 if self.from_start and self.state == "wait" else max(0, len(self.points) - int(SAMPLE_FPS * STILL_S))
        self.start_n = len(self.points) - self.rep_from
        self.elbow = None
        self.fit_n, self.fit_span = 0, 0.0
        self.peak_ext = self.ext = 0.0
        self.angle = None
        self.stall_since = self.hold_since = None
        self.result = None

    # verdict — вердикт модели E02 по точкам повтора, теми же функциями, что на сервере
    def verdict(self) -> dict:
        if self.mode == "pose":
            series = smooth(fill_gaps(np.array(self.pose_angles[self.rep_from:], dtype=float)))
        else:
            try:
                series = elbow_angle_series(np.array(self.points[self.rep_from:]))
            except ArmNotFound:
                return {"label": "uncertain", "confidence": 0.0, "verdict": "check_instructions"}
        quality = signal_quality(series, SAMPLE_FPS)
        p = predict_complete(self.bundle, compute_features(series, SAMPLE_FPS))
        label, confidence = decide(p, quality.ok, self.bundle["confidence_threshold"])
        self.reps += 1
        return {"label": label, "confidence": confidence, "verdict": "completed" if label == "complete" else "check_instructions"}

    # pose_to_points — в режиме pose: угол в локте по сглаженной руке и псевдоточки кисти для общей логики покоя
    def pose_to_points(self, t: float, arm: np.ndarray | None, vis: float) -> np.ndarray | None:
        self.raw_arm, self.arm_vis = arm, vis
        if arm is None or vis < MIN_VIS:
            self.arm_filter.reset()
            self.arm = None
            self.pose_angles.append(np.nan)
            return None
        self.arm = self.arm_filter(t, arm)
        self.pose_angles.append(joint_angle(self.arm))
        wrist, elbow = self.arm[2], self.arm[1]
        p = np.repeat(wrist[None, :], 21, axis=0)
        p[MIDDLE_MCP] = wrist + (wrist - elbow) / K_FOREARM
        return p

    # is_outlier — выброс: запястье прыгнуло дальше, чем рука успевает за это время, или размер кисти резко изменился
    def is_outlier(self, t: float, p: np.ndarray) -> bool:
        hand_len = float(np.linalg.norm(p[MIDDLE_MCP] - p[WRIST]))
        if self.last_good is None or t - self.last_good[0] > 0.5:
            return False
        pt, wrist, prev_len = self.last_good
        steps = max(1.0, (t - pt) * SAMPLE_FPS)
        jump = float(np.linalg.norm(p[WRIST] - wrist))
        return jump > MAX_JUMP_HAND_LENS * prev_len * steps or abs(hand_len - prev_len) > MAX_SIZE_CHANGE * prev_len

    # update — один кадр: точки кисти или None, возвращает список ключей подсказок; выброс считается пропуском
    def update(self, t: float, p: np.ndarray | None) -> list[str]:
        out: list[str] = []
        if p is not None and self.mode != "pose" and self.is_outlier(t, p):
            p = None
        elif p is not None and self.mode != "pose":
            hand_len = float(np.linalg.norm(p[MIDDLE_MCP] - p[WRIST]))
            recent = self.last_good is not None and t - self.last_good[0] <= 0.5
            self.last_good = (t, p[WRIST].copy(), 0.8 * self.last_good[2] + 0.2 * hand_len if recent else hand_len)
        self.unstable = p is None
        if self.mode != "pose":
            self.pose_angles.append(np.nan)
        if p is None:
            self.points.append(np.full((21, 2), np.nan))
            self.smoothed.append(np.full((21, 2), np.nan))
            self.times.append(t)
            if self.state == "wait":
                self.cue("show_arm" if self.mode == "pose" else "show_hand", t, out)
            elif self.last_seen is not None and t - self.last_seen >= LOST_S:
                self.cue("lost", t, out)
            self.angle = None
            return out
        self.points.append(p)
        self.smoothed.append(self.filter(t, p))
        self.times.append(t)
        self.last_seen = t
        recent = np.array(self.smoothed[-int(SAMPLE_FPS * STILL_S):])[:, WRIST]
        hand_len = np.linalg.norm(p[MIDDLE_MCP] - p[WRIST])
        moving = bool(np.isnan(recent).any()) or np.ptp(recent, axis=0).max() > 0.15 * hand_len

        if self.state == "return":
            series = self.rep_angles()
            if series is not None and np.nanmean(series[-3:]) - np.nanmedian(series[: max(self.start_n, 5)]) > 25:
                self.still_since = None
                return out
        if self.state in ("wait", "return"):
            first = self.from_start and self.state == "wait"
            if first or (not moving and len(self.points) >= SAMPLE_FPS * STILL_S):
                self.reset_rep()
                self.state = "extend"
                self.cue("start", t, out, force=True)
            return out

        series = self.rep_angles()
        if series is None or np.isnan(series[-1]):
            return out
        self.angle = float(series[-1])
        self.ext = self.angle - float(np.nanmedian(series[: max(self.start_n, 5)]))
        back = series[-1 - SPEED_WINDOW] if len(series) > SPEED_WINDOW else np.nan
        speed = 0.0 if np.isnan(back) else (series[-1] - back) * SAMPLE_FPS / SPEED_WINDOW
        self.peak_ext = max(self.peak_ext, self.ext)

        if self.state == "extend":
            if speed > FAST_SPEED:
                self.cue("slower", t, out)
            if self.ext >= TARGET_EXT:
                self.state = "hold"
                self.hold_since = t
                self.cue("hold", t, out, force=True)
            elif self.peak_ext > 15 and t - self.times[self.rep_from] > 2.0 and self.ext < self.peak_ext * 0.4:
                self.finish(t, out)
            else:
                window = series[-int(SAMPLE_FPS * STALL_S):]
                if self.ext > 10 and len(window) >= SAMPLE_FPS * STALL_S and np.nanmax(window) - np.nanmin(window) < STALL_DEG:
                    self.cue("more", t, out)
        elif self.state == "hold":
            if self.ext < self.peak_ext - 15:
                self.hold_since = t
            if t - self.hold_since >= HOLD_S:
                self.finish(t, out)
        return out

    # finish — вердикт модели и просьба вернуться
    def finish(self, t: float, out: list[str]) -> None:
        self.result = self.verdict()
        out.append(self.result["verdict"])
        out.append("back")
        self.state = "return"
        self.still_since = None


# Voice — озвучка через macOS say, новая фраза не перебивает текущую, а ждёт в очереди из одной
class Voice:
    # __init__ — голос языка, выключение флагом
    def __init__(self, lang: str, enabled: bool):
        self.voice, self.enabled, self.proc, self.queue = VOICES[lang], enabled, None, []

    # say — добавляет фразы в очередь
    def say(self, texts: list[str]) -> None:
        if self.enabled:
            self.queue = (self.queue + texts)[-2:]
        self.tick()

    # tick — запускает следующую фразу, когда предыдущая закончилась
    def tick(self) -> None:
        if self.queue and (self.proc is None or self.proc.poll() is not None):
            self.proc = subprocess.Popen(["say", "-v", self.voice, "-r", "170", self.queue.pop(0)])


# draw — кадр с линией предплечья, углом и последней подсказкой
def draw(frame: np.ndarray, coach: Coach, p: np.ndarray | None, message: str, font: ImageFont.FreeTypeFont, mirror: bool) -> np.ndarray:
    h, w = frame.shape[:2]
    fx = (lambda x: w - x) if mirror else (lambda x: x)
    if mirror:
        frame = cv2.flip(frame, 1)
    if p is not None:
        for q in p:
            cv2.circle(frame, (int(fx(q[0])), int(q[1])), 3, (80, 220, 80), -1)
        if coach.elbow is not None and coach.state in ("extend", "hold"):
            cv2.line(frame, (int(fx(coach.elbow[0])), int(coach.elbow[1])), (int(fx(p[WRIST, 0])), int(p[WRIST, 1])), (80, 220, 80), 3)
    if coach.mode == "pose" and coach.raw_arm is not None:
        arm = coach.arm if coach.arm is not None else coach.raw_arm
        ok = coach.arm_vis >= MIN_VIS
        color = (80, 220, 80) if ok else (60, 60, 230)
        pts = [(int(fx(q[0])), int(q[1])) for q in arm]
        cv2.line(frame, pts[0], pts[1], color, 4)
        cv2.line(frame, pts[1], pts[2], color, 4)
        cv2.circle(frame, pts[1], 14, color, -1)
        cv2.circle(frame, pts[1], 14, (255, 255, 255), 2)
    img = Image.fromarray(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB))
    d = ImageDraw.Draw(img)
    d.rectangle([0, h - 90, w, h], fill=(0, 0, 0))
    d.text((20, h - 75), message, font=font, fill=(255, 255, 255))
    info = f"{coach.mode}  {coach.state}  " + (f"угол {coach.angle:.0f}°  " if coach.angle is not None else "") + (f"+{coach.ext:.0f}° / цель +{TARGET_EXT:.0f}°" if coach.state in ("extend", "hold") else "") + f"  повторов: {coach.reps}"
    d.rectangle([0, 0, w, 44], fill=(0, 0, 0))
    d.text((20, 8), info, font=font.font_variant(size=26), fill=(200, 200, 200))
    return cv2.cvtColor(np.array(img), cv2.COLOR_RGB2BGR)


# frames — кадры камеры или файла с отметкой времени, прореженные до SAMPLE_FPS
def frames(source: str | int, realtime: bool):
    cap = cv2.VideoCapture(source)
    if not cap.isOpened():
        raise SystemExit(f"Не открывается источник: {source}")
    file_fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
    t0, n, next_t, last_ok = time.monotonic(), 0, 0.0, time.monotonic()
    while True:
        ok, frame = cap.read()
        if not ok:
            if isinstance(source, int) and time.monotonic() - last_ok < 5.0:
                time.sleep(0.05)
                continue
            break
        last_ok = time.monotonic()
        t = (time.monotonic() - t0) if isinstance(source, int) else n / file_fps
        n += 1
        if t + 1e-6 < next_t:
            continue
        next_t = t + 1.0 / SAMPLE_FPS
        if realtime and not isinstance(source, int):
            time.sleep(max(0.0, t - (time.monotonic() - t0)))
        yield t, frame
    cap.release()


# main — живая подсказка с камеры или проверка на видеофайле
def main() -> None:
    ap = argparse.ArgumentParser(description="Живая подсказка E02 локально")
    ap.add_argument("--video", help="видеофайл вместо камеры")
    ap.add_argument("--camera", type=int, default=0)
    ap.add_argument("--lang", choices=["ru", "kk"], default="ru")
    ap.add_argument("--no-voice", action="store_true")
    ap.add_argument("--no-window", action="store_true", help="без окна: только вывод подсказок в консоль")
    ap.add_argument("--from-start", action="store_true", help="повтор с первого кадра с кистью, как записаны видео датасета")
    ap.add_argument("--elbow", choices=["arc", "pose"], default="arc", help="arc — локоть по дуге кулака (рука на столе), pose — настоящий локоть из MediaPipe Pose (без стола)")
    args = ap.parse_args()

    texts = TEXTS[args.lang]
    coach = Coach(load_bundle(str(E02_MODEL)), from_start=args.from_start, mode=args.elbow)
    voice = Voice(args.lang, not args.no_voice)
    font = ImageFont.truetype(FONT, 40)
    message = texts["show_arm" if args.elbow == "pose" else "show_hand"]
    if args.elbow == "pose":
        options = vision.PoseLandmarkerOptions(
            base_options=mp_python.BaseOptions(model_asset_path=str(POSE_MODEL)),
            running_mode=vision.RunningMode.VIDEO, num_poses=1,
            min_pose_detection_confidence=0.5, min_pose_presence_confidence=0.5, min_tracking_confidence=0.5,
        )
        create = vision.PoseLandmarker.create_from_options
    else:
        options = vision.HandLandmarkerOptions(
            base_options=mp_python.BaseOptions(model_asset_path=str(HAND_MODEL)),
            running_mode=vision.RunningMode.VIDEO, num_hands=1,
            min_hand_detection_confidence=0.3, min_hand_presence_confidence=0.3, min_tracking_confidence=0.3,
        )
        create = vision.HandLandmarker.create_from_options
    source = args.video if args.video else args.camera
    with create(options) as landmarker:
        for t, frame in frames(source, realtime=not args.no_window):
            h, w = frame.shape[:2]
            rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            res = landmarker.detect_for_video(mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb), int(t * 1000))
            if args.elbow == "pose":
                arm, vis = arm_from_pose(res.pose_landmarks[0], w, h) if res.pose_landmarks else (None, 0.0)
                p = coach.pose_to_points(t, arm, vis)
            else:
                p = np.array([(q.x * w, q.y * h) for q in res.hand_landmarks[0]]) if res.hand_landmarks else None
            cues = coach.update(t, p)
            for key in cues:
                message = texts[key]
                extra = f"  ({coach.result['label']}, {coach.result['confidence']:.2f}{', pose: вердикт не проверен' if args.elbow == 'pose' else ''})" if key in ("completed", "check_instructions") else ""
                print(f"{t:6.1f}s  {key:18s} {texts[key]}{extra}", flush=True)
            voice.say([texts[k] for k in cues])
            voice.tick()
            if not args.no_window:
                shown = coach.smoothed[-1] if p is not None and args.elbow == "arc" else None
                cv2.imshow("SerIQ live E02", draw(frame, coach, shown, message, font, mirror=args.video is None))
                if cv2.waitKey(1) & 0xFF in (27, ord("q")):
                    break
    cv2.destroyAllWindows()


if __name__ == "__main__":
    main()
