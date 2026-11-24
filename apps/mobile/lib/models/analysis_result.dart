// CycleResult — результат одного цикла упражнения
class CycleResult {
  final int index;
  final double startS;
  final double endS;
  final String label;
  final double confidence;
  final String verdict;

  CycleResult.fromJson(Map<String, dynamic> j)
      : index = j['index'] as int,
        startS = (j['start_s'] as num).toDouble(),
        endS = (j['end_s'] as num).toDouble(),
        label = j['label'] as String,
        confidence = (j['confidence'] as num).toDouble(),
        verdict = j['verdict'] as String;
}

// AngleSeries — угол локтя по времени для графика
class AngleSeries {
  final double fps;
  final List<double?> values;

  AngleSeries.fromJson(Map<String, dynamic> j)
      : fps = (j['fps'] as num).toDouble(),
        values = (j['values'] as List)
            .map((v) => v == null ? null : (v as num).toDouble())
            .toList();
}

// AnalysisResult — полный ответ POST /analysis
class AnalysisResult {
  final String analysisId;
  final String source;
  final String modelVersion;
  final String verdict;
  final List<CycleResult> cycles;
  final AngleSeries angleSeries;
  final List<String> warnings;
  final int processingMs;

  AnalysisResult.fromJson(Map<String, dynamic> j)
      : analysisId = j['analysis_id'] as String,
        source = j['source'] as String,
        modelVersion = j['model_version'] as String,
        verdict = j['verdict'] as String,
        cycles = (j['cycles'] as List)
            .map((c) => CycleResult.fromJson(c as Map<String, dynamic>))
            .toList(),
        angleSeries =
            AngleSeries.fromJson(j['angle_series'] as Map<String, dynamic>),
        warnings = List<String>.from(j['warnings'] as List),
        processingMs = j['processing_ms'] as int;

  bool get isMock => source == 'mock';

  // mainCycle — цикл, по которому показываем результат (в MVP он один)
  CycleResult? get mainCycle => cycles.isEmpty ? null : cycles.first;
}
