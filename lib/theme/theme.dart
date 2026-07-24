import 'package:flutter/material.dart';

/// Palette «Polaris» — глубокий космос с северным сиянием.
/// Отличается от Altron (там золото #F2C14E): здесь холодный полярный свет.
class PolarisColors {
  // Фоны
  static const bg = Color(0xFF05070F); // почти чёрный космос
  static const surface = Color(0xFF0B1226); // карточки
  static const surfaceHigh = Color(0xFF141C36); // приподнятые элементы

  // Полярный свет — фирменные акценты
  static const polar = Color(0xFF6FB7FF); // главный: голубое сияние
  static const aurora = Color(0xFF54E6C1); // бирюза сияния
  static const violet = Color(0xFF9B7BFF); // фиолетовый край сияния
  static const star = Color(0xFFEFF4FF); // звёздный белый (текст)

  // Деньги
  static const gain = Color(0xFF3DDC97); // рост
  static const loss = Color(0xFFFF6B81); // падение
  static const dividend = Color(0xFFFFD479); // дивиденды — тёплая монета

  // Текст
  static const textPrimary = Color(0xFFEFF4FF);
  static const textSecondary = Color(0xFF9AA6C4);
  static const textFaint = Color(0xFF5A6584);

  // Классы активов (каталог, темы, графика)
  static const stock = polar;
  static const etf = violet;
  static const crypto = Color(0xFFFFB86B);
  static const fx = aurora;
}

ThemeData polarisTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: PolarisColors.bg,
    colorScheme: base.colorScheme.copyWith(
      primary: PolarisColors.polar,
      secondary: PolarisColors.aurora,
      surface: PolarisColors.surface,
      error: PolarisColors.loss,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: PolarisColors.textPrimary,
      displayColor: PolarisColors.textPrimary,
    ),
    splashFactory: InkSparkle.splashFactory,
  );
}
