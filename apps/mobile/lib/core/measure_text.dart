import '../models/analysis_result.dart';
import 'strings.dart';

// chartKeys — ключи подписи оси и подсказки графика по измеряемому значению
const chartKeys = {
  'elbow_angle': ('chart_y_label', 'chart_tooltip_angle'),
  'wrist_lift': ('chart_y_label_wrist_lift', 'chart_tooltip_wrist_lift'),
  'hand_openness': ('chart_y_label_hand_openness', 'chart_tooltip_hand_openness'),
  'lift_height': ('chart_y_label_lift_height', 'chart_tooltip_lift_height'),
};

// decimal — число с одной цифрой после запятой, разделитель по языку
String decimal(double value) => num(value.toStringAsFixed(1));

// formatSeconds — число с одной цифрой после запятой без лишнего «.0», разделитель по языку
String formatSeconds(double s) {
  final r = (s * 10).round() / 10;
  return num(r == r.roundToDouble() ? '${r.round()}' : '$r');
}

// formatChartValue — значение ряда с единицей для подсказки графика и оси
String formatChartValue(double value, String unit) {
  if (unit == 'deg') return '${value.round()}°';
  if (unit == 'percent') return '${value.round()}%';
  return '${decimal(value)} ${tr('chart_unit_hand_lengths')}';
}

// measureLine — строка с измеренным значением для упражнений кроме E02; null, если значения нет
String? measureLine(Measure measure) {
  final value = measure.value;
  if (value == null) return null;
  switch (measure.name) {
    case 'hand_openness':
      return value > 100
          ? trFill('result_measure_hand_openness_up', {'n': (value - 100).round()})
          : trFill('result_measure_hand_openness_base', {'n': value.round()});
    case 'wrist_lift':
      return trFill('result_measure_wrist_lift', {'n': value.round()});
    case 'lift_height':
      return trFill('result_measure_lift_height', {'n': decimal(value)});
    default:
      return null;
  }
}

// resultTitle — заголовок результата: для E02 как раньше, для остальных «Выполнено» или «Проверьте инструкцию»
String resultTitle(String label, String exercise) {
  if (exercise == 'E02') return tr('result_title_$label');
  return label == 'complete' ? tr('verdict_completed') : tr('verdict_check_instructions');
}

// resultHint — подсказка под заголовком, когда измеренного значения нет
String resultHint(String label, String exercise) =>
    trForExercise('result_hint_$label', exercise, 'result_hint_incomplete');

// resultLines — строки под заголовком результата: первая главная, остальные дополнительные
List<String> resultLines(AnalysisResult result, String label) {
  final measure = result.measure;
  final done = label == 'complete';
  final elbow = measure?.name == 'elbow_angle' || result.exercise == 'E02';
  final max = measure?.name == 'elbow_angle' && measure?.value != null
      ? measure!.value!.round()
      : null;
  final lines = elbow
      ? [
          max == null
              ? resultHint(label, result.exercise)
              : trFill('result_line_$label', {'max': max}),
        ]
      : [
          if (measure != null) measureLine(measure),
          if (!done) resultHint(label, result.exercise),
        ];
  return [
    for (final l in lines)
      if (l != null && l.isNotEmpty) l,
  ];
}
