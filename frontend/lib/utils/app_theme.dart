// lib/utils/app_theme.dart
// Theme: "Midnight Feast"
// Dark premium base (Image 4) + vibrant food accent cards (Image 3)
// + clean rounded typography (Image 6) + fresh greens (Image 1)
// Font: Nunito — rounded, warm, food-forward
//
// Palette:
//   Primary   — Flame Orange   #FF6B35
//   Accent1   — Rose Coral     #FF8C69
//   Accent2   — Golden Saffron #FFB347
//   Accent3   — Lime Fresh     #7ED957
//   Accent4   — Violet         #9B59B6
//   Surface   — Deep Ink       #0F1218
//   Card      — Glass Slate    #181E2C
//   Glass     — Frosted White  8–12% opacity

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {

  // ── Core palette ───────────────────────────────────────────────────────────
  static const Color primary      = Color(0xFFFF6B35);
  static const Color primaryLight = Color(0xFFFF8C69);
  static const Color saffron      = Color(0xFFFFB347);
  static const Color lime         = Color(0xFF7ED957);
  static const Color violet       = Color(0xFF9B59B6);

  // ── Surfaces ───────────────────────────────────────────────────────────────
  static const Color bgDeep    = Color(0xFF0F1218);
  static const Color bgCard    = Color(0xFF181E2C);
  static const Color bgCardAlt = Color(0xFF1E2535);
  static const Color bgGlass   = Color(0x14FFFFFF);

  // ── Borders ────────────────────────────────────────────────────────────────
  static const Color glassStroke = Color(0x20FFFFFF);

  // ── Text ───────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xB3FFFFFF);
  static const Color textMuted     = Color(0x66FFFFFF);
  static const Color textDim       = Color(0x40FFFFFF);

  // ── Legacy aliases ─────────────────────────────────────────────────────────
  static const Color primaryOrange = primary;
  static const Color darkNavy      = bgDeep;
  static const Color cardDark      = bgCard;

  // ── Helpers ────────────────────────────────────────────────────────────────
  static Color scoreColor(double score) {
    if (score >= 0.7)  return lime;
    if (score >= 0.45) return saffron;
    return primary;
  }

  static BoxDecoration glassCard({
    Color? tintColor,
    double radius = 20,
    bool glow = false,
  }) => BoxDecoration(
    color: tintColor != null ? tintColor.withOpacity(0.07) : bgGlass,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: tintColor != null
          ? tintColor.withOpacity(0.25)
          : glassStroke,
      width: 1,
    ),
    boxShadow: glow && tintColor != null
        ? [BoxShadow(color: tintColor.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 6))]
        : [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 4))],
  );

  static BoxDecoration premiumCard({Color? accentColor, double radius = 20}) =>
      BoxDecoration(
        gradient: LinearGradient(
          colors: [bgCard, accentColor != null ? accentColor.withOpacity(0.08) : bgCardAlt],
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: accentColor != null ? accentColor.withOpacity(0.2) : glassStroke,
          width: 1,
        ),
      );

  // ── Typography: Nunito ─────────────────────────────────────────────────────
  static TextTheme get _darkText =>
      GoogleFonts.nunitoTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge:  GoogleFonts.nunito(fontSize: 34, fontWeight: FontWeight.w900, color: textPrimary, letterSpacing: -1),
        displayMedium: GoogleFonts.nunito(fontSize: 28, fontWeight: FontWeight.w800, color: textPrimary, letterSpacing: -0.5),
        displaySmall:  GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w700, color: textPrimary),
        titleLarge:    GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w700, color: textPrimary),
        titleMedium:   GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary),
        titleSmall:    GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600, color: textSecondary),
        bodyLarge:     GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w500, color: textSecondary, height: 1.5),
        bodyMedium:    GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w400, color: textSecondary, height: 1.5),
        bodySmall:     GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w400, color: textMuted),
        labelLarge:    GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w800, color: textPrimary, letterSpacing: 0.2),
        labelMedium:   GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: textSecondary),
        labelSmall:    GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w600, color: textMuted, letterSpacing: 0.5),
      );

  static TextTheme get _lightText =>
      GoogleFonts.nunitoTextTheme(ThemeData.light().textTheme);

  // ── Color scheme ───────────────────────────────────────────────────────────
  static const ColorScheme _darkScheme = ColorScheme(
    brightness:              Brightness.dark,
    primary:                 primary,
    onPrimary:               Colors.white,
    primaryContainer:        Color(0x28FF6B35),
    onPrimaryContainer:      primaryLight,
    secondary:               saffron,
    onSecondary:             Color(0xFF1A0E00),
    secondaryContainer:      Color(0x28FFB347),
    onSecondaryContainer:    saffron,
    tertiary:                lime,
    onTertiary:              Color(0xFF0A1800),
    tertiaryContainer:       Color(0x207ED957),
    onTertiaryContainer:     lime,
    error:                   Color(0xFFFF5252),
    onError:                 Colors.white,
    errorContainer:          Color(0x28FF5252),
    onErrorContainer:        Color(0xFFFF8A80),
    surface:                 bgCard,
    onSurface:               textPrimary,
    surfaceContainerHighest: bgCardAlt,
    outline:                 glassStroke,
    outlineVariant:          Color(0x14FFFFFF),
    shadow:                  Colors.black,
    scrim:                   Color(0x99000000),
    inverseSurface:          Color(0xFFE8EAF0),
    onInverseSurface:        bgDeep,
    inversePrimary:          Color(0xFFBF4018),
  );

  // ══════════════════════════════════════════════════════════════════════════
  // DARK THEME — "Midnight Feast"
  // ══════════════════════════════════════════════════════════════════════════
  static ThemeData get darkTheme => ThemeData(
    useMaterial3:            true,
    brightness:              Brightness.dark,
    colorScheme:             _darkScheme,
    scaffoldBackgroundColor: bgDeep,
    textTheme:               _darkText,

    appBarTheme: AppBarTheme(
      backgroundColor:        bgDeep,
      foregroundColor:        textPrimary,
      elevation:              0,
      scrolledUnderElevation: 0,
      centerTitle:            false,
      surfaceTintColor:       Colors.transparent,
      titleTextStyle: GoogleFonts.nunito(
        color: textPrimary, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3,
      ),
      iconTheme:        const IconThemeData(color: textPrimary, size: 22),
      actionsIconTheme: const IconThemeData(color: textSecondary, size: 22),
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: bgCard,
      indicatorColor:  primary.withOpacity(0.15),
      elevation:       0,
      height:          64,
      labelBehavior:   NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith((s) {
        final on = s.contains(WidgetState.selected);
        return GoogleFonts.nunito(
          fontSize: 10,
          fontWeight: on ? FontWeight.w800 : FontWeight.w500,
          color: on ? primary : textMuted,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((s) {
        final on = s.contains(WidgetState.selected);
        return IconThemeData(color: on ? primary : textMuted, size: 22);
      }),
    ),

    cardTheme: CardThemeData(
      color:            bgCard,
      elevation:        0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: glassStroke, width: 1),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    ),

    chipTheme: ChipThemeData(
      backgroundColor:     bgGlass,
      selectedColor:       primary.withOpacity(0.18),
      checkmarkColor:      primary,
      labelStyle:          GoogleFonts.nunito(color: textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
      secondaryLabelStyle: GoogleFonts.nunito(color: primary, fontSize: 12, fontWeight: FontWeight.w700),
      side: const BorderSide(color: glassStroke, width: 1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.disabled)) return primary.withOpacity(0.3);
          if (s.contains(WidgetState.pressed))  return const Color(0xFFE05A28);
          return primary;
        }),
        foregroundColor: WidgetStateProperty.all(Colors.white),
        textStyle:       WidgetStateProperty.all(
          GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.2),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        padding:       WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 28, vertical: 16)),
        elevation:     WidgetStateProperty.all(0),
        overlayColor:  WidgetStateProperty.all(Colors.white.withOpacity(0.10)),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.all(primary),
        side: WidgetStateProperty.all(const BorderSide(color: primary, width: 1.5)),
        textStyle: WidgetStateProperty.all(
          GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.all(primary),
        textStyle: WidgetStateProperty.all(
          GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
      ),
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor:    primary,
      foregroundColor:    Colors.white,
      elevation:          0,
      focusElevation:     0,
      hoverElevation:     0,
      highlightElevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      extendedTextStyle: GoogleFonts.nunito(
        fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white,
      ),
      extendedPadding: const EdgeInsets.symmetric(horizontal: 24),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled:          true,
      fillColor:       bgGlass,
      hintStyle:       GoogleFonts.nunito(color: textMuted, fontSize: 14, fontWeight: FontWeight.w500),
      prefixIconColor: textMuted,
      suffixIconColor: textMuted,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide:   const BorderSide(color: glassStroke, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide:   const BorderSide(color: glassStroke, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide:   const BorderSide(color: primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide:   const BorderSide(color: Color(0xFFFF5252), width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: bgCardAlt,
      contentTextStyle: GoogleFonts.nunito(
        color: textPrimary, fontSize: 13, fontWeight: FontWeight.w600,
      ),
      actionTextColor: primary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: glassStroke, width: 1),
      ),
      behavior:     SnackBarBehavior.floating,
      elevation:    0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),

    progressIndicatorTheme: ProgressIndicatorThemeData(
      color:              primary,
      linearTrackColor:   primary.withOpacity(0.12),
      circularTrackColor: primary.withOpacity(0.12),
      linearMinHeight:    5,
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor:      bgCard,
      modalBackgroundColor: bgCard,
      surfaceTintColor:     Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        side: BorderSide(color: glassStroke, width: 1),
      ),
      elevation:       0,
      modalElevation:  0,
      dragHandleColor: textMuted,
      dragHandleSize:  Size(40, 4),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor:  bgCard,
      surfaceTintColor: Colors.transparent,
      elevation:        0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: const BorderSide(color: glassStroke, width: 1),
      ),
      titleTextStyle: GoogleFonts.nunito(
        color: textPrimary, fontSize: 20, fontWeight: FontWeight.w800,
      ),
      contentTextStyle: GoogleFonts.nunito(
        color: textSecondary, fontSize: 14, fontWeight: FontWeight.w500,
      ),
    ),

    tabBarTheme: TabBarThemeData(
      indicatorColor:       primary,
      indicatorSize:        TabBarIndicatorSize.label,
      dividerColor:         Colors.transparent,
      labelColor:           primary,
      unselectedLabelColor: textMuted,
      labelStyle:           GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w800),
      unselectedLabelStyle: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w500),
    ),

    dividerTheme: const DividerThemeData(
      color: glassStroke, thickness: 1, space: 1,
    ),

    listTileTheme: ListTileThemeData(
      tileColor: Colors.transparent,
      titleTextStyle:    GoogleFonts.nunito(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
      subtitleTextStyle: GoogleFonts.nunito(color: textMuted, fontSize: 12),
      iconColor:         textMuted,
      contentPadding:    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),

    iconTheme:        const IconThemeData(color: textSecondary, size: 22),
    primaryIconTheme: const IconThemeData(color: textPrimary, size: 22),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? Colors.white : textMuted),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? primary : bgGlass),
    ),
  );

  // ══════════════════════════════════════════════════════════════════════════
  // LIGHT THEME (system fallback — clean, like Image 1 / Image 2)
  // ══════════════════════════════════════════════════════════════════════════
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor:  primary,
      brightness: Brightness.light,
      primary:    primary,
      secondary:  saffron,
      tertiary:   lime,
    ),
    scaffoldBackgroundColor: const Color(0xFFF5F5F0),
    textTheme: _lightText,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF1A1A2E),
      elevation:       0,
      centerTitle:     false,
      titleTextStyle:  GoogleFonts.nunito(
        color: const Color(0xFF1A1A2E),
        fontSize: 18, fontWeight: FontWeight.w800,
      ),
    ),
    cardTheme: CardThemeData(
      color:     Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.black.withOpacity(0.06), width: 1),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation:       0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
    ),
  );
}