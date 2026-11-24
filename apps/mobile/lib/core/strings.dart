import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Strings — тексты интерфейса на казахском и русском
class Strings {
  static const ru = {
    'app_tagline': 'Помощник для домашних упражнений: проверяет по видео, выполнено ли упражнение',
    'disclaimer':
        'SerIQ не является медицинским изделием и не ставит диагнозов',
    'nav_home': 'Главная',
    'nav_history': 'История',
    'lang_ru': 'РУС',
    'lang_kk': 'ҚАЗ',
    'exercise_e02_title': 'Разгибание локтя',
    'exercise_e02_desc': 'Одно повторение — одна запись. После каждой записи вы увидите результат.',
    'start_session': 'Начать занятие',
    'instruction_title': 'Как выполнять упражнение',
    'instruction_video_missing':
        'Видеоинструкция скоро появится. Пока ориентируйтесь на шаги ниже.',
    'instruction_step_1': 'Сядьте за стол. Поставьте локоть на стол, предплечье поднимите вертикально, кисть сожмите в кулак.',
    'instruction_step_2':
        'Медленно опускайте предплечье, разгибая руку в локте.',
    'instruction_step_3': 'Опустите руку, пока она не ляжет прямо на стол, и задержите 1–2 секунды.',
    'instruction_step_4': 'Остановите запись, не поднимая руку обратно. Одна запись — одно повторение.',
    'tips_title': 'Как снимать',
    'tip_1': 'Камера сбоку от вас, на уровне стола.',
    'tip_2': 'Локоть на столе, предплечье и кулак целиком в кадре, ничем не закрыты.',
    'tip_3': 'Хорошее освещение, телефон неподвижен.',
    'tip_4': 'Лицо в кадр попадать не должно.',
    'ready': 'Я готов',
    'session_title': 'Занятие',
    'session_hint': 'Запишите одно повторение или выберите видео из галереи.',
    'session_reminder': 'Камера сбоку на уровне стола. Локоть на столе, предплечье и кулак целиком в кадре, ничем не закрыты. Запись останавливайте, когда рука лежит на столе.',
    'record_attempt': 'Записать повторение',
    'pick_video': 'Выбрать видео',
    'upload_formats': 'MP4, MOV или WEBM, до 100 МБ, от 2 до 60 секунд',
    'analyzing': 'Анализируем движение…',
    'analyzing_hint': 'Не закрывайте приложение.',
    'result_title': 'Результат',
    'another_attempt': 'Ещё повторение',
    'watch_instruction': 'Посмотреть инструкцию',
    'try_again': 'Попробовать снова',
    'verdict_completed': 'Выполнено',
    'verdict_check_instructions': 'Проверьте инструкцию',
    'label_complete': 'Выполнено полностью',
    'label_incomplete': 'Рука разогнута не до конца',
    'label_uncertain': 'Не удалось оценить повторение',
    'result_title_complete': 'Выполнено',
    'result_title_incomplete': 'Рука разогнута не до конца',
    'result_title_uncertain': 'Не удалось оценить повторение',
    'result_line_complete': 'Рука разогнулась до {max}° (прямая рука — 180°).',
    'result_line_incomplete': 'Рука разогнулась до {max}° из 180°. Посмотрите инструкцию и попробуйте ещё раз.',
    'result_line_uncertain': 'Рука разогнулась до {max}°. Оценить уверенно не удалось — посмотрите инструкцию и снимите ещё раз: сбоку, кулак и предплечье всё время в кадре.',
    'result_hint_complete': '',
    'result_hint_incomplete': 'Посмотрите инструкцию и попробуйте ещё раз.',
    'result_hint_uncertain': 'Оценить уверенно не удалось — посмотрите инструкцию и снимите ещё раз: сбоку, кулак и предплечье всё время в кадре.',
    'confidence_title': 'Уверенность оценки',
    'confidence_high': 'высокая',
    'confidence_medium': 'средняя',
    'confidence_low': 'низкая',
    'chart_title': 'Как двигалась рука',
    'chart_y_label': 'Угол локтя, ° (180° — прямая рука)',
    'chart_x_label': 'Время, с',
    'chart_gap_hint': 'Разрывы линии — моменты, когда рука не была видна.',
    'mock_badge': 'Тестовые данные — не результат модели',
    'warnings_title': 'Подсказки по съёмке',
    'warning_arm_not_visible': 'Кисть не всё время была видна. Убедитесь, что кулак и предплечье в кадре на протяжении всего движения.',
    'error_missing_video': 'Видео не было отправлено. Выберите файл ещё раз.',
    'error_empty_file': 'Файл пустой. Выберите другое видео.',
    'error_unsupported_exercise': 'Это упражнение пока не поддерживается.',
    'error_file_too_large': 'Файл больше 100 МБ. Запишите видео короче.',
    'error_unsupported_format':
        'Формат не подходит. Нужно видео MP4, MOV или WEBM.',
    'error_video_unreadable':
        'Не удалось открыть видео. Попробуйте записать его заново.',
    'error_video_too_short':
        'Видео короче 2 секунд. Запишите повторение целиком.',
    'error_video_too_long':
        'Видео длиннее 60 секунд. Запишите одно повторение.',
    'error_no_pose_detected': 'Рука не найдена на видео. Снимите сбоку: локоть на столе, предплечье и кулак в кадре.',
    'error_busy':
        'Сервер сейчас занят. Подождите несколько секунд и попробуйте снова.',
    'error_internal_error': 'Что-то пошло не так. Попробуйте ещё раз.',
    'error_network_error':
        'Нет связи с сервером. Проверьте интернет и попробуйте снова.',
    'error_camera_denied':
        'Нет доступа к камере. Разрешите доступ или выберите видео из галереи.',
    'error_recording_too_short':
        'Запись слишком короткая. Запишите повторение целиком.',
    'attempts_title': 'Повторения этого занятия',
    'attempts_empty': 'Пока нет повторений.',
    'attempt_n': 'Повторение',
    'finish_session': 'Завершить занятие',
    'summary_title': 'Итоги занятия',
    'summary_total': 'Всего повторений',
    'summary_chart_title': 'Результаты повторений',
    'summary_attempts': 'Все повторения',
    'summary_has_mock':
        'В занятии есть тестовые данные — это не результат модели',
    'new_session': 'Новое занятие',
    'history_title': 'История занятий',
    'history_empty': 'Здесь появятся ваши занятия. История хранится только на этом устройстве.',
    'history_local_note':
        'История хранится только на этом устройстве и никуда не отправляется.',
    'history_completed_count': 'Выполнено {done} из {total}',
    'clear_history': 'Удалить историю',
    'clear_history_confirm':
        'Удалить все занятия с этого устройства? Восстановить их будет нельзя.',
    'clear_history_yes': 'Да, удалить',
    'clear_history_no': 'Отмена',
    'loading': 'Загрузка…',
    'debug_mock_title': 'Сценарий мока (только в отладке)',
  };

