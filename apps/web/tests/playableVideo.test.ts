import { describe, expect, it } from "vitest";
import { patchHev1, toPlayableVideo } from "@/lib/playableVideo";

// box — кусок MP4: размер, тип и содержимое
const ascii = (s: string) => Array.from(s, (c) => c.charCodeAt(0));
const sampleEntry = (codec: string) => new Uint8Array([0, 0, 0, 0x20, ...ascii("stsd"), 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0x10, ...ascii(codec), ...ascii("hvcC"), 1, 2, 3, 4]);
const text = (b: Uint8Array) => String.fromCharCode(...b);

describe("playableVideo", () => {
  it("patchHev1 меняет hev1 на hvc1 после stsd и не трогает остальное", () => {
    const bytes = sampleEntry("hev1");
    expect(patchHev1(bytes)).toBe(true);
    expect(text(bytes)).toContain("hvc1");
    expect(text(bytes)).not.toContain("hev1");
    expect(text(bytes)).toContain("hvcC");
  });

  it("patchHev1 не меняет hvc1, H.264 и hev1 вне описания дорожек", () => {
    expect(patchHev1(sampleEntry("hvc1"))).toBe(false);
    expect(patchHev1(sampleEntry("avc1"))).toBe(false);
    const stray = new Uint8Array([...ascii("hev1"), ...new Array(100).fill(0)]);
    expect(patchHev1(stray)).toBe(false);
  });

  it("toPlayableVideo отдаёт новый файл только для MP4 с hev1", async () => {
    const hev = new File([sampleEntry("hev1")], "a.mp4", { type: "video/mp4" });
    const patched = await toPlayableVideo(hev);
    expect(patched).not.toBe(hev);
    expect(text(new Uint8Array(await patched.arrayBuffer()))).toContain("hvc1");
    const webm = new File([sampleEntry("hev1")], "a.webm", { type: "video/webm" });
    expect(await toPlayableVideo(webm)).toBe(webm);
    const avc = new File([sampleEntry("avc1")], "b.mp4", { type: "video/mp4" });
    expect(await toPlayableVideo(avc)).toBe(avc);
  });
});
