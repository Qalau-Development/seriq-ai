import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'core/exercises.dart';
import 'core/routes.dart';
import 'core/theme.dart';
import 'features/exercise/exercise_screen.dart';
import 'features/history/history_screen.dart';
import 'features/account/auth_screen.dart';
import 'features/account/profile_screen.dart';
import 'features/home/home_screen.dart';
import 'features/privacy/privacy_screen.dart';
import 'features/progress/progress_screen.dart';
import 'features/session/session_screen.dart';
import 'features/summary/summary_screen.dart';
import 'features/system/system_screens.dart';

// _exerciseArgs — аргументы маршрута упражнения; без них E02
ExerciseArgs _exerciseArgs(Object? arguments) =>
    arguments is ExerciseArgs ? arguments : const ExerciseArgs(defaultExercise);

// onGenerateRoute — маршруты с теми же именами, что на сайте
Route<dynamic>? onGenerateRoute(RouteSettings settings) {
  final Widget page;
  switch (settings.name) {
    case '/':
      page = const HomeScreen();
    case '/exercise':
      final args = _exerciseArgs(settings.arguments);
      page = ExerciseScreen(id: args.id, fromSession: args.fromSession);
    case '/session':
      page = SessionScreen(exercise: _exerciseArgs(settings.arguments).id);
    case '/summary':
      page = SummaryScreen(id: settings.arguments as String? ?? '');
    case '/history':
      page = const HistoryScreen();
    case '/progress':
      page = const ProgressScreen();
    case '/privacy':
      page = const PrivacyScreen();
    case '/login':
      page = const AuthScreen();
    case '/register':
      page = const AuthScreen(register: true);
    case '/profile':
      page = const ProfileScreen();
    default:
      page = const NotFoundScreen();
  }
  return MaterialPageRoute(builder: (_) => page, settings: settings);
}

// appRestarts — растёт при «Попробовать снова» на экране ошибки: приложение собирается заново
final appRestarts = ValueNotifier<int>(0);

// appNavigator — ключ навигатора, чтобы экран ошибки мог вернуть на главную
var appNavigator = GlobalKey<NavigatorState>();

// restartApp — собирает приложение заново с новым навигатором, прежние экраны не сохраняются
void restartApp() {
  appNavigator = GlobalKey<NavigatorState>();
  appRestarts.value++;
}

// installErrorScreen — в рабочей сборке упавший экран заменяется страницей «Что-то пошло не так» без технических подробностей
void installErrorScreen() {
  if (kDebugMode) return;
  ErrorWidget.builder = (details) => ErrorScreen(
    onRetry: restartApp,
    onHome: () => appNavigator.currentState?.popUntil((r) => r.isFirst),
  );
}

// SeriqApp — корень приложения
class SeriqApp extends StatelessWidget {
  const SeriqApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: appRestarts,
      builder: (context, restarts, _) => MaterialApp(
        key: ValueKey(restarts),
        navigatorKey: appNavigator,
        title: 'SerIQ',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        initialRoute: '/',
        onGenerateRoute: onGenerateRoute,
      ),
    );
  }
}
