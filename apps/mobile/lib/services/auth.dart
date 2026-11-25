import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../core/config.dart';
import '../core/strings.dart';

// AccountError — ошибка запроса к аккаунтам с кодом из контракта; retryAfter — секунды из Retry-After при rate_limited
class AccountError implements Exception {
  final String code;
  final int? httpStatus;
  final int? retryAfter;

  AccountError(this.code, [this.httpStatus, this.retryAfter]);

  @override
  String toString() => 'AccountError($code, $httpStatus)';
}

// AuthUser — вошедший пользователь
class AuthUser {
  final String id;
  final String login;
  final String createdAt;

  const AuthUser(this.id, this.login, this.createdAt);

  // fromJson — пользователь из ответа сервера
  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
    j['id'] as String,
    j['login'] as String,
    (j['created_at'] as String?) ?? '',
  );

  // toJson — пользователь для хранилища
  Map<String, dynamic> toJson() => {
    'id': id,
    'login': login,
    'created_at': createdAt,
  };
}

// AuthKind — состояние входа: гость, восстановление входа, вошёл, вход истёк
enum AuthKind { guest, restoring, signedIn, expired }

// AuthState — состояние входа и пользователь, если вошёл
class AuthState {
  final AuthKind kind;
  final AuthUser? user;

  const AuthState(this.kind, [this.user]);

  static const guest = AuthState(AuthKind.guest);
}

// TokenStore — защищённое хранилище токена обновления и пользователя
abstract class TokenStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

// SecureTokenStore — Keychain на iOS и Keystore на Android
class SecureTokenStore implements TokenStore {
  final _storage = const FlutterSecureStorage();

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (_) {
      // хранилище недоступно — токен останется только в памяти до закрытия приложения
    }
  }
}

// MemoryTokenStore — хранилище в памяти для тестов
class MemoryTokenStore implements TokenStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

// authCodes — ошибки, после которых нужно войти снова
const authCodes = ['invalid_token', 'token_expired', 'refresh_reused'];

// validLogin — логин 3–32 символа: латинские буквы, цифры, точка, подчёркивание, дефис
bool validLogin(String login) => RegExp(r'^[A-Za-z0-9._-]{3,32}$').hasMatch(login);

// validPassword — пароль 10–128 символов и без логина внутри (регистр не важен)
bool validPassword(String password, String login) =>
    password.length >= 10 &&
    password.length <= 128 &&
    !password.toLowerCase().contains(login.toLowerCase());

// waitText — время ожидания из Retry-After словами: секунды или минуты
String waitText(int? seconds) {
  final s = (seconds ?? 60) < 1 ? 1 : (seconds ?? 60);
  return s < 60
      ? trFill('wait_seconds', {'n': s})
      : trFill('wait_minutes', {'n': (s / 60).ceil()});
}

// AuthService — вход, обновление токенов и запросы с Bearer; refresh-токен хранится в защищённом хранилище, access-токен только в памяти
class AuthService extends ValueNotifier<AuthState> {
  static const refreshKey = 'seriq.refresh';
  static const userKey = 'seriq.user';
  static const earlyRefresh = Duration(seconds: 30);

  final String baseUrl;
  final http.Client _client;
  final TokenStore _store;
  final DateTime Function() _now;

  String? _access;
  DateTime? _accessExpiresAt;
  String? _refresh;
  Future<void>? _refreshing;

  AuthService({
    String? baseUrl,
    http.Client? client,
    TokenStore? store,
    DateTime Function()? now,
  }) : baseUrl = baseUrl ?? AppConfig.apiBaseUrl,
       _client = client ?? http.Client(),
       _store = store ?? SecureTokenStore(),
       _now = now ?? DateTime.now,
       super(AuthState.guest);

  // user — вошедший пользователь или null
  AuthUser? get user => value.kind == AuthKind.signedIn ? value.user : null;

