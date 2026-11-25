import 'package:flutter_test/flutter_test.dart';
import 'package:seriq_mobile/services/speech.dart';

void main() {
  test('двойные точки на стыках убираются, обычный текст не меняется', () {
    expect(cleanText('Выполнено. . Рука разогнулась до 166°.'), 'Выполнено. Рука разогнулась до 166°.');
    expect(cleanText('Привет… .. Пока'), 'Привет… Пока');
    expect(cleanText('Без точек'), 'Без точек');
  });

  test('языки голоса: русский, казахский и английский', () {
    expect(speechLocales, {'ru': 'ru-RU', 'kk': 'kk-KZ', 'en': 'en-US'});
  });
}
