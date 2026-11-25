# tts_server — сервер синтеза речи для озвучки сайта: русский Silero, казахский ISSAI KazakhTTS, числа словами, кэш на диске
import hashlib, json, os, re, subprocess, sys, threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

import numpy as np
import torch

HERE = os.path.dirname(os.path.abspath(__file__))
MODELS = os.environ.get("SERIQ_TTS_MODELS", os.path.join(HERE, "models"))
CACHE = os.environ.get("SERIQ_TTS_CACHE", os.path.join(HERE, "cache"))
TEXTS = os.path.join(HERE, "texts.json")
PORT = int(os.environ.get("SERIQ_TTS_PORT", "8100"))
MAX_TEXT = 2000
PAUSE_S = 0.3
torch.set_num_threads(8)
DEVICE = "cuda" if torch.cuda.is_available() else "cpu"

RU_UNITS = ["ноль", "один", "два", "три", "четыре", "пять", "шесть", "семь", "восемь", "девять"]
RU_UNITS_F = ["ноль", "одна", "две"] + RU_UNITS[3:]
RU_TEENS = ["десять", "одиннадцать", "двенадцать", "тринадцать", "четырнадцать", "пятнадцать", "шестнадцать", "семнадцать", "восемнадцать", "девятнадцать"]
RU_TENS = ["", "", "двадцать", "тридцать", "сорок", "пятьдесят", "шестьдесят", "семьдесят", "восемьдесят", "девяносто"]
RU_HUND = ["", "сто", "двести", "триста", "четыреста", "пятьсот", "шестьсот", "семьсот", "восемьсот", "девятьсот"]
RU_UNITS_G = ["ноля", "одного", "двух", "трёх", "четырёх", "пяти", "шести", "семи", "восьми", "девяти"]
RU_TEENS_G = ["десяти", "одиннадцати", "двенадцати", "тринадцати", "четырнадцати", "пятнадцати", "шестнадцати", "семнадцати", "восемнадцати", "девятнадцати"]
RU_TENS_G = ["", "", "двадцати", "тридцати", "сорока", "пятидесяти", "шестидесяти", "семидесяти", "восьмидесяти", "девяноста"]
RU_HUND_G = ["", "ста", "двухсот", "трёхсот", "четырёхсот", "пятисот", "шестисот", "семисот", "восьмисот", "девятисот"]
RU_GEN_PREP = {"до", "из", "от", "с", "около", "более", "менее"}
RU_NOUNS = {"°": ("градус", "градуса", "градусов"), "%": ("процент", "процента", "процентов")}

KK_UNITS = ["нөл", "бір", "екі", "үш", "төрт", "бес", "алты", "жеті", "сегіз", "тоғыз"]
KK_TENS = ["", "он", "жиырма", "отыз", "қырық", "елу", "алпыс", "жетпіс", "сексен", "тоқсан"]
KK_NOUN = {"°": "градус", "%": "пайыз"}
KK_SUFFIX = {
    "°": {"dat": "қа", "gen": "тың", "poss": "ы", "abl": "тан", "loc": "та"},
    "%": {"dat": "ға", "gen": "дың", "poss": "ы", "abl": "дан", "loc": "да"},
}
KK_SUFFIX_KIND = {
    **dict.fromkeys(["ға", "ге", "қа", "ке", "на", "не", "а", "е"], "dat"),
    **dict.fromkeys(["ның", "нің", "дың", "дің", "тың", "тің"], "gen"),
    **dict.fromkeys(["ы", "і", "сы", "сі"], "poss"),
    **dict.fromkeys(["нан", "нен", "дан", "ден", "тан", "тен"], "abl"),
    **dict.fromkeys(["да", "де", "та", "те", "нда", "нде"], "loc"),
}


