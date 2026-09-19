import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Kikoeru-style Material: blue app bar over a grey ground, white elevated
/// cards with small radii, pill chips.
class AppTheme {
  AppTheme._();

  static const primary = Color(0xFF1976D2);
  static const secondary = Color(0xFF26A69A);
  static const accent = Color(0xFF9C27B0);
  static const price = Color(0xFFE53935);
  static const star = Color(0xFFFFB300);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final seeded = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
    );
    final colorScheme = seeded.copyWith(
      primary: dark ? const Color(0xFF64B5F6) : primary,
      onPrimary: dark ? const Color(0xFF0D2A4A) : Colors.white,
      secondary: secondary,
      onSecondary: Colors.white,
      tertiary: accent,
      surface: dark ? const Color(0xFF1D1D1D) : Colors.white,
      surfaceContainerLowest: dark ? const Color(0xFF121212) : Colors.white,
      surfaceContainerLow: dark ? const Color(0xFF1D1D1D) : Colors.white,
      surfaceContainer: dark
          ? const Color(0xFF242424)
          : const Color(0xFFF5F5F5),
      surfaceContainerHigh: dark
          ? const Color(0xFF2C2C2C)
          : const Color(0xFFEEEEEE),
      surfaceContainerHighest: dark
          ? const Color(0xFF333333)
          : const Color(0xFFE0E0E0),
      surfaceTint: Colors.transparent,
    );
    final ground = dark ? const Color(0xFF121212) : const Color(0xFFF0F0F0);
    final barColor = dark ? const Color(0xFF1D1D1D) : primary;
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: ground,
      canvasColor: ground,
      appBarTheme: AppBarTheme(
        backgroundColor: barColor,
        foregroundColor: Colors.white,
        elevation: 2,
        scrolledUnderElevation: 2,
        shadowColor: Colors.black54,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w500,
        ),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 2,
        shadowColor: Colors.black38,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerHighest,
        side: BorderSide.none,
        shape: const StadiumBorder(),
      ),
      // Plain lists read as white rows on the grey ground, like Kikoeru's.
      listTileTheme: ListTileThemeData(tileColor: colorScheme.surface),
      dividerTheme: DividerThemeData(
        color: dark ? Colors.white12 : Colors.black12,
        space: 1,
        thickness: 1,
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      navigationDrawerTheme: NavigationDrawerThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: primary.withValues(alpha: dark ? 0.3 : 0.12),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 14,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w400,
            color: states.contains(WidgetState.selected)
                ? colorScheme.primary
                : colorScheme.onSurface,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {TargetPlatform.iOS: CupertinoPageTransitionsBuilder()},
      ),
    );
  }
}
