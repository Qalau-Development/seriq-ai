import 'package:material_ui/material_ui.dart';

import 'core/exercises.dart';
import 'core/routes.dart';
import 'core/theme.dart';
import 'features/exercise/exercise_screen.dart';
import 'features/history/history_screen.dart';
import 'features/home/home_screen.dart';
import 'features/session/session_screen.dart';
import 'features/summary/summary_screen.dart';
import 'models/session.dart';

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
      page = SummaryScreen(session: settings.arguments as Session);
    case '/history':
      page = const HistoryScreen();
    default:
      return null;
  }
  return MaterialPageRoute(builder: (_) => page, settings: settings);
}

// SeriqApp — корень приложения
class SeriqApp extends StatelessWidget {
  const SeriqApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SerIQ',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      initialRoute: '/',
      onGenerateRoute: onGenerateRoute,
    );
  }
}
