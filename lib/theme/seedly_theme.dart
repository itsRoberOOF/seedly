import 'package:flutter/material.dart';

/// Seedly's source palette mirrored from the Figma design system.
abstract final class SeedlyPalette {
  static const neutral = <int, Color>{
    50: Color(0xFFFFFFFF),
    100: Color(0xFFFAFAFA),
    150: Color(0xFFF7F7F7),
    200: Color(0xFFF2F2F2),
    300: Color(0xFFEEEEEE),
    400: Color(0xFFE1E1E1),
    500: Color(0xFFCACACA),
    600: Color(0xFF8E8E8E),
    700: Color(0xFF4B4B4B),
    800: Color(0xFF333333),
    850: Color(0xFF1F1F1F),
    900: Color(0xFF000000),
  };

  static const primary = <int, Color>{
    50: Color(0xFFD5DED7),
    100: Color(0xFFC9D4CC),
    150: Color(0xFFBCCBC0),
    200: Color(0xFFB0C1B5),
    300: Color(0xFF98AD9E),
    400: Color(0xFF7F9A87),
    500: Color(0xFF678670),
    600: Color(0xFF546D5B),
    700: Color(0xFF415446),
    800: Color(0xFF2E3C32),
    850: Color(0xFF242F27),
    900: Color(0xFF1B231D),
  };

  static const secondary = <int, Color>{
    50: Color(0xFFFBF8F3),
    100: Color(0xFFF8F4EC),
    150: Color(0xFFF6EFE5),
    200: Color(0xFFF4EBDE),
    300: Color(0xFFEFE3D1),
    400: Color(0xFFEBDAC3),
    500: Color(0xFFE6D2B5),
    600: Color(0xFFE1CAA7),
    700: Color(0xFFDDC199),
    800: Color(0xFFD8B98C),
    850: Color(0xFFD6B585),
    900: Color(0xFFD4B07E),
  };

  static const success = <int, Color>{
    50: Color(0xFFFBFEFC),
    100: Color(0xFFF2FAF6),
    200: Color(0xFFE5F5EC),
    300: Color(0xFFC0E5D1),
    400: Color(0xFF97D4B4),
    500: Color(0xFF6BC497),
    600: Color(0xFF47B881),
    700: Color(0xFF0C9D61),
  };

  static const warning = <int, Color>{
    50: Color(0xFFFFFDFA),
    100: Color(0xFFFFF9EE),
    200: Color(0xFFFFF7E1),
    300: Color(0xFFFFEAB3),
    400: Color(0xFFFFDD82),
    500: Color(0xFFFFC62B),
    600: Color(0xFFFFAD0D),
    700: Color(0xFFFE9B0E),
  };

  static const danger = <int, Color>{
    50: Color(0xFFFFFBFB),
    100: Color(0xFFFEF2F2),
    200: Color(0xFFFFEBEE),
    300: Color(0xFFFFCCD2),
    400: Color(0xFFF49898),
    500: Color(0xFFEB6F70),
    600: Color(0xFFF64C4C),
    700: Color(0xFFEC2D30),
  };

  static const info = <int, Color>{
    50: Color(0xFFF8FCFF),
    100: Color(0xFFF1F8FF),
    200: Color(0xFFE4F2FF),
    300: Color(0xFFBDDDFF),
    400: Color(0xFF93C8FF),
    500: Color(0xFF4BA1FF),
    600: Color(0xFF3B82F6),
    700: Color(0xFF3A70E2),
  };

  /// Figma "Text Color/text-secondary-dark", used for alert messages.
  static const Color textSecondaryDark = Color(0xFF535353);
  static const Color border = Color(0xFFEEEEEE);
  static const Color focus = Color(0xFF7F9A87);
  static const Color shadow = Color(0x1F000000);
}

/// Figma's drop shadows. Figma applies each effect twice, so they are
/// stacked twice here too.
abstract final class SeedlyShadows {
  static const _card = BoxShadow(
    color: SeedlyPalette.shadow,
    offset: Offset(0, 2),
    blurRadius: 4,
    spreadRadius: -2,
  );
  static const _tag = BoxShadow(
    color: SeedlyPalette.shadow,
    offset: Offset(0, 6),
    blurRadius: 8,
    spreadRadius: -6,
  );
  static const _floating = BoxShadow(
    color: SeedlyPalette.shadow,
    offset: Offset(0, 8),
    blurRadius: 28,
    spreadRadius: -6,
  );

  /// Cards, inputs, segment controls and avatars.
  static const card = [_card, _card];

  /// Tags (chips).
  static const tag = [_tag, _tag];

  /// Small buttons floating over other content, like the avatar's edit.
  static const floating = [_floating, _floating];
}

