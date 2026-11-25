import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:seriq_mobile/services/api_client.dart';

void main() {
  late File video;

  setUpAll(() {
    video = File('${Directory.systemTemp.createTempSync('seriq').path}/v.mp4')
      ..writeAsBytesSync([0, 1, 2, 3]);
  });

  test('отправляет video и exercise=E02, передаёт mock_scenario', () async {
    late http.Request sent;
    final example =
        File('../../docs/api-examples/analysis-uncertain.json').readAsStringSync();
    final client = ApiClient(
      baseUrl: 'https://example.com/api/v1',
      client: MockClient((req) async {
        sent = req;
        return http.Response(example, 200,
            headers: {'content-type': 'application/json'});
      }),
    );
    final r = await client.analyze(video.path, mockScenario: 'uncertain');
    expect(r.mainCycle!.label, 'uncertain');
    expect(sent.url.toString(),
        'https://example.com/api/v1/analysis?mock_scenario=uncertain');
    final body = sent.body;
    expect(body, contains('name="video"'));
    expect(body, contains('name="exercise"'));
    expect(body, contains('E02'));
  });

  test('передаёт выбранное упражнение, а не жёстко E02', () async {
    late http.Request sent;
    final example =
        File('../../docs/api-examples/analysis-complete.json').readAsStringSync();
    final client = ApiClient(
      baseUrl: 'https://example.com/api/v1',
      client: MockClient((req) async {
        sent = req;
        return http.Response(example, 200,
            headers: {'content-type': 'application/json'});
      }),
    );
    await client.analyze(video.path, exercise: 'E04');
    expect(sent.url.toString(), 'https://example.com/api/v1/analysis');
    expect(sent.body, contains('E04'));
    expect(sent.body, isNot(contains('E02')));
  });

  test('каталог упражнений: ответ сервера', () async {
    final client = ApiClient(
      baseUrl: 'https://example.com/api/v1',
      client: MockClient((req) async {
        expect(req.url.toString(), 'https://example.com/api/v1/exercises');
        return http.Response(
          jsonEncode([
            {'id': 'E01', 'measure': {'name': 'lift_height', 'unit': 'hand_lengths'}, 'ready': true},
            {'id': 'E02', 'measure': {'name': 'elbow_angle', 'unit': 'deg'}, 'ready': true},
            {'id': 'E03', 'measure': {'name': 'wrist_lift', 'unit': 'deg'}, 'ready': false},
            {'id': 'E04', 'measure': {'name': 'hand_openness', 'unit': 'percent'}, 'ready': true},
          ]),
          200,
        );
      }),
    );
    final c = await client.fetchCatalog();
    expect(c.where((e) => e.ready).map((e) => e.id), ['E01', 'E02', 'E04']);
  });

  test('каталог упражнений: при любой ошибке запасной список', () async {
    final fallbackIds = ['E02'];
    for (final handler in <Future<http.Response> Function(http.Request)>[
      (_) async => http.Response('', 500),
      (_) async => http.Response('не json', 200),
      (_) async => http.Response('{"a": 1}', 200),
      (_) async => throw const SocketException('offline'),
    ]) {
      final c = await ApiClient(client: MockClient(handler)).fetchCatalog();
      expect(c.where((e) => e.ready).map((e) => e.id), fallbackIds);
      expect(c.length, 4);
    }
  });

  test('ошибка из контракта', () async {
    final example =
        File('../../docs/api-examples/error-no-pose.json').readAsStringSync();
    final client = ApiClient(
        client: MockClient((_) async => http.Response(example, 422)));
    expect(
      () => client.analyze(video.path),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', 'no_pose_detected')
          .having((e) => e.httpStatus, 'status', 422)),
    );
  });

  test('нет сети — network_error', () async {
    final client = ApiClient(
        client: MockClient((_) async => throw const SocketException('offline')));
    expect(
      () => client.analyze(video.path),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'network_error')),
    );
  });

  test('ответ без JSON', () {
    expect(
      () => ApiClient.parseResponse(413, utf8.encode('Request Entity Too Large')),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'file_too_large')),
    );
    expect(
      () => ApiClient.parseResponse(502, const []),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'internal_error')),
    );
  });
}
