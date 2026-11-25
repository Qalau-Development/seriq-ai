import 'package:material_ui/material_ui.dart';

// AppColors — цвета из токенов дизайна (00a-tokens)
class AppColors {
  static const page = Color(0xFFF2F6FA);
  static const surface = Color(0xFFFFFFFF);
  static const line = Color(0xFFD3DEE9);
  static const lineStrong = Color(0xFF5F7C99);
  static const ink = Color(0xFF0E2237);
  static const muted = Color(0xFF435A72);
  static const accent = Color(0xFFF87C2C);
  static const accentHover = Color(0xFFEC6F1F);
  static const accentSoft = Color(0xFFFFEADA);
  static const accentStrong = Color(0xFFE4620C);
  static const onAccent = Color(0xFF0A1E33);
  static const secondary = Color(0xFFFF4919);
  static const brand = Color(0xFF114A7D);
  static const brandHover = Color(0xFF0C3A63);
  static const brandSoft = Color(0xFFDCEBF6);
  static const brandSoft2 = Color(0xFFB0D0E4);
  static const link = Color(0xFF1C5CA9);
  static const neutralSoft = Color(0xFFDCEBF6);
  static const neutralInk = Color(0xFF0F3F6B);
  static const warnSoft = Color(0xFFFFF3C4);
  static const warnInk = Color(0xFF5C3A00);
  static const warnLine = Color(0xFFD9A400);
  static const errorSoft = Color(0xFFFDECEA);
  static const errorInk = Color(0xFF7F1D1D);
  static const errorLine = Color(0xFFE5A19B);
  static const tile = Color(0xFFEAF1F7);
  static const accentLine = Color(0xFFF6B98C);
  static const track = Color(0xFFDFE8F1);
  static const errorHover = Color(0xFF651717);
  static const disabled = Color(0xFFE1E8EF);
  static const disabledInk = Color(0xFF4F6176);
}

// AppSizes — радиусы и отступы из макета
class AppSizes {
  static const cardRadius = 28.0;
  static const tileRadius = 22.0;
  static const messageRadius = 20.0;
  static const fieldRadius = 16.0;
  static const pagePadding = 20.0;
  static const contentMaxWidth = 720.0;
  static const touch = 48.0;
  static const buttonHeight = 56.0;
}

// cardShadow — тень карточек: 0 1px 2px и 0 10px 30px оттенка brand
const cardShadow = [
  BoxShadow(color: Color(0x0F114A7D), blurRadius: 2, offset: Offset(0, 1)),
  BoxShadow(color: Color(0x12114A7D), blurRadius: 30, offset: Offset(0, 10)),
];

// AppText — стили текста: основной 18/27, вторичный 16/24, заголовки 32/38 и 24/29
class AppText {
  static const title = TextStyle(
    fontSize: 32,
    height: 38 / 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.32,
    color: AppColors.ink,
  );
  static const h2 = TextStyle(
    fontSize: 24,
    height: 29 / 24,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.24,
    color: AppColors.ink,
  );
  static const h3 = TextStyle(
    fontSize: 20,
    height: 26 / 20,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );
  static const body = TextStyle(
    fontSize: 18,
    height: 27 / 18,
    fontWeight: FontWeight.w500,
    color: AppColors.ink,
  );
  static const bodyStrong = TextStyle(
    fontSize: 18,
    height: 26 / 18,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );
  static const small = TextStyle(
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w500,
    color: AppColors.muted,
  );
  static const smallStrong = TextStyle(
    fontSize: 16,
    height: 22 / 16,
    fontWeight: FontWeight.w700,
    color: AppColors.muted,
  );
}

// buildTheme — тема приложения из токенов: Montserrat, светлый фон, кнопки-таблетки
ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.brand,
    primary: AppColors.brand,
    onPrimary: Colors.white,
    secondary: AppColors.accent,
    onSecondary: AppColors.onAccent,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.muted,
    outline: AppColors.lineStrong,
    outlineVariant: AppColors.line,
    error: AppColors.errorInk,
    onError: Colors.white,
    errorContainer: AppColors.errorSoft,
    onErrorContainer: AppColors.errorInk,
  );
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Montserrat',
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.page,
    textTheme: const TextTheme(
      headlineLarge: AppText.title,
      headlineMedium: AppText.title,
      headlineSmall: AppText.h2,
      titleLarge: AppText.h2,
      titleMedium: AppText.h3,
      bodyLarge: AppText.body,
      bodyMedium: AppText.body,
      bodySmall: AppText.small,
      labelLarge: AppText.bodyStrong,
    ),
    dividerColor: AppColors.line,
    focusColor: AppColors.brand,
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.brand,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.fieldRadius),
        borderSide: const BorderSide(color: AppColors.lineStrong, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.fieldRadius),
        borderSide: const BorderSide(color: AppColors.lineStrong, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.fieldRadius),
        borderSide: const BorderSide(color: AppColors.brand, width: 3),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSizes.fieldRadius),
        borderSide: const BorderSide(color: AppColors.errorInk, width: 2),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      ),
    ),
  );
}