/// Figma spacing and radius scales for custom Seedly widgets.
abstract final class SeedlyMetrics {
  static const spacing = <String, double>{
    '4xs': 2,
    '3xs': 4,
    '2xs': 6,
    'xs': 8,
    'sm': 12,
    'md': 16,
    'lg': 20,
    'xl': 24,
    '2xl': 32,
    '3xl': 40,
    '4xl': 48,
    '5xl': 64,
    '6xl': 100,
    '7xl': 120,
  };

  static const radii = <String, double>{
    'xs': 4,
    'sm': 8,
    'md': 12,
    'lg': 16,
    'xl': 24,
    'full': 999,
  };
}

abstract final class SeedlyTheme {
  static const fontFamily = 'Plus Jakarta Sans';
  static const logoFontFamily = 'Denk One';

  static const logoTextStyle = TextStyle(
    fontFamily: logoFontFamily,
    fontSize: 32,
    color: Color(0xFF678670),
  );

  static final ColorScheme _colorScheme =
      ColorScheme.fromSeed(
        seedColor: SeedlyPalette.primary[500]!,
        brightness: Brightness.light,
      ).copyWith(
        // White on this 600 tone has a 5.65:1 contrast ratio.
        primary: SeedlyPalette.primary[600],
        onPrimary: SeedlyPalette.neutral[50],
        primaryContainer: SeedlyPalette.primary[50],
        onPrimaryContainer: SeedlyPalette.primary[900],
        secondary: SeedlyPalette.secondary[500],
        onSecondary: SeedlyPalette.neutral[850],
        secondaryContainer: SeedlyPalette.secondary[50],
        onSecondaryContainer: SeedlyPalette.neutral[800],
        error: SeedlyPalette.danger[600],
        onError: SeedlyPalette.neutral[50],
        errorContainer: SeedlyPalette.danger[100],
        onErrorContainer: SeedlyPalette.danger[700],
        surface: SeedlyPalette.neutral[100],
        onSurface: SeedlyPalette.neutral[850],
        surfaceContainerLowest: SeedlyPalette.neutral[50],
        surfaceContainerLow: SeedlyPalette.neutral[100],
        surfaceContainer: SeedlyPalette.neutral[150],
        surfaceContainerHigh: SeedlyPalette.neutral[200],
        surfaceContainerHighest: SeedlyPalette.neutral[200],
        onSurfaceVariant: SeedlyPalette.neutral[700],
        outline: SeedlyPalette.neutral[300],
        outlineVariant: SeedlyPalette.neutral[200],
        shadow: SeedlyPalette.shadow,
        surfaceTint: SeedlyPalette.primary[600],
      );

  static final TextTheme _textTheme =
      TextTheme(
        displayLarge: _textStyle(48, 58, FontWeight.w700, letterSpacing: 2),
        displayMedium: _textStyle(40, 48, FontWeight.w700, letterSpacing: 2),
        displaySmall: _textStyle(32, 38, FontWeight.w700, letterSpacing: 2),
        headlineLarge: _textStyle(28, 34, FontWeight.w600, letterSpacing: 2),
        headlineMedium: _textStyle(24, 28, FontWeight.w500, letterSpacing: 2),
        headlineSmall: _textStyle(18, 28, FontWeight.w600),
        titleLarge: _textStyle(18, 28, FontWeight.w600),
        titleMedium: _textStyle(16, 24, FontWeight.w600),
        titleSmall: _textStyle(14, 20, FontWeight.w600),
        bodyLarge: _textStyle(16, 24, FontWeight.w400),
        bodyMedium: _textStyle(14, 20, FontWeight.w400),
        bodySmall: _textStyle(12, 16, FontWeight.w400),
        labelLarge: _textStyle(14, 20, FontWeight.w600),
        labelMedium: _textStyle(12, 16, FontWeight.w500),
        labelSmall: _textStyle(10, 14, FontWeight.w500),
      ).apply(
        bodyColor: SeedlyPalette.neutral[850],
        displayColor: SeedlyPalette.neutral[850],
      );

