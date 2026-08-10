import 'package:flutter/material.dart';

ThemeData buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final base = ColorScheme.fromSeed(
    seedColor: const Color(0xFF2E7D6E),
    brightness: brightness,
  );

  final scheme = isDark
      ? base.copyWith(
          primary: const Color(0xFF7CC7B8),
          onPrimary: const Color(0xFF07372F),
          primaryContainer: const Color(0xFF1C4C43),
          onPrimaryContainer: const Color(0xFFC5F1E8),
          secondary: const Color(0xFFAECAC4),
          secondaryContainer: const Color(0xFF2B3C39),
          onSecondaryContainer: const Color(0xFFDCEBE7),
          surface: const Color(0xFF111416),
          onSurface: const Color(0xFFE4E8E7),
          surfaceContainerLowest: const Color(0xFF0D1011),
          surfaceContainerLow: const Color(0xFF171B1D),
          surfaceContainer: const Color(0xFF1B2022),
          surfaceContainerHigh: const Color(0xFF22282A),
          surfaceContainerHighest: const Color(0xFF2A3133),
          onSurfaceVariant: const Color(0xFFBCC5C2),
          outline: const Color(0xFF596360),
          outlineVariant: const Color(0xFF343D3A),
          error: const Color(0xFFFFB4AB),
        )
      : base;

  final cardColor = isDark
      ? const Color(0xFF191E20)
      : scheme.surfaceContainerLow;
  final fieldColor = isDark
      ? const Color(0xFF181D1F)
      : scheme.surfaceContainerLow;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor:
        isDark ? const Color(0xFF101315) : scheme.surface,
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: isDark
            ? const BorderSide(color: Color(0xFF283032), width: 0.7)
            : BorderSide.none,
      ),
      color: cardColor,
    ),
    navigationBarTheme: NavigationBarThemeData(
      elevation: 0,
      backgroundColor:
          isDark ? const Color(0xFF15191B) : scheme.surfaceContainer,
      indicatorColor:
          isDark ? const Color(0xFF244B43) : scheme.secondaryContainer,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(color: scheme.onSurfaceVariant),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor:
          isDark ? const Color(0xFF15191B) : scheme.surfaceContainer,
      indicatorColor:
          isDark ? const Color(0xFF244B43) : scheme.secondaryContainer,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor:
          isDark ? const Color(0xFF1A1F21) : scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor:
          isDark ? const Color(0xFF171B1D) : scheme.surfaceContainerLow,
      modalBackgroundColor:
          isDark ? const Color(0xFF171B1D) : scheme.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: fieldColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: isDark
            ? const BorderSide(color: Color(0xFF2B3435), width: 0.8)
            : BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary, width: 1.4),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: isDark ? const Color(0xFF2B3234) : scheme.outlineVariant,
      thickness: 0.7,
    ),
  );
}
