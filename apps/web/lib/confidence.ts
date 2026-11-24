export type ConfidenceLevel = "high" | "medium" | "low";

// confidenceLevel — переводит уверенность 0–1 в слово: от 0,8 высокая, от 0,6 средняя, ниже низкая
export function confidenceLevel(confidence: number): ConfidenceLevel {
  if (confidence >= 0.8) return "high";
  if (confidence >= 0.6) return "medium";
  return "low";
}