  static final ThemeData light = ThemeData(
    useMaterial3: true,
    colorScheme: _colorScheme,
    fontFamily: fontFamily,
    textTheme: _textTheme,
    scaffoldBackgroundColor: SeedlyPalette.neutral[100],
    canvasColor: SeedlyPalette.neutral[100],
    dividerColor: SeedlyPalette.border,
    focusColor: SeedlyPalette.focus,
    splashColor: SeedlyPalette.primary[500]!.withValues(alpha: 0.10),
    highlightColor: SeedlyPalette.primary[500]!.withValues(alpha: 0.06),
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    appBarTheme: AppBarTheme(
      backgroundColor: SeedlyPalette.neutral[100],
      foregroundColor: SeedlyPalette.neutral[850],
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 1,
      titleTextStyle: _textStyle(
        18,
        28,
        FontWeight.w600,
      ).copyWith(color: SeedlyPalette.neutral[850]),
    ),
    cardTheme: CardThemeData(
      color: SeedlyPalette.neutral[50],
      surfaceTintColor: Colors.transparent,
      shadowColor: SeedlyPalette.shadow,
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SeedlyMetrics.radii['lg']!),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: _buttonStyle(
        background: SeedlyPalette.primary[600]!,
        foreground: SeedlyPalette.neutral[50]!,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: _buttonStyle(
        background: SeedlyPalette.primary[600]!,
        foreground: SeedlyPalette.neutral[50]!,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: _buttonStyle(
        background: Colors.transparent,
        foreground: SeedlyPalette.primary[700]!,
        side: const BorderSide(color: SeedlyPalette.border),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: _buttonStyle(
        background: Colors.transparent,
        foreground: SeedlyPalette.primary[700]!,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: SeedlyPalette.primary[600],
      foregroundColor: SeedlyPalette.neutral[50],
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SeedlyMetrics.radii['md']!),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: SeedlyPalette.neutral[50],
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      labelStyle: _textStyle(
        14,
        20,
        FontWeight.w400,
      ).copyWith(color: SeedlyPalette.neutral[700]),
      hintStyle: _textStyle(
        14,
        20,
        FontWeight.w400,
      ).copyWith(color: SeedlyPalette.neutral[700]),
      errorStyle: _textStyle(
        12,
        16,
        FontWeight.w500,
      ).copyWith(color: SeedlyPalette.danger[600]),
      border: _inputBorder(SeedlyPalette.border),
      enabledBorder: _inputBorder(SeedlyPalette.border),
      focusedBorder: _inputBorder(SeedlyPalette.focus, width: 1.5),
      errorBorder: _inputBorder(SeedlyPalette.danger[600]!),
      focusedErrorBorder: _inputBorder(SeedlyPalette.danger[600]!, width: 1.5),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: SeedlyPalette.neutral[50],
      selectedColor: SeedlyPalette.primary[50],
      disabledColor: SeedlyPalette.neutral[200],
      secondarySelectedColor: SeedlyPalette.secondary[100],
      labelStyle: _textStyle(12, 16, FontWeight.w500),
      side: const BorderSide(color: SeedlyPalette.border),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SeedlyMetrics.radii['sm']!),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      showCheckmark: false,
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      side: const BorderSide(color: Color(0xFF8E8E8E)),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return SeedlyPalette.primary[600];
        }
        return SeedlyPalette.neutral[600];
      }),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return SeedlyPalette.neutral[50];
        }
        return SeedlyPalette.neutral[100];
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return SeedlyPalette.primary[600];
        }
        return SeedlyPalette.neutral[400];
      }),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: SeedlyPalette.neutral[50],
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SeedlyMetrics.radii['lg']!),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: SeedlyPalette.neutral[50],
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(SeedlyMetrics.radii['xl']!),
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: SeedlyPalette.neutral[50],
      surfaceTintColor: Colors.transparent,
      indicatorColor: SeedlyPalette.primary[50],
      elevation: 1,
      labelTextStyle: WidgetStatePropertyAll(
        _textStyle(12, 16, FontWeight.w500),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: SeedlyPalette.primary[600],
      linearTrackColor: SeedlyPalette.primary[150],
      circularTrackColor: SeedlyPalette.primary[150],
      linearMinHeight: 8,
    ),
    dividerTheme: const DividerThemeData(
      color: SeedlyPalette.border,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: SeedlyPalette.neutral[800],
      contentTextStyle: _textStyle(
        14,
        20,
        FontWeight.w400,
      ).copyWith(color: SeedlyPalette.neutral[50]),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SeedlyMetrics.radii['sm']!),
      ),
    ),
  );

  static TextStyle _textStyle(
    double size,
    double lineHeight,
    FontWeight weight, {
    double letterSpacing = 0,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      height: lineHeight / size,
      fontWeight: weight,
      letterSpacing: letterSpacing,
    );
  }

  static ButtonStyle _buttonStyle({
    required Color background,
    required Color foreground,
    BorderSide? side,
  }) {
    return ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      textStyle: WidgetStatePropertyAll(_textStyle(14, 20, FontWeight.w600)),
      backgroundColor: WidgetStatePropertyAll(background),
      foregroundColor: WidgetStatePropertyAll(foreground),
      side: side == null ? null : WidgetStatePropertyAll(side),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SeedlyMetrics.radii['md']!),
        ),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(SeedlyMetrics.radii['sm']!),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
