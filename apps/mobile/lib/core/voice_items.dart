import '../models/analysis_result.dart';
import 'exercises.dart';
import 'measure_text.dart';
import 'strings.dart';

// VoiceItem — фрагмент озвучки: id клипа в манифесте (как lib/voice.ts на сайте) и текст для запасного голоса
class VoiceItem {
  final String id;
  final String text;

  const VoiceItem(this.id, this.text);

  @override
  bool operator ==(Object other) =>
      other is VoiceItem && other.id == id && other.text == text;

  @override
  int get hashCode => Object.hash(id, text);

  @override
  String toString() => 'VoiceItem($id, $text)';
}

// clampInt — целое число, прижатое к краям диапазона (как clampInt в lib/voice.ts)
int clampInt(num n, int min, int max) {
  final r = n.round();
  return r < min ? min : (r > max ? max : r);
}

// instructionItems — инструкция по порядку: название упражнения, шаги, «Как снимать», советы; id клипа = ключ словаря
List<VoiceItem> instructionItems(ExerciseDef def) => [
  VoiceItem(def.titleKey, tr(def.titleKey)),
  for (final k in def.stepKeys) VoiceItem(k, tr(k)),
  VoiceItem('tips_title', tr('tips_title')),
  for (final k in def.tipKeys) VoiceItem(k, tr(k)),
];

// measureVoicePart — строка с измеренным значением для упражнений кроме E02 и id её клипа («ключ__значение», число прижато к диапазону озвучки); null, если значения нет
VoiceItem? measureVoicePart(Measure measure) {
  final value = measure.value;
  if (value == null) return null;
  switch (measure.name) {
    case 'hand_openness':
      final up = value > 100;
      final key = up
          ? 'result_measure_hand_openness_up'
          : 'result_measure_hand_openness_base';
      final n = (up ? value - 100 : value).round();
      final clamped = up ? clampInt(n, 1, 200) : clampInt(n, 0, 100);
      return VoiceItem('${key}__$clamped', trFill(key, {'n': n}));
    case 'wrist_lift':
      return VoiceItem(
        'result_measure_wrist_lift__${clampInt(value, 0, 180)}',
        trFill('result_measure_wrist_lift', {'n': value.round()}),
      );
    case 'lift_height':
      final tenths = value.clamp(0.0, 9.9).toStringAsFixed(1);
      return VoiceItem(
        'result_measure_lift_height__$tenths',
        trFill('result_measure_lift_height', {'n': decimal(value)}),
      );
    default:
      return null;
  }
}

// _hintItem — фрагмент подсказки под заголовком результата; id — ключ текста (с суффиксом _other у упражнений кроме E02, если он есть)
VoiceItem _hintItem(String label, String exercise) {
  final key = 'result_hint_$label';
  final other = '${key}_other';
  final id = exercise != 'E02' && Strings.ru.containsKey(other)
      ? other
      : (Strings.ru.containsKey(key) ? key : 'result_hint_incomplete');
  return VoiceItem(id, tr(id));
}

// ResultVoiceParts — заголовок и строки результата с id клипов озвучки; те же тексты показываются на экране
typedef ResultVoiceParts = ({VoiceItem title, List<VoiceItem> lines});

// resultVoiceParts — заголовок и строки результата с id клипов озвучки (как resultParts в lib/resultText.ts)
ResultVoiceParts resultVoiceParts(AnalysisResult result, String label) {
  final exercise = result.exercise;
  final measure = result.measure;
  final titleId = exercise == 'E02'
      ? 'result_title_$label'
      : (label == 'complete' ? 'verdict_completed' : 'verdict_check_instructions');
  final title = VoiceItem(titleId, tr(titleId));

  final elbow = measure?.name == 'elbow_angle' || exercise == 'E02';
  if (elbow) {
    final max = measure?.name == 'elbow_angle' && measure?.value != null
        ? measure!.value!.round()
        : null;
    if (max == null) {
      final hint = _hintItem(label, exercise);
      return (title: title, lines: hint.text.isEmpty ? [] : [hint]);
    }
    final key = 'result_line_$label';
    return (
      title: title,
      lines: [
        VoiceItem('${key}__${clampInt(max, 0, 180)}', trFill(key, {'max': max})),
      ],
    );
  }
  final line = measure != null ? measureVoicePart(measure) : null;
  final hint = label == 'complete' ? null : _hintItem(label, exercise);
  return (title: title, lines: [?line, ?hint]);
}
