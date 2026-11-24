import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