  static const kk = {
    'app_tagline': 'Үйдегі жаттығуларға арналған көмекші: жаттығудың орындалғанын бейне арқылы тексереді',
    'disclaimer': 'SerIQ медициналық бұйым емес және диагноз қоймайды',
    'nav_home': 'Басты бет',
    'nav_history': 'Тарих',
    'lang_ru': 'РУС',
    'lang_kk': 'ҚАЗ',
    'exercise_e02_title': 'Шынтақты жазу',
    'exercise_e02_desc':
        'Бір қайталау — бір жазба. Әр жазбадан кейін нәтижені көресіз.',
    'start_session': 'Сабақты бастау',
    'instruction_title': 'Жаттығуды қалай орындау керек',
    'instruction_video_missing': 'Бейненұсқаулық жақында қосылады. Әзірге төмендегі қадамдарды басшылыққа алыңыз.',
    'instruction_step_1': 'Үстел басына отырыңыз. Шынтағыңызды үстелге қойып, білекті тігінен көтеріңіз, қолды жұдырыққа түйіңіз.',
    'instruction_step_2': 'Шынтақты жазып, білекті баяу түсіріңіз.',
    'instruction_step_3':
        'Қол үстелге түзу жатқанша түсіріп, 1–2 секунд ұстап тұрыңыз.',
    'instruction_step_4':
        'Қолды қайта көтермей, жазуды тоқтатыңыз. Бір жазба — бір қайталау.',
    'tips_title': 'Қалай түсіру керек',
    'tip_1': 'Камера сіздің бүйіріңізде, үстел деңгейінде.',
    'tip_2':
        'Шынтақ үстелде, білек пен жұдырық толық кадрда, ештеңемен жабылмаған.',
    'tip_3': 'Жарық жақсы, телефон қозғалмайды.',
    'tip_4': 'Бет кадрға түспеуі керек.',
    'ready': 'Мен дайынмын',
    'session_title': 'Сабақ',
    'session_hint':
        'Бір қайталауды жазыңыз немесе галереядан бейнені таңдаңыз.',
    'session_reminder': 'Камера бүйірде, үстел деңгейінде. Шынтақ үстелде, білек пен жұдырық толық кадрда, ештеңемен жабылмаған. Қол үстелде жатқанда жазуды тоқтатыңыз.',
    'record_attempt': 'Қайталауды жазу',
    'pick_video': 'Бейнені таңдау',
    'upload_formats':
        'MP4, MOV немесе WEBM, 100 МБ-қа дейін, 2-ден 60 секундқа дейін',
    'analyzing': 'Қимылды талдап жатырмыз…',
    'analyzing_hint': 'Қосымшаны жаппаңыз.',
    'result_title': 'Нәтиже',
    'another_attempt': 'Тағы бір қайталау',
    'watch_instruction': 'Нұсқаулықты қарау',
    'try_again': 'Қайталап көру',
    'verdict_completed': 'Орындалды',
    'verdict_check_instructions': 'Нұсқаулықты тексеріңіз',
    'label_complete': 'Толық орындалды',
    'label_incomplete': 'Қол соңына дейін жазылмады',
    'label_uncertain': 'Қайталауды бағалау мүмкін болмады',
    'result_title_complete': 'Орындалды',
    'result_title_incomplete': 'Қол соңына дейін жазылмады',
    'result_title_uncertain': 'Қайталауды бағалау мүмкін болмады',
    'result_line_complete':
        'Қол {max}° бұрышқа дейін жазылды (түзу қол — 180°).',
    'result_line_incomplete': 'Қол 180°-тың орнына {max}° бұрышқа дейін ғана жазылды. Нұсқаулықты қарап, қайталап көріңіз.',
    'result_line_uncertain': 'Қол {max}° бұрышқа дейін жазылды. Сенімді бағалау мүмкін болмады — нұсқаулықты қарап, қайта түсіріңіз: бүйірден, жұдырық пен білек үнемі кадрда болсын.',
    'result_hint_complete': '',
    'result_hint_incomplete': 'Нұсқаулықты қарап, қайталап көріңіз.',
    'result_hint_uncertain': 'Сенімді бағалау мүмкін болмады — нұсқаулықты қарап, қайта түсіріңіз: бүйірден, жұдырық пен білек үнемі кадрда болсын.',
    'confidence_title': 'Бағалаудың сенімділігі',
    'confidence_high': 'жоғары',
    'confidence_medium': 'орташа',
    'confidence_low': 'төмен',
    'chart_title': 'Қол қалай қозғалды',
    'chart_y_label': 'Шынтақ бұрышы, ° (180° — түзу қол)',
    'chart_x_label': 'Уақыт, с',
    'chart_gap_hint': 'Сызықтағы үзілістер — қол көрінбеген сәттер.',
    'mock_badge': 'Сынақ деректері — модель нәтижесі емес',
    'warnings_title': 'Түсіру бойынша кеңестер',
    'warning_arm_not_visible': 'Қол басы үнемі көрінбеді. Бүкіл қимыл бойы жұдырық пен білектің кадрда болуын қадағалаңыз.',
    'error_missing_video': 'Бейне жіберілмеді. Файлды қайта таңдаңыз.',
    'error_empty_file': 'Файл бос. Басқа бейнені таңдаңыз.',
    'error_unsupported_exercise': 'Бұл жаттығуға әзірге қолдау көрсетілмейді.',
    'error_file_too_large': 'Файл 100 МБ-тан үлкен. Қысқарақ бейне жазыңыз.',
    'error_unsupported_format':
        'Формат сәйкес келмейді. MP4, MOV немесе WEBM бейнесі керек.',
    'error_video_unreadable':
        'Бейнені ашу мүмкін болмады. Оны қайта жазып көріңіз.',
    'error_video_too_short':
        'Бейне 2 секундтан қысқа. Қайталауды толық жазыңыз.',
    'error_video_too_long': 'Бейне 60 секундтан ұзын. Бір қайталауды жазыңыз.',
    'error_no_pose_detected': 'Бейнеде қол табылмады. Бүйірден түсіріңіз: шынтақ үстелде, білек пен жұдырық кадрда.',
    'error_busy':
        'Сервер қазір бос емес. Бірнеше секунд күтіп, қайталап көріңіз.',
    'error_internal_error': 'Бірдеңе дұрыс болмады. Қайталап көріңіз.',
    'error_network_error':
        'Сервермен байланыс жоқ. Интернетті тексеріп, қайталап көріңіз.',
    'error_camera_denied': 'Камераға рұқсат жоқ. Рұқсат беріңіз немесе галереядан бейнені таңдаңыз.',
    'error_recording_too_short': 'Жазба тым қысқа. Қайталауды толық жазыңыз.',
    'attempts_title': 'Осы сабақтағы қайталаулар',
    'attempts_empty': 'Әзірге қайталау жоқ.',
    'attempt_n': 'Қайталау',
    'finish_session': 'Сабақты аяқтау',
    'summary_title': 'Сабақ қорытындысы',
    'summary_total': 'Барлық қайталау',
    'summary_chart_title': 'Қайталаулардың нәтижесі',
    'summary_attempts': 'Барлық қайталаулар',
    'summary_has_mock':
        'Сабақта сынақ деректері бар — бұл модель нәтижесі емес',
    'new_session': 'Жаңа сабақ',
    'history_title': 'Сабақтар тарихы',
    'history_empty':
        'Сабақтарыңыз осында көрсетіледі. Тарих тек осы құрылғыда сақталады.',
    'history_local_note':
        'Тарих тек осы құрылғыда сақталады және ешқайда жіберілмейді.',
    'history_completed_count': '{total} қайталаудың {done} орындалды',
    'clear_history': 'Тарихты өшіру',
    'clear_history_confirm': 'Осы құрылғыдағы барлық сабақты өшіру керек пе? Оларды қалпына келтіру мүмкін болмайды.',
    'clear_history_yes': 'Иә, өшіру',
    'clear_history_no': 'Болдырмау',
    'loading': 'Жүктеліп жатыр…',
    'debug_mock_title': 'Мок сценарийі (тек жөндеу кезінде)',
  };

  // of — возвращает текст по ключу для выбранного языка
  static String of(String lang, String key) =>
      (lang == 'kk' ? kk : ru)[key] ?? ru[key] ?? key;
}

// LangController — выбранный язык, хранится под ключом seriq.lang
class LangController extends ValueNotifier<String> {
  static const storageKey = 'seriq.lang';

  LangController() : super('ru');

  // load — читает сохранённый язык
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(storageKey);
    value = saved == 'kk' ? 'kk' : 'ru';
  }

  // set — меняет и сохраняет язык
  Future<void> set(String lang) async {
    value = lang == 'kk' ? 'kk' : 'ru';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, value);
  }
}

final appLang = LangController();

// tr — текст по ключу на текущем языке
String tr(String key) => Strings.of(appLang.value, key);

// trError — текст для кода ошибки API или клиента
String trError(String code) {
  final key = 'error_$code';
  return Strings.ru.containsKey(key) ? tr(key) : tr('error_internal_error');
}

// trConfidence — уверенность словами по правилу из integration.md
String trConfidence(double c) => tr(
  c >= 0.8
      ? 'confidence_high'
      : c >= 0.6
      ? 'confidence_medium'
      : 'confidence_low',
);
