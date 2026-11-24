import 'package:material_ui/material_ui.dart';

import 'features/exercise/exercise_screen.dart';
import 'features/history/history_screen.dart';
import 'features/home/home_screen.dart';
import 'features/session/session_screen.dart';
import 'features/summary/summary_screen.dart';
import 'models/session.dart';

// AppColors — цвета: белый фон, светло-серые карточки, тёмно-зелёный акцент
class AppColors {
  static const green = Color(0xFF1B5E20);
  static const text = Color(0xFF1A1A1A);
  static const textMuted = Color(0xFF3F4642);
  static const card = Color(0xFFF1F3F2);
}

// buildTheme — крупный шрифт и кнопки, высокий контраст
ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.green,
    primary: AppColors.green,
    onPrimary: Colors.white,
    surface: Colors.white,
    onSurface: AppColors.text,
    onSurfaceVariant: AppColors.textMuted,
  );
  const buttonText = TextStyle(fontSize: 20, fontWeight: FontWeight.w700);
  const buttonPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 14);
  final buttonShape =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.white,
    textTheme: const TextTheme(
      headlineSmall: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      bodyLarge: TextStyle(fontSize: 20),
      bodyMedium: TextStyle(fontSize: 18),
      labelLarge: TextStyle(fontSize: 18),
    ).apply(bodyColor: AppColors.text, displayColor: AppColors.text),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.text,
      titleTextStyle: TextStyle(
          fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.text),
      iconTheme: IconThemeData(size: 30),
    ),
    cardTheme: const CardThemeData(
      color: AppColors.card,
      elevation: 0,
      margin: EdgeInsets.symmetric(vertical: 6),
    ),
    listTileTheme: const ListTileThemeData(
      titleTextStyle: TextStyle(
          fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.text),
      subtitleTextStyle: TextStyle(fontSize: 17, color: AppColors.textMuted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(60),
        padding: buttonPadding,
        textStyle: buttonText,
        shape: buttonShape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(60),
        padding: buttonPadding,
        textStyle: buttonText,
        foregroundColor: AppColors.green,
        side: const BorderSide(color: AppColors.green, width: 2),
        shape: buttonShape,
      ),
    ),
  );
}

// onGenerateRoute — маршруты с теми же именами, что на сайте
Route<dynamic>? onGenerateRoute(RouteSettings settings) {
  final Widget page;
  switch (settings.name) {
    case '/':
      page = const HomeScreen();
    case '/exercise':
      page = ExerciseScreen(fromSession: settings.arguments == true);
    case '/session':
      page = const SessionScreen();
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
