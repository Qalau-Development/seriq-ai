const STSD = [0x73, 0x74, 0x73, 0x64];
const HEV1 = [0x68, 0x65, 0x76, 0x31];
const HVC1 = [0x68, 0x76, 0x63, 0x31];
const SEARCH_AFTER_STSD = 64;

// indexOfBytes — позиция последовательности байтов в массиве, начиная с from; -1, если нет
function indexOfBytes(bytes: Uint8Array, pattern: number[], from: number, to = bytes.length): number {
  const end = Math.min(to, bytes.length) - pattern.length;
  for (let i = Math.max(0, from); i <= end; i++) {
    let ok = true;
    for (let k = 0; k < pattern.length; k++) {
      if (bytes[i + k] !== pattern[k]) {
        ok = false;
        break;
      }
    }
    if (ok) return i;
  }
  return -1;
}

// patchHev1 — меняет метку HEVC hev1 на hvc1 в описании дорожек (stsd), как ffmpeg -c copy -tag:v hvc1; true, если что-то поменяли
export function patchHev1(bytes: Uint8Array): boolean {
  let changed = false;
  let from = 0;
  for (;;) {
    const stsd = indexOfBytes(bytes, STSD, from);
    if (stsd < 0) return changed;
    const tag = indexOfBytes(bytes, HEV1, stsd + 4, stsd + 4 + SEARCH_AFTER_STSD);
    if (tag >= 0) {
      bytes.set(HVC1, tag);
      changed = true;
    }
    from = stsd + 4;
  }
}

// toPlayableVideo — копия видео для показа на экране: Safari не показывает HEVC с меткой hev1 (чёрный экран), на анализ уходит исходный файл
export async function toPlayableVideo(file: File): Promise<Blob> {
  const isMp4 = /\.(mp4|mov|m4v)$/i.test(file.name) || /mp4|quicktime/.test(file.type);
  if (!isMp4) return file;
  try {
    const bytes = new Uint8Array(await file.arrayBuffer());
    return patchHev1(bytes) ? new Blob([bytes], { type: file.type || "video/mp4" }) : file;
  } catch {
    return file;
  }
}