# ru_int — целое 0–999 словами в именительном или родительном падеже
def ru_int(n, gen=False, fem=False):
    if n == 0:
        return RU_UNITS_G[0] if gen else "ноль"
    units = RU_UNITS_G if gen else (RU_UNITS_F if fem else RU_UNITS)
    teens, tens, hund = (RU_TEENS_G, RU_TENS_G, RU_HUND_G) if gen else (RU_TEENS, RU_TENS, RU_HUND)
    words = [hund[n // 100]] if n >= 100 else []
    rest = n % 100
    if 10 <= rest < 20:
        words.append(teens[rest - 10])
    else:
        if rest >= 20:
            words.append(tens[rest // 10])
        if rest % 10:
            words.append(units[rest % 10])
    return " ".join(w for w in words if w)


# ru_noun — форма существительного после числа: 1 градус, 2 градуса, 5 градусов
def ru_noun(n, forms, gen=False):
    if n % 100 in range(11, 15):
        return forms[2]
    last = n % 10
    if gen:
        return forms[1] if last == 1 else forms[2]
    return forms[0] if last == 1 else forms[1] if last in (2, 3, 4) else forms[2]


# ru_number — число из текста словами с учётом предлога перед ним и единицы после
def ru_number(m, text):
    before = text[: m.start()].split()
    prep = before[-1].lower().strip("(«") if before else ""
    gen = prep in RU_GEN_PREP
    acc = prep == "на"
    whole, frac, unit = m.group(1), m.group(2), m.group(3) or ""
    n = int(whole)
    if frac is not None:
        f = int(frac[:1])
        one = n % 10 == 1 and n % 100 != 11
        w = ru_int(n, gen, fem=True)
        if acc and one:
            w = w[: -len("одна")] + "одну целую"
        else:
            w += " целой" if gen and one else " целая" if one else " целых"
        fw = ru_int(f, gen, fem=True)
        if acc and f == 1:
            fw = "одну десятую"
        else:
            fw += " десятой" if gen and f == 1 else " десятая" if f == 1 else " десятых"
        w += " " + fw
        return w + (" " + RU_NOUNS[unit][1] if unit else "")
    w = ru_int(n, gen)
    return w + (" " + ru_noun(n, RU_NOUNS[unit], gen) if unit else "")


# kk_int — целое 0–999 словами по-казахски
def kk_int(n):
    if n == 0:
        return "нөл"
    words = []
    if n >= 100:
        words += ([KK_UNITS[n // 100]] if n // 100 > 1 else []) + ["жүз"]
    if n % 100 >= 10:
        words.append(KK_TENS[(n % 100) // 10])
    if n % 10:
        words.append(KK_UNITS[n % 10])
    return " ".join(words)


# kk_number — число из текста словами; суффикс после единицы согласуется со словом «градус» или «пайыз»
def kk_number(m):
    whole, frac, unit, suffix = m.group(1), m.group(2), m.group(3) or "", m.group(4) or ""
    w = kk_int(int(whole))
    if frac is not None:
        w += " бүтін оннан " + kk_int(int(frac[:1]))
    if unit:
        noun = KK_NOUN[unit]
        kind = KK_SUFFIX_KIND.get(suffix)
        w += " " + noun + (KK_SUFFIX[unit][kind] if kind else suffix)
    return w + ("" if unit or not suffix else suffix)


NUM_RE_RU = re.compile(r"(\d+)(?:[.,](\d+))?(?:\s?(°|%))?")
NUM_RE_KK = re.compile(r"(\d+)(?:[.,](\d+))?(?:\s?(°|%))?(?:-([а-яәғқңөұүһі]+))?")


# normalize — текст для голоса: диапазоны и числа словами, тире и скобки как паузы
def normalize(lang, text):
    t = text.replace("«", "").replace("»", "")
    if lang == "ru":
        t = t.replace("1–2 секунды", "одну-две секунды")
        t = _sub_ru(t)
    else:
        t = t.replace("1–2 секунд", "бір-екі секунд")
        t = NUM_RE_KK.sub(kk_number, t)
    t = re.sub(r"\s*[—–]\s*", ", ", t)
    t = re.sub(r"\s*\(\s*", ", ", t).replace(")", "")
    return re.sub(r"\s+", " ", t).strip()


# _sub_ru — замена чисел по одному, чтобы предлог брался из исходного текста
def _sub_ru(t):
    out, pos = [], 0
    for m in NUM_RE_RU.finditer(t):
        out.append(t[pos : m.start()])
        out.append(ru_number(m, t))
        pos = m.end()
    out.append(t[pos:])
    return "".join(out)


# sentences — делит текст на предложения, чтобы модели не теряли длинный текст
def sentences(text):
    parts = re.split(r"(?<=[.!?:;])\s+", text)
    return [p.strip() for p in parts if re.search(r"\w", p)]


class Voices:
    # __init__ — загружает Silero для русского и ISSAI KazakhTTS для казахского
    def __init__(self):
        self.lock = threading.Lock()
        self.ru = torch.package.PackageImporter(f"{MODELS}/v5_ru.pt").load_pickle("tts_models", "model")
        self.ru.to(DEVICE)
        from espnet2.bin.tts_inference import Text2Speech
        from parallel_wavegan.utils import load_model
        self.voc = load_model(f"{MODELS}/parallelwavegan_female1_checkpoint/checkpoint-400000steps.pkl").to(DEVICE).eval()
        self.voc.remove_weight_norm()
        base = f"{MODELS}/kaztts_female1_tacotron2_train.loss.ave"
        cwd = os.getcwd()
        os.chdir(base)
        self.kk = Text2Speech("exp/tts_train_raw_char/config.yaml", "exp/tts_train_raw_char/train.loss.ave_5best.pth",
                              device=DEVICE, threshold=0.5, minlenratio=0.0, maxlenratio=10.0,
                              use_att_constraint=True, backward_window=1, forward_window=3)
        os.chdir(cwd)
        self.kk.spc2wav = None
        self.rate = {"ru": 48000, "kk": 22050}

    # sentence_wav — звук одного предложения, из кэша или заново
    def sentence_wav(self, lang, s):
        path = f"{CACHE}/sent/{lang}/{hashlib.sha1(s.encode()).hexdigest()}.npy"
        if os.path.exists(path):
            return np.load(path)
        with self.lock, torch.no_grad():
            if lang == "ru":
                wav = self.ru.apply_tts(text=s, speaker="xenia", sample_rate=48000).cpu().numpy()
            else:
                wav = self.voc.inference(self.kk(s.lower())["feat_gen"]).view(-1).cpu().numpy()
        os.makedirs(os.path.dirname(path), exist_ok=True)
        np.save(path, wav.astype(np.float32))
        return wav

    # mp3 — готовый mp3 всего текста с паузами между предложениями
    def mp3(self, lang, text):
        norm = normalize(lang, text)
        path = f"{CACHE}/mp3/{lang}/{hashlib.sha1(norm.encode()).hexdigest()}.mp3"
        if not os.path.exists(path):
            rate = self.rate[lang]
            gap = np.zeros(int(rate * PAUSE_S), dtype=np.float32)
            chunks = []
            for s in sentences(norm):
                chunks += [self.sentence_wav(lang, s), gap]
            pcm = (np.clip(np.concatenate(chunks or [gap]), -1, 1) * 32767).astype(np.int16).tobytes()
            os.makedirs(os.path.dirname(path), exist_ok=True)
            subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-f", "s16le", "-ar", str(rate), "-ac", "1", "-i", "-",
                            "-b:a", "64k", path], input=pcm, check=True)
        with open(path, "rb") as f:
            return f.read()


# warm_up — заранее озвучивает готовые фразы сайта, чтобы они звучали сразу
def warm_up(voices):
    if not os.path.exists(TEXTS):
        print("warm-up skipped: no texts.json", flush=True)
        return
    texts = json.load(open(TEXTS))
    for lang, items in texts.items():
        for v in items.values():
            for s in sentences(normalize(lang, v)):
                voices.sentence_wav(lang, s)
    print("warm-up done", flush=True)


class Handler(BaseHTTPRequestHandler):
    # do_GET — GET /tts?lang=ru|kk&text=... отдаёт mp3
    def do_GET(self):
        url = urlparse(self.path)
        q = parse_qs(url.query)
        lang, text = q.get("lang", [""])[0], q.get("text", [""])[0]
        if url.path != "/tts" or lang not in ("ru", "kk") or not text or len(text) > MAX_TEXT:
            self.send_error(400)
            return
        try:
            body = VOICES.mp3(lang, text)
        except Exception as e:
            print("error:", e, flush=True)
            self.send_error(500)
            return
        self.send_response(200)
        self.send_header("Content-Type", "audio/mpeg")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "public, max-age=86400")
        self.end_headers()
        self.wfile.write(body)

    # log_message — без журнала запросов: в адресе текст фразы
    def log_message(self, *args):
        pass


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--normalize":
        for lang, s in (a.split(":", 1) for a in sys.argv[2:]):
            print(lang, "→", normalize(lang, s))
        sys.exit(0)
    VOICES = Voices()
    threading.Thread(target=warm_up, args=(VOICES,), daemon=True).start()
    print(f"tts server on 127.0.0.1:{PORT}, device {DEVICE}", flush=True)
    ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
