import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seriq_mobile/core/strings.dart';

import '../tool/sync_strings.dart' show parseDict;

// siteDict — словарь сайта из apps/web/lib/i18n
Map<String, String> siteDict(String lang) =>
    parseDict(File('../web/lib/i18n/$lang.ts').readAsStringSync());

void main() {
  setUp(() => appLang.value = 'ru');

  test('тексты приложения совпадают с сайтом один в один', () {
    for (final lang in appLangs) {
      expect(Strings.byLang(lang), siteDict(lang), reason: lang);
    }
  });

  test('у трёх языков одинаковые ключи', () {
    expect(Strings.kk.keys.toSet(), Strings.ru.keys.toSet());
    expect(Strings.en.keys.toSet(), Strings.ru.keys.toSet());
  });

  test('есть тексты для всех кодов из api.md', () {
    const codes = [
      'verdict_completed', 'verdict_check_instructions',
      'label_complete', 'label_incomplete', 'label_uncertain',
      'warning_arm_not_visible',
      'error_missing_video', 'error_empty_file', 'error_unsupported_exercise',
      'error_file_too_large', 'error_unsupported_format',
      'error_video_unreadable', 'error_video_too_short',
      'error_video_too_long', 'error_no_pose_detected', 'error_busy',
      'error_internal_error', 'error_network_error', 'error_camera_denied',
      'error_recording_too_short', 'error_invalid_credentials',
      'error_login_taken', 'error_weak_password', 'error_invalid_request',
      'error_rate_limited', 'error_invalid_token', 'error_token_expired',
      'error_refresh_reused', 'error_quota_exceeded',
    ];
    for (final c in codes) {
      expect(Strings.ru.containsKey(c), isTrue, reason: c);
    }
  });

  test('уверенность словами', () {
    expect(Strings.of('ru', 'confidence_high'), 'высокая');
    expect(trConfidence(0.87), 'высокая');
    expect(trConfidence(0.6), 'средняя');
    expect(trConfidence(0.55), 'низкая');
    appLang.value = 'en';
    expect(trConfidence(0.87), Strings.en['confidence_high']);
  });

  test('подстановка и десятичный разделитель', () {
    expect(fill('Выполнено {done} из {total}', {'done': 3, 'total': 4}),
        'Выполнено 3 из 4');
    expect(localNum('0.8'), '0,8');
    appLang.value = 'en';
    expect(localNum('0.8'), '0.8');
  });

  test('ошибка нерусского упражнения берёт вариант _other', () {
    expect(trError('no_pose_detected', 'E02'),
        Strings.ru['error_no_pose_detected']);
    expect(trError('no_pose_detected', 'E04'),
        Strings.ru['error_no_pose_detected_other']);
    expect(trError('нет_такого'), Strings.ru['error_internal_error']);
  });

  test('язык сохраняется под seriq.lang, неизвестное значение — ru', () async {
    SharedPreferences.setMockInitialValues({});
    await appLang.set('en');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('seriq.lang'), 'en');
    appLang.value = 'ru';
    await appLang.load();
    expect(appLang.value, 'en');
    expect(parseLang('de'), 'ru');
    await appLang.set('ru');
  });
}
