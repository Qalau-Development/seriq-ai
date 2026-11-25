import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seriq_mobile/models/analysis_result.dart';
import 'package:seriq_mobile/models/session.dart';
import 'package:seriq_mobile/services/history_storage.dart';

// attempt — попытка с нужной меткой для теста
Attempt attempt(String label, {String source = 'model'}) => Attempt(
      analysisId: 'a-$label',
      at: DateTime.utc(2026, 11, 24, 15, 3, 40, 123),
      verdict: label == 'complete' ? 'completed' : 'check_instructions',
      label: label,
      confidence: 0.87,
      source: source,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('формат как в architecture.md', () {
    final s = Session(
      id: 'local-uuid',
      startedAt: DateTime.utc(2026, 11, 24, 15, 2, 11, 500),
      attempts: [attempt('complete')],
    );
    expect(s.toJson(), {
      'id': 'local-uuid',
      'exercise': 'E02',
      'started_at': '2026-11-24T15:02:11Z',
      'attempts': [
        {
          'analysis_id': 'a-complete',
          'at': '2026-11-24T15:03:40Z',
          'verdict': 'completed',
          'label': 'complete',
          'confidence': 0.87,
          'source': 'model',
        }
      ],
    });
  });

  test('попытка с measure и версией модели: запись и чтение без потерь', () async {
    final a = Attempt(
      analysisId: 'a1',
      at: DateTime.utc(2026, 11, 24, 15, 3, 40),
      verdict: 'completed',
      label: 'complete',
      confidence: 0.9,
      source: 'model',
      modelVersion: 'e02-logreg2-1',
      measure: Measure(
        name: 'hand_openness',
        unit: 'percent',
        value: 138.5,
        series: Series(fps: 10, values: [100.0, null, 138.5]),
      ),
    );
    final s = Session(
      id: 's',
      exercise: 'E04',
      startedAt: DateTime.utc(2026, 11, 24, 15),
      attempts: [a],
    );
    final storage = HistoryStorage();
    await storage.saveSession(s);
    final back = (await storage.loadSessions()).single;
    expect(back.exercise, 'E04');
    expect(back.attempts.single.modelVersion, 'e02-logreg2-1');
    expect(back.attempts.single.measure!.toJson(), a.measure!.toJson());
  });

  test('старые записи E02 без measure и exercise читаются как раньше', () async {
    SharedPreferences.setMockInitialValues({
      'seriq.sessions.v1': jsonEncode([
        {
          'id': 'old',
          'exercise': 'E02',
          'started_at': '2026-11-20T10:00:00Z',
          'attempts': [
            {
              'analysis_id': 'a',
              'at': '2026-11-20T10:01:00Z',
              'verdict': 'completed',
              'label': 'complete',
              'confidence': 0.8,
              'source': 'model',
            }
          ],
        },
        {
          'id': 'no-exercise',
          'started_at': '2026-11-21T10:00:00Z',
          'attempts': <Object>[],
        },
        {'id': 'broken'},
      ]),
    });
    final loaded = await HistoryStorage().loadSessions();
    expect(loaded.map((s) => s.id), ['no-exercise', 'old']);
    final old = loaded.last;
    expect(old.exercise, 'E02');
    expect(old.attempts.single.measure, isNull);
    expect(old.attempts.single.modelVersion, isNull);
    expect(old.toJson()['attempts'], [
      {
        'analysis_id': 'a',
        'at': '2026-11-20T10:01:00Z',
        'verdict': 'completed',
        'label': 'complete',
        'confidence': 0.8,
        'source': 'model',
      }
    ]);
    expect(loaded.first.exercise, 'E02');
  });

  test('сводка по меткам', () {
    final s = Session(id: 'x', startedAt: DateTime.now(), attempts: [
      attempt('complete'),
      attempt('complete'),
      attempt('incomplete'),
      attempt('uncertain', source: 'mock'),
    ]);
    expect(s.total, 4);
    expect(s.completeCount, 2);
    expect(s.incompleteCount, 1);
    expect(s.uncertainCount, 1);
    expect(s.hasMock, isTrue);
  });

  test('сохранение, обновление, порядок и удаление', () async {
    final storage = HistoryStorage();
    final old = Session(id: 'old', startedAt: DateTime.utc(2026, 11, 23));
    final now = Session(id: 'new', startedAt: DateTime.utc(2026, 11, 24));
    await storage.saveSession(old);
    await storage.saveSession(now);
    now.attempts.add(attempt('complete'));
    await storage.saveSession(now);

    final loaded = await storage.loadSessions();
    expect(loaded.map((s) => s.id), ['new', 'old']);
    expect(loaded.first.total, 1);

    final prefs = await SharedPreferences.getInstance();
    final raw = jsonDecode(prefs.getString('seriq.sessions.v1')!) as List;
    expect(raw.length, 2);

    await storage.clearAll();
    expect(await storage.loadSessions(), isEmpty);
  });
}
