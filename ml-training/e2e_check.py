import argparse
import json
import re
import sys
import time
import urllib.error
import urllib.request
import uuid
from pathlib import Path

API_URL = "https://seriq-ai.qalau.com/api/v1/analysis"
VIDEO_EXTENSIONS = {".mp4", ".mov", ".webm"}
EXPECTED = {
    "full": {"complete"},
    "half_back": {"incomplete"},
    "full_back": {"uncertain"},
    "bad_frame": {"uncertain", "no_pose_detected"},
    "other_arm": {"complete"},
    "half_hold": None,
}
SCENARIO_PATTERN = re.compile(r"(?:^|_)(half_hold|half_back|full_back|bad_frame|other_arm|full)(?:_|$)")
BUSY_RETRIES = 5


# scenario_of — сценарий по имени файла, например d_full_1 → full, z_half_hold → half_hold
def scenario_of(path: Path) -> str | None:
    match = SCENARIO_PATTERN.search(path.stem.lower())
    return match.group(1) if match else None


# multipart_body — тело multipart/form-data с одним файлом video
def multipart_body(path: Path) -> tuple[bytes, str]:
    boundary = uuid.uuid4().hex
    head = (f'--{boundary}\r\nContent-Disposition: form-data; name="video"; filename="{path.name}"\r\n'
            "Content-Type: application/octet-stream\r\n\r\n").encode()
    return head + path.read_bytes() + f"\r\n--{boundary}--\r\n".encode(), f"multipart/form-data; boundary={boundary}"


# analyze_remote — отправляет видео на API, при 503 busy повторяет через несколько секунд
def analyze_remote(path: Path, url: str) -> dict:
    body, content_type = multipart_body(path)
    for attempt in range(BUSY_RETRIES):
        request = urllib.request.Request(url, data=body, headers={"Content-Type": content_type}, method="POST")
        try:
            with urllib.request.urlopen(request, timeout=300) as response:
                return json.loads(response.read())
        except urllib.error.HTTPError as err:
            data = json.loads(err.read() or b"{}")
            if err.code == 503 and attempt < BUSY_RETRIES - 1:
                time.sleep(5)
                continue
            return data or {"status": "error", "error": {"code": f"http_{err.code}"}}
    return {"status": "error", "error": {"code": "busy"}}


# analyze_local — анализ тем же кодом, что на сервере, но на этом компьютере
def analyze_local(path: Path) -> dict:
    from seriq_engine.errors import EngineError
    from seriq_engine.pipeline import analyze_video

    started = time.perf_counter()
    try:
        result = analyze_video(path)
    except EngineError as err:
        return {"status": "error", "error": {"code": err.api_code}}
    return result | {"status": "ok", "processing_ms": int((time.perf_counter() - started) * 1000)}


# summarize — одна строка таблицы: решение, уверенность и углы из ответа
def summarize(path: Path, response: dict) -> dict:
    scenario = scenario_of(path)
    expected = EXPECTED.get(scenario) if scenario else None
    row = {"file": path.name, "scenario": scenario or "?", "expected": "/".join(sorted(expected)) if expected else "?"}
    if response.get("status") != "ok":
        label = response.get("error", {}).get("code", "error")
        row |= {"label": label, "confidence": None, "warnings": "", "start": None, "max": None, "end": None, "ms": None}
    else:
        cycle = response["cycles"][0]
        values = [v for v in response["angle_series"]["values"] if v is not None]
        label = cycle["label"]
        row |= {
            "label": label,
            "confidence": cycle["confidence"],
            "warnings": ",".join(response["warnings"]),
            "start": values[0] if values else None,
            "max": max(values) if values else None,
            "end": values[-1] if values else None,
            "ms": response.get("processing_ms"),
        }
    row["match"] = "?" if expected is None else ("yes" if label in expected else "NO")
    return row


# print_table — таблица результатов и итог по совпадениям
def print_table(rows: list[dict]) -> None:
    fmt = "{file:<28} {scenario:<10} {expected:<27} {label:<18} {confidence:>5} {warnings:<16} {start:>6} {max:>6} {end:>6} {ms:>7} {match:>5}"
    print(fmt.format(file="file", scenario="scenario", expected="expected", label="label", confidence="conf",
                     warnings="warnings", start="start", max="max", end="end", ms="ms", match="match"))
    for r in rows:
        shown = {k: ("—" if v is None else v) for k, v in r.items()}
        shown["confidence"] = "—" if r["confidence"] is None else f"{r['confidence']:.2f}"
        print(fmt.format(**shown))
    checked = [r for r in rows if r["match"] != "?"]
    print(f"\nmatched {sum(r['match'] == 'yes' for r in checked)} of {len(checked)} with a known expectation; "
          f"{len(rows) - len(checked)} without one (half_hold or unknown scenario)")


# main — проверяет все видео папки на сервере или локально и печатает только числа
def main() -> None:
    parser = argparse.ArgumentParser(description="End-to-end check on own recordings. Prints numbers only; videos are not stored.")
    parser.add_argument("folder", type=Path, help="folder with recordings, outside the repository")
    parser.add_argument("--local", action="store_true", help="run seriq_engine on this computer instead of the server API")
    parser.add_argument("--url", default=API_URL)
    args = parser.parse_args()

    videos = sorted(p for p in args.folder.iterdir() if p.suffix.lower() in VIDEO_EXTENSIONS)
    if not videos:
        sys.exit(f"No .mp4/.mov/.webm files in {args.folder}")
    rows = []
    for path in videos:
        response = analyze_local(path) if args.local else analyze_remote(path, args.url)
        rows.append(summarize(path, response))
    print_table(rows)


if __name__ == "__main__":
    main()
