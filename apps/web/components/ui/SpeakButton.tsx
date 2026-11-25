"use client";

import { useEffect, useState } from "react";
import { Square, Volume2 } from "lucide-react";
import { useLang } from "@/lib/i18n";
import { speakNatural, stopSpeaking, useVoiceAvailable } from "@/lib/speech";
import { Button } from "@/components/ui/Button";

// SpeakButton — «Озвучить»: читает вслух ровно тот текст, что на экране; ru и kk своим голосом
export function SpeakButton({ text, className = "" }: { text: string; className?: string }) {
  const { lang, t } = useLang();
  const available = useVoiceAvailable(lang);
  const key = `${lang}|${text}`;
  const [speakingKey, setSpeakingKey] = useState<string | null>(null);
  const speaking = speakingKey === key;

  useEffect(() => () => stopSpeaking(), [key]);

  if (!available) return null;
  return (
    <Button
      variant="secondary"
      className={className}
      aria-pressed={speaking}
      onClick={() => {
        if (speaking) {
          stopSpeaking();
          setSpeakingKey(null);
        } else {
          setSpeakingKey(key);
          speakNatural(text, lang, () => setSpeakingKey(null));
        }
      }}
          >
      {speaking ? <Square aria-hidden className="size-6" /> : <Volume2 aria-hidden className="size-6" />}
      {speaking ? t.speak_stop : t.speak_start}
    </Button>
  );
}
