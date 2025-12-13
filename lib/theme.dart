import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// --- 1. Constants & Colors ---
const neoBlack = Color(0xFF000000);
const neoWhite = Color(0xFFFFFFFF);
const neoBackground = Color(0xFFFFF9F4); // Мягкий кремовый
const neoAccent = Color(0xFFFD7600); // Циан (резервный акцент)
const btnColorWhite = Color(0xFFF4F3EE);
// Цвета кнопок (по вашему ТЗ)
const btnColorSuccess = Color(0xFF37FD00);
const btnColorLogin = Color(0xFFFFAF81); // Персиковый (Login)
const btnColorSignup = Color(0xFFFFAF81); // Салатовый (Sign Up)
const btnColorDefault = Color(0xFFFD7600); // Оранжевый (General)
const bottomBackground = Color.fromARGB(255, 239, 239, 239);
// --- 2. Typography Helper (EPILOGUE FONT) ---
// Используем Epilogue везде
TextStyle neoTextStyle(
  double size, {
  FontWeight weight = FontWeight.w700,
  Color color = neoBlack,
}) {
  return GoogleFonts.epilogue(fontSize: size, fontWeight: weight, color: color);
}

// --- 3. Base Theme Data ---
// Эта тема нужна для стандартных виджетов (Scaffold, AppBar).
// Для кнопок и полей ввода лучше использовать кастомные виджеты ниже.
var fullNeoBrutalismTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: neoBackground,

  colorScheme: const ColorScheme.light(
    primary: neoBlack,
    secondary: btnColorDefault,
    surface: neoWhite,
    onSurface: neoBlack,
  ),

  // Настройка AppBar
  appBarTheme: const AppBarTheme(
    backgroundColor: neoBackground,
    foregroundColor: neoBlack,
    centerTitle: true,
    elevation: 0,
    iconTheme: IconThemeData(color: neoBlack, size: 30),
    // У AppBar рамка всегда равномерная, ставим 4
  ),

  // Типографика
  textTheme: TextTheme(
    headlineLarge: neoTextStyle(
      28,
      weight: FontWeight.w900,
    ), // ExtraBold для заголовков
    headlineMedium: neoTextStyle(24, weight: FontWeight.w800),
    headlineSmall: neoTextStyle(20, weight: FontWeight.bold),
    bodyLarge: neoTextStyle(18, weight: FontWeight.normal),
    bodyMedium: neoTextStyle(16, weight: FontWeight.normal),
    bodySmall: neoTextStyle(14, weight: FontWeight.normal),
  ),

  // Стандартные инпуты (если вдруг используете TextField без обертки)
  inputDecorationTheme: InputDecorationTheme(
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
    filled: true,
    fillColor: neoWhite,
    hintStyle: neoTextStyle(
      16,
      color: Colors.grey.shade600,
      weight: FontWeight.normal,
    ),
    enabledBorder: OutlineInputBorder(
      borderSide: const BorderSide(color: neoBlack, width: 3),
      borderRadius: BorderRadius.circular(15),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: const BorderSide(color: neoBlack, width: 3),
      borderRadius: BorderRadius.circular(15),
    ),
    errorBorder: OutlineInputBorder(
      borderSide: const BorderSide(color: Colors.redAccent, width: 3),
      borderRadius: BorderRadius.circular(15),
    ),
  ),
);
