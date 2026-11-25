import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config.dart';
import '../core/exercises.dart';
import '../models/analysis_result.dart';

// ApiException — ошибка API с кодом из контракта
class ApiException implements Exception {
  final String code;
  final int? httpStatus;
  ApiException(this.code, [this.httpStatus]);

  @override
  String toString() => 'ApiException($code, $httpStatus)';
}

// ApiClient — отправляет видео на анализ
class ApiClient {
  final String baseUrl;
  final http.Client _client;

  ApiClient({String? baseUrl, http.Client? client})
      : baseUrl = baseUrl ?? AppConfig.apiBaseUrl,
        _client = client ?? http.Client();

  // analyze — загружает видео выбранного упражнения и возвращает результат анализа
  Future<AnalysisResult> analyze(
    String filePath, {
    String exercise = defaultExercise,
    String? mockScenario,
  }) async {
    final uri = Uri.parse('$baseUrl/analysis').replace(
      queryParameters:
          mockScenario == null ? null : {'mock_scenario': mockScenario},
    );
    final request = http.MultipartRequest('POST', uri)
      ..fields['exercise'] = exercise
      ..files.add(await http.MultipartFile.fromPath('video', filePath));

    final http.Response response;
    try {
      final streamed =
          await _client.send(request).timeout(const Duration(minutes: 3));
      response = await http.Response.fromStream(streamed)
          .timeout(const Duration(minutes: 3));
    } catch (_) {
      throw ApiException('network_error');
    }
    return parseResponse(response.statusCode, response.bodyBytes);
  }

  // fetchCatalog — каталог упражнений с сервера; при любой ошибке запасной список, где запись доступна только для E02
  Future<List<CatalogEntry>> fetchCatalog() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/exercises'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return fallbackCatalog();
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      return parseCatalog(body) ?? fallbackCatalog();
    } catch (_) {
      return fallbackCatalog();
    }
  }

  // parseResponse — превращает ответ сервера в результат или ApiException
  static AnalysisResult parseResponse(int statusCode, List<int> bodyBytes) {
    Map<String, dynamic>? body;
    try {
      body = jsonDecode(utf8.decode(bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      body = null;
    }
    if (statusCode == 200 && body != null && body['status'] == 'ok') {
      return AnalysisResult.fromJson(body);
    }
    final code = (body?['error'] as Map<String, dynamic>?)?['code'] as String?;
    throw ApiException(code ?? _codeForStatus(statusCode), statusCode);
  }

  // _codeForStatus — код ошибки, если сервер или прокси ответил без JSON
  static String _codeForStatus(int statusCode) {
    switch (statusCode) {
      case 413:
        return 'file_too_large';
      case 503:
        return 'busy';
      default:
        return 'internal_error';
    }
  }
}
