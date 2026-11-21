// Gene - Nov, 20, 2026: Modern Neumorphism ("Soft UI 2.0") light & dark theme system and design tokens for EIS.
import 'package:material_ui/material_ui.dart';

/// Semantic design tokens for the Soft Porcelain Light and Obsidian Slate Dark
/// neumorphic surfaces, directional highlights, and Philippine BIR compliance accents.
@immutable
class EisNeumorphicTokens extends ThemeExtension<EisNeumorphicTokens> {
  final Color canvas;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceRecessed;
  final Color shadowLight;
  final Color shadowDark;
  final Color borderHighlight;
  final Color borderSubtle;
  final Color accentPrimary;
  final Color accentSecondary;
  final Color success;
  final Color warning;
  final Color danger;
  final Color textPrimary;
  final Color textSecondary;

  const EisNeumorphicTokens({
    required this.canvas,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceRecessed,
    required this.shadowLight,
    required this.shadowDark,
    required this.borderHighlight,
    required this.borderSubtle,
    required this.accentPrimary,
    required this.accentSecondary,
    required this.success,
    required this.warning,
    required this.danger,
    required this.textPrimary,
    required this.textSecondary,
  });

  /// Soft Porcelain Light palette.
  static const light = EisNeumorphicTokens(
    canvas: Color(0xFFE8EEF5),
    surface: Color(0xFFEDF2F8),
    surfaceElevated: Color(0xFFF5F8FC),
    surfaceRecessed: Color(0xFFDDE5F0),
    shadowLight: Color(0xEBFFFFFF),
    shadowDark: Color(0xB8B8C5D8),
    borderHighlight: Color(0xCCFFFFFF),
    borderSubtle: Color(0xFFD0DAE8),
    accentPrimary: Color(0xFF0D7A6F),
    accentSecondary: Color(0xFF2563EB),
    success: Color(0xFF0F766E),
    warning: Color(0xFFD97706),
    danger: Color(0xFFDC2626),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
  );

  /// Obsidian Slate Dark palette.
  static const dark = EisNeumorphicTokens(
    canvas: Color(0xFF151A23),
    surface: Color(0xFF1B222E),
    surfaceElevated: Color(0xFF222B3A),
    surfaceRecessed: Color(0xFF11161F),
    shadowLight: Color(0xBF2B364A),
    shadowDark: Color(0xD9090C11),
    borderHighlight: Color(0x8C384760),
    borderSubtle: Color(0xE6263144),
    accentPrimary: Color(0xFF2DD4BF),
    accentSecondary: Color(0xFF60A5FA),
    success: Color(0xFF34D399),
    warning: Color(0xFFFBBF24),
    danger: Color(0xFFF87171),
    textPrimary: Color(0xFFF1F5F9),
    textSecondary: Color(0xFF94A3B8),
  );

