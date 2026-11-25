import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/config.dart';

// checkInterval — как часто заново спрашивается, включены ли аккаунты
const checkInterval = Duration(minutes: 5);

// hasDatabase — аккаунты доступны, если в ответе /health есть поле database (значение не важно)
bool hasDatabase(Object? body) => body is Map && body.containsKey('database');

// checkAccounts — читает /health: есть поле database — аккаунты есть; нет поля или сервер недоступен — аккаунтов нет
Future<bool> checkAccounts({http.Client? client, String? baseUrl}) async {
  final c = client ?? http.Client();
  try {
    final res = await c
        .get(Uri.parse('${baseUrl ?? AppConfig.apiBaseUrl}/health'))
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return false;
    return hasDatabase(jsonDecode(utf8.decode(res.bodyBytes)));
  } catch (_) {
    return false;
  }
}

// AccountsAvailability — «аккаунты доступны»: проверка при запуске и затем раз в интервал; null, пока ответа нет
class AccountsAvailability extends ValueNotifier<bool?> {
  final Future<bool> Function() _check;
  Timer? _timer;

  AccountsAvailability(this._check) : super(null);

  // refresh — запрашивает /health и сообщает об изменении
  Future<void> refresh() async {
    value = await _check();
  }

  // start — первая проверка сразу и дальше по таймеру
  void start([Duration interval = checkInterval]) {
    refresh();
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => refresh());
  }

  // stop — останавливает периодические проверки
  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}

// accountsAvailable — доступны ли аккаунты на сервере
final accountsAvailable = AccountsAvailability(checkAccounts);
