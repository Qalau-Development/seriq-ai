import '../core/exercises.dart';
import 'analysis_result.dart';

// isoUtc — время в формате 2026-11-24T15:02:11Z
String isoUtc(DateTime t) =>
    '${t.toUtc().toIso8601String().split('.').first.replaceAll('Z', '')}Z';

// Attempt — одна попытка (одно повторение) внутри занятия
class Attempt {
  final String analysisId;
  final DateTime at;
  final String verdict;
  final String label;
  final double confidence;
  final String source;
  final String? modelVersion;
  final Measure? measure;

  Attempt({
    required this.analysisId,
    required this.at,
    required this.verdict,
    required this.label,
    required this.confidence,
    required this.source,
    this.modelVersion,
    this.measure,
  });

  // fromResult — попытка из ответа API
  factory Attempt.fromResult(AnalysisResult r, DateTime at) {
    final cycle = r.mainCycle;
    return Attempt(
      analysisId: r.analysisId,
      at: at,
      verdict: r.verdict,
      label: cycle?.label ?? 'uncertain',
      confidence: cycle?.confidence ?? 0,
      source: r.source,
      modelVersion: r.modelVersion,
      measure: r.measure?.rounded,
    );
  }

  Attempt.fromJson(Map<String, dynamic> j)
      : analysisId = j['analysis_id'] as String,
        at = DateTime.parse(j['at'] as String),
        verdict = j['verdict'] as String,
        label = j['label'] as String,
        confidence = (j['confidence'] as num).toDouble(),
        source = j['source'] as String,
        modelVersion = j['model_version'] as String?,
        measure = Measure.tryParse(j['measure']);

  // toJson — формат «Local session model» из architecture.md
  Map<String, dynamic> toJson() => {
        'analysis_id': analysisId,
        'at': isoUtc(at),
        'verdict': verdict,
        'label': label,
        'confidence': confidence,
        'source': source,
        if (modelVersion != null) 'model_version': modelVersion,
        if (measure != null) 'measure': measure!.toJson(),
      };
}

// Session — локальное занятие из нескольких попыток
class Session {
  final String id;
  final String exercise;
  final DateTime startedAt;
  final List<Attempt> attempts;

  Session({
    required this.id,
    required this.startedAt,
    this.exercise = defaultExercise,
    List<Attempt>? attempts,
  }) : attempts = attempts ?? [];

  Session.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        exercise = parseExercise(j['exercise'] as String?),
        startedAt = DateTime.parse(j['started_at'] as String),
        attempts = (j['attempts'] as List)
            .map((a) => Attempt.fromJson(a as Map<String, dynamic>))
            .toList();

  // toJson — формат «Local session model» из architecture.md
  Map<String, dynamic> toJson() => {
        'id': id,
        'exercise': exercise,
        'started_at': isoUtc(startedAt),
        'attempts': attempts.map((a) => a.toJson()).toList(),
      };

  int get total => attempts.length;
  int get completeCount => attempts.where((a) => a.label == 'complete').length;
  int get incompleteCount =>
      attempts.where((a) => a.label == 'incomplete').length;
  int get uncertainCount =>
      attempts.where((a) => a.label == 'uncertain').length;
  bool get hasMock => attempts.any((a) => a.source == 'mock');
}
