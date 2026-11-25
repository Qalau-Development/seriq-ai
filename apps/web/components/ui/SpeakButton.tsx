"use client";

import { useEffect, useState } from "react";
import { Square, Volume2 } from "lucide-react";
import { useLang } from "@/lib/i18n";
import { useVoiceAvailable } from "@/lib/speech";
import { clipAvailable, useManifest, voice, type VoiceItem } from "@/lib/voice";
import { Button } from "@/components/ui/Button";

// SpeakButton — «Озвучить»: играет записанные клипы по id, а где клипа нет, читает текст голосом браузера; кнопки нет, если нет ни клипов, ни голоса
export function SpeakButton({ items, className = "" }: { items: VoiceItem[]; className?: string }) {
  const { lang, t } = useLang();
  const browserVoice = useVoiceAvailable(lang);
  const manifest = useManifest();
  const key = `${lang}|${items.map((i) => i.id).join(",")}`;
  const [speakingKey, setSpeakingKey] = useState<string | null>(null);
  const speaking = speakingKey === key;

  useEffect(() => () => voice.stop(), [key]);

  if (!browserVoice && !clipAvailable(manifest, items, lang)) return null;
  return (
    <Button
      variant="secondary"
      className={className}
      aria-pressed={speaking}
      onClick={() => {
        if (speaking) {
          voice.stop();
          setSpeakingKey(null);
        } else {
          setSpeakingKey(key);
          voice.playClips(items, lang, () => setSpeakingKey(null));
        }
      }}
    >
      {speaking ? <Square aria-hidden className="size-6" /> : <Volume2 aria-hidden className="size-6" />}
      {speaking ? t.speak_stop : t.speak_start}
    </Button>
  );
}
