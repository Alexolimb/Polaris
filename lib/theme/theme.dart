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

  // Третичный текст. Был #5A6584 — контраст 2.96:1 на surfaceHigh при норме
  // WCAG AA 4.5:1, и им набраны подписи 9–12,5 px по всему приложению
  // (аудитория продукта — в том числе пожилые). Осветлён до контраста ≥4.6:1
  // на всех трёх фонах, оттенок сохранён.
  static const textFaint = Color(0xFF8592B0);

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
    // Закрываем схему целиком. Раньше переопределялись только 4 цвета, а всё
    // остальное оставалось из дефолтной ФИОЛЕТОВОЙ схемы Material 3 — из-за
    // этого нижнее меню (главный элемент приложения) и снекбары рисовались
    // лавандово-серыми поверх ледяного космоса.
    colorScheme: base.colorScheme.copyWith(
      primary: PolarisColors.polar,
      onPrimary: PolarisColors.bg,
      secondary: PolarisColors.aurora,
      onSecondary: PolarisColors.bg,
      surface: PolarisColors.surface,
      onSurface: PolarisColors.textPrimary,
      onSurfaceVariant: PolarisColors.textSecondary,
      surfaceContainerHighest: PolarisColors.surfaceHigh,
      outline: PolarisColors.textFaint,
      outlineVariant: PolarisColors.surfaceHigh,
      inverseSurface: PolarisColors.surfaceHigh,
      onInverseSurface: PolarisColors.textPrimary,
      error: PolarisColors.loss,
      onError: PolarisColors.bg,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: PolarisColors.textPrimary,
      displayColor: PolarisColors.textPrimary,
    ),
    // Нижнее меню — в фирменных цветах, с крупной читаемой подписью
    // (целевая аудитория — в том числе пожилые и дети).
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: PolarisColors.surface,
      indicatorColor: PolarisColors.polar.withValues(alpha: 0.18),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          size: 24,
          color: s.contains(WidgetState.selected)
              ? PolarisColors.polar
              : PolarisColors.textSecondary,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 12.5,
          fontWeight:
              s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          color: s.contains(WidgetState.selected)
              ? PolarisColors.polar
              : PolarisColors.textSecondary,
        ),
      ),
    ),
    // Снекбар — основной канал ответа после сделки и реплик Cosmo.
    // Дефолтный M3 рисовал светлую коробку в тёмном приложении.
    snackBarTheme: SnackBarThemeData(
      backgroundColor: PolarisColors.surfaceHigh,
      contentTextStyle: const TextStyle(
        color: PolarisColors.textPrimary,
        fontSize: 14,
      ),
      actionTextColor: PolarisColors.polar,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      insetPadding: const EdgeInsets.all(16),
    ),
    splashFactory: InkSparkle.splashFactory,
  );
}