  // _readError — разбирает ответ с ошибкой в AccountError
  AccountError _readError(http.Response res) {
    String code = 'internal_error';
    try {
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is Map && body['status'] == 'error') {
        final c = (body['error'] as Map?)?['code'];
        if (c is String) code = c;
      }
    } catch (_) {
      // ответ без JSON — внутренняя ошибка
    }
    final retry = int.tryParse(res.headers['retry-after'] ?? '');
    return AccountError(code, res.statusCode, retry != null && retry > 0 ? retry : null);
  }

  // _send — запрос с JSON; обрыв связи превращается в network_error
  Future<http.Response> _send(
    String method,
    String path, {
    Object? body,
    String? bearer,
  }) async {
    final request = http.Request(method, Uri.parse('$baseUrl$path'))
      ..headers['Content-Type'] = 'application/json'
      ..headers['Accept'] = 'application/json';
    if (bearer != null) request.headers['Authorization'] = 'Bearer $bearer';
    if (body != null) request.body = jsonEncode(body);
    try {
      final streamed = await _client.send(request).timeout(const Duration(seconds: 30));
      return await http.Response.fromStream(streamed);
    } catch (_) {
      throw AccountError('network_error');
    }
  }

  // _takeTokens — запоминает токены: access в памяти, новый refresh сразу в защищённом хранилище
  Future<void> _takeTokens(Map<String, dynamic> body) async {
    _access = body['access_token'] as String;
    final expiresIn = (body['expires_in'] as num?)?.toInt() ?? 900;
    _accessExpiresAt = _now().add(Duration(seconds: expiresIn)).subtract(earlyRefresh);
    final refresh = body['refresh_token'] as String?;
    if (refresh != null) {
      _refresh = refresh;
      await _store.write(refreshKey, refresh);
    }
  }

  // _forget — забывает токены и пользователя
  Future<void> _forget() async {
    _access = null;
    _accessExpiresAt = null;
    _refresh = null;
    await _store.delete(refreshKey);
    await _store.delete(userKey);
  }

  // signIn — регистрация или вход по логину и паролю
  Future<AuthUser> signIn(String mode, String login, String password) async {
    final res = await _send('POST', '/auth/$mode', body: {'login': login, 'password': password});
    if (res.statusCode != 200 && res.statusCode != 201) throw _readError(res);
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final u = AuthUser.fromJson(body['user'] as Map<String, dynamic>);
    await _takeTokens(body);
    await _store.write(userKey, jsonEncode(u.toJson()));
    value = AuthState(AuthKind.signedIn, u);
    return u;
  }

  // _refreshOnce — обновляет access-токен по refresh-токену из хранилища
  Future<void> _refreshOnce() async {
    final token = _refresh ?? await _store.read(refreshKey);
    if (token == null) throw AccountError('invalid_token', 401);
    final res = await _send('POST', '/auth/refresh', body: {'refresh_token': token});
    if (res.statusCode != 200) throw _readError(res);
    await _takeTokens(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }

  // refresh — обновление входа, один запрос на всех; invalid_token и refresh_reused означают «войдите снова»
  Future<void> refresh() {
    _refreshing ??= _refreshOnce()
        .catchError((Object e) async {
          if (e is AccountError && authCodes.contains(e.code)) {
            await _forget();
            value = const AuthState(AuthKind.expired);
          }
          throw e;
        })
        .whenComplete(() => _refreshing = null);
    return _refreshing!;
  }

  // restore — при запуске восстанавливает вход по токену из хранилища; без связи остаётся вход с сохранённым пользователем
  Future<void> restore() async {
    if (value.kind != AuthKind.guest) return;
    final token = await _store.read(refreshKey);
    final raw = await _store.read(userKey);
    if (token == null) return;
    AuthUser? cached;
    try {
      cached = raw == null ? null : AuthUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      cached = null;
    }
    _refresh = token;
    value = const AuthState(AuthKind.restoring);
    try {
      await refresh();
      final res = await authorized('GET', '/me');
      final u = AuthUser.fromJson(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
      await _store.write(userKey, jsonEncode(u.toJson()));
      value = AuthState(AuthKind.signedIn, u);
    } catch (e) {
      if (value.kind == AuthKind.expired) return;
      if (e is AccountError && e.code == 'network_error' && cached != null) {
        value = AuthState(AuthKind.signedIn, cached);
      } else if (value.kind == AuthKind.restoring) {
        value = AuthState.guest;
      }
    }
  }

  // authorized — запрос с Bearer-токеном: обновляет токен заранее и один раз повторяет запрос при token_expired или invalid_token
  Future<http.Response> authorized(String method, String path, {Object? body}) async {
    final expired = _access == null || !_now().isBefore(_accessExpiresAt ?? _now());
    if (expired) await refresh();
    for (var attempt = 0; ; attempt++) {
      final res = await _send(method, path, body: body, bearer: _access);
      if (res.statusCode >= 200 && res.statusCode < 300) return res;
      final err = _readError(res);
      if (attempt == 0 && (err.code == 'token_expired' || err.code == 'invalid_token')) {
        await refresh();
        continue;
      }
      throw err;
    }
  }

  // signOut — выход: сервер отзывает цепочку, токен и вход на устройстве забываются
  Future<void> signOut() async {
    final token = _refresh ?? await _store.read(refreshKey);
    if (token != null) {
      try {
        await _send('POST', '/auth/logout', body: {'refresh_token': token});
      } catch (_) {
        // выход на устройстве выполняется всегда
      }
    }
    await _forget();
    value = AuthState.guest;
  }

  // deleteAccount — удаляет аккаунт и все данные на сервере после подтверждения паролем
  Future<void> deleteAccount(String password) async {
    await authorized('DELETE', '/me', body: {'password': password});
    await _forget();
    value = AuthState.guest;
  }
}

// auth — вход приложения
final auth = AuthService();