  /// Safely resolves [EisNeumorphicTokens] from [context], falling back to the
  /// matching brightness preset in isolated widget tests.
  static EisNeumorphicTokens of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<EisNeumorphicTokens>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  @override
  EisNeumorphicTokens copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceElevated,
    Color? surfaceRecessed,
    Color? shadowLight,
    Color? shadowDark,
    Color? borderHighlight,
    Color? borderSubtle,
    Color? accentPrimary,
    Color? accentSecondary,
    Color? success,
    Color? warning,
    Color? danger,
    Color? textPrimary,
    Color? textSecondary,
  }) {
    return EisNeumorphicTokens(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceRecessed: surfaceRecessed ?? this.surfaceRecessed,
      shadowLight: shadowLight ?? this.shadowLight,
      shadowDark: shadowDark ?? this.shadowDark,
      borderHighlight: borderHighlight ?? this.borderHighlight,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      accentPrimary: accentPrimary ?? this.accentPrimary,
      accentSecondary: accentSecondary ?? this.accentSecondary,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
    );
  }

  @override
  EisNeumorphicTokens lerp(covariant EisNeumorphicTokens? other, double t) {
    if (other == null) return this;
    return EisNeumorphicTokens(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      surfaceRecessed: Color.lerp(surfaceRecessed, other.surfaceRecessed, t)!,
      shadowLight: Color.lerp(shadowLight, other.shadowLight, t)!,
      shadowDark: Color.lerp(shadowDark, other.shadowDark, t)!,
      borderHighlight: Color.lerp(borderHighlight, other.borderHighlight, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      accentPrimary: Color.lerp(accentPrimary, other.accentPrimary, t)!,
      accentSecondary: Color.lerp(accentSecondary, other.accentSecondary, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
    );
  }
}

/// Provides the modern Soft Porcelain Light and Obsidian Slate Dark Material 3
/// themes configured with [EisNeumorphicTokens].
class EisTheme {
  static ThemeData light() => _build(EisNeumorphicTokens.light, Brightness.light);

  static ThemeData dark() => _build(EisNeumorphicTokens.dark, Brightness.dark);

  static ThemeData _build(EisNeumorphicTokens tokens, Brightness brightness) {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: tokens.accentPrimary,
      brightness: brightness,
    );
    final scheme = baseScheme.copyWith(
      primary: tokens.accentPrimary,
      onPrimary: brightness == Brightness.dark ? const Color(0xFF042F2E) : Colors.white,
      secondary: tokens.accentSecondary,
      surface: tokens.canvas,
      surfaceContainerLowest: tokens.surfaceRecessed,
      surfaceContainerLow: tokens.surface,
      surfaceContainer: tokens.surface,
      surfaceContainerHigh: tokens.surfaceElevated,
      surfaceContainerHighest: tokens.surfaceElevated,
      onSurface: tokens.textPrimary,
      onSurfaceVariant: tokens.textSecondary,
      outline: tokens.borderSubtle,
      outlineVariant: tokens.borderSubtle,
      error: tokens.danger,
    );

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: tokens.borderSubtle),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: tokens.canvas,
      extensions: [tokens],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: tokens.textPrimary,
        titleTextStyle: TextStyle(
          color: tokens.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: tokens.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: tokens.borderHighlight),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surfaceRecessed,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: tokens.accentPrimary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: tokens.danger, width: 1.4),
        ),
        labelStyle: TextStyle(color: tokens.textSecondary, fontWeight: FontWeight.w500),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: BorderSide(color: tokens.borderSubtle),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          side: WidgetStatePropertyAll(BorderSide(color: tokens.borderSubtle)),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return tokens.accentPrimary;
            }
            return tokens.surfaceRecessed;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return scheme.onPrimary;
            }
            return tokens.textPrimary;
          }),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: tokens.surface,
        selectedColor: tokens.accentPrimary.withValues(alpha: 0.16),
        side: BorderSide(color: tokens.borderSubtle),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: TextStyle(
          color: tokens.textPrimary,
          fontWeight: FontWeight.w500,
          fontSize: 12.5,
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(tokens.surfaceRecessed),
        headingTextStyle: TextStyle(
          color: tokens.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
        ),
        dataTextStyle: TextStyle(
          color: tokens.textPrimary,
          fontSize: 13,
        ),
        dividerThickness: 0.75,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: tokens.borderHighlight),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      tabBarTheme: TabBarThemeData(
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: tokens.borderSubtle,
        indicator: BoxDecoration(
          color: tokens.accentPrimary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: tokens.accentPrimary.withValues(alpha: 0.3)),
        ),
        labelColor: tokens.accentPrimary,
        unselectedLabelColor: tokens.textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
      dividerTheme: DividerThemeData(
        color: tokens.borderSubtle,
        thickness: 1,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: tokens.accentPrimary.withValues(alpha: 0.14),
        selectedIconTheme: IconThemeData(color: tokens.accentPrimary),
        unselectedIconTheme: IconThemeData(color: tokens.textSecondary),
        selectedLabelTextStyle: TextStyle(
          color: tokens.accentPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: tokens.textSecondary,
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: tokens.accentPrimary.withValues(alpha: 0.14),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: tokens.accentPrimary);
          }
          return IconThemeData(color: tokens.textSecondary);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              color: tokens.accentPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
            );
          }
          return TextStyle(
            color: tokens.textSecondary,
            fontWeight: FontWeight.w500,
            fontSize: 11.5,
          );
        }),
      ),
    );
  }
}
