import "package:flutter/material.dart";

/// Shared visual language for the POS.
///
/// Keeping the styling here makes the waiter, cashier and management views
/// feel like one product instead of a collection of separate screens.
class AppTheme {
  static const Color textPrimary = Color(0xFF162033);
  static const Color textMuted = Color(0xFF667085);
  static const Color bg = Color(0xFFF5F7FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSoft = Color(0xFFF8FAFC);
  static const Color border = Color(0xFFE6EAF0);
  static const Color primary = Color(0xFF0F9F6E);
  static const Color primaryDark = Color(0xFF087A53);
  static const Color secondary = Color(0xFF356AE6);
  static const Color danger = Color(0xFFD92D20);
  static const Color warning = Color(0xFFF79009);

  static const BorderRadius radius = BorderRadius.all(Radius.circular(16));
  static const BorderRadius compactRadius = BorderRadius.all(Radius.circular(12));

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFDDF8EC),
      onPrimaryContainer: primaryDark,
      secondary: secondary,
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFE8EEFF),
      error: danger,
      onError: Colors.white,
      surface: surface,
      onSurface: textPrimary,
      outline: border,
    );
    final textTheme = base.textTheme.apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
    ).copyWith(
      displayLarge: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: -1.2),
      displayMedium: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.8),
      headlineLarge: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
      headlineMedium: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.35),
      headlineSmall: const TextStyle(fontWeight: FontWeight.w800),
      titleLarge: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.2),
      titleMedium: const TextStyle(fontWeight: FontWeight.w700),
      titleSmall: const TextStyle(fontWeight: FontWeight.w700),
      bodyLarge: const TextStyle(height: 1.35),
      bodyMedium: const TextStyle(height: 1.35),
      labelLarge: const TextStyle(fontWeight: FontWeight.w700),
      labelMedium: const TextStyle(fontWeight: FontWeight.w700),
    );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bg,
      textTheme: textTheme,
      iconTheme: const IconThemeData(color: textPrimary),
      dividerTheme: const DividerThemeData(color: border, space: 1, thickness: 1),
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        elevation: 0,
        shadowColor: const Color(0xFF182230).withValues(alpha: 0.08),
        shape: const RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: border),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: radius),
        titleTextStyle: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.w800),
        contentTextStyle: TextStyle(color: textPrimary, fontSize: 14, height: 1.4),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        hintStyle: const TextStyle(color: textMuted, fontWeight: FontWeight.w500),
        labelStyle: const TextStyle(color: textMuted, fontWeight: FontWeight.w600),
        floatingLabelStyle: const TextStyle(color: primary, fontWeight: FontWeight.w700),
        enabledBorder: const OutlineInputBorder(
          borderRadius: compactRadius,
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: compactRadius,
          borderSide: BorderSide(color: primary, width: 1.7),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: compactRadius,
          borderSide: BorderSide(color: danger),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: compactRadius,
          borderSide: BorderSide(color: danger, width: 1.7),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFE1E7EF),
          disabledForegroundColor: textMuted,
          elevation: 0,
          minimumSize: const Size(52, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: const RoundedRectangleBorder(borderRadius: compactRadius),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: surface,
          foregroundColor: textPrimary,
          elevation: 0,
          minimumSize: const Size(52, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: const RoundedRectangleBorder(
            borderRadius: compactRadius,
            side: BorderSide(color: border),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          minimumSize: const Size(52, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          side: const BorderSide(color: border),
          shape: const RoundedRectangleBorder(borderRadius: compactRadius),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryDark,
          minimumSize: const Size(48, 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceSoft,
        selectedColor: const Color(0xFFDDF8EC),
        secondarySelectedColor: const Color(0xFFE8EEFF),
        disabledColor: const Color(0xFFF0F2F5),
        labelStyle: const TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
        side: const BorderSide(color: border),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      ),
      listTileTheme: const ListTileThemeData(
        minTileHeight: 56,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        iconColor: textMuted,
        shape: RoundedRectangleBorder(borderRadius: compactRadius),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        shape: StadiumBorder(),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Color(0xFF182230),
        contentTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: compactRadius),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: compactRadius),
      ),
      tooltipTheme: const TooltipThemeData(
        decoration: BoxDecoration(color: Color(0xFF182230), borderRadius: compactRadius),
        textStyle: TextStyle(color: Colors.white, fontSize: 12),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: primary),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        side: const BorderSide(color: textMuted),
      ),
    );
  }
}
