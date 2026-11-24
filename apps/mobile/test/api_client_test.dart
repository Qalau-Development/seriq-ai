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
