import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Shared palette ────────────────────────────────────────────────
  static const Color primaryGreen  = Color(0xFFFB8500); // Mapped to Neon Orange for legacy
  static const Color lightGreen    = Color(0xFFFFB703);
  static const Color darkGreen     = Color(0xFFE85D04);

  // primaryBlue is an alias so legacy references compile unchanged
  static const Color primaryBlue   = Color(0xFFFB8500);
  static const Color lightBlue     = Color(0xFFFFB703);
  static const Color darkBlue      = Color(0xFFE85D04);

  static const Color warningOrange = Color(0xFF0077B6); // Tech Blue (as secondary)
  static const Color errorRed      = Color(0xFFEF4444);
  static const Color lightOrange   = Color(0xFFFFB703);
  static const Color primaryPurple = Color(0xFF6366F1);

  // ── Dark palette (default) ────────────────────────────────────────
  static const Color backgroundWhite = Color(0xFF0F1117); // dark scaffold
  static const Color backgroundGrey  = Color(0xFF1A1D27); // dark card
  static const Color textPrimary     = Color(0xFFFFFFFF);
  static const Color textSecondary   = Color(0xFF8B95A9);
  static const Color dividerColor    = Color(0xFF2A2D3A);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFB8500), Color(0xFFFFB703)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Dark theme ────────────────────────────────────────────────────
  static ThemeData get darkTheme => _buildTheme(Brightness.dark);

  // ── Light theme ───────────────────────────────────────────────────
  static ThemeData get lightTheme => _buildTheme(Brightness.light);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final Color scaffoldBg  = isDark ? const Color(0xFF0F1117) : const Color(0xFFF8FAFC);
    final Color cardBg      = isDark ? const Color(0xFF1A1D27) : const Color(0xFFFFFFFF);
    final Color divider     = isDark ? const Color(0xFF2A2D3A) : const Color(0xFFE2E8F0);
    final Color txtPrimary  = isDark ? const Color(0xFFFFFFFF) : const Color(0xFF0F172A);
    final Color txtSecond   = isDark ? const Color(0xFF8B95A9) : const Color(0xFF64748B);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        brightness: brightness,
        primary: primaryBlue,
        secondary: warningOrange, // Accent Tech Blue
        error: errorRed,
        surface: cardBg,
        onSurface: txtPrimary,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        ThemeData(brightness: brightness).textTheme,
      ),
      scaffoldBackgroundColor: scaffoldBg,

      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBg,
        foregroundColor: txtPrimary,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 20, fontWeight: FontWeight.w700, color: txtPrimary,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryBlue,
          side: const BorderSide(color: primaryBlue),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: divider),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryBlue, width: 2),
        ),
        filled: true,
        fillColor: cardBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        hintStyle: TextStyle(color: txtSecond),
        prefixIconColor: txtSecond,
        suffixIconColor: txtSecond,
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryBlue, foregroundColor: Colors.white,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: cardBg,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? const Color(0xFF2A2D3A) : const Color(0xFF1A1D27),
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),

      dividerTheme: DividerThemeData(color: divider),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardBg,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      listTileTheme: ListTileThemeData(
        tileColor: cardBg,
        textColor: txtPrimary,
        iconColor: txtSecond,
      ),
    );
  }

  // Stock status colours (unchanged)
  static Color stockStatusColor(String status) {
    switch (status) {
      case 'out': return errorRed;
      case 'low': return warningOrange;
      default:    return primaryBlue;
    }
  }
}

/// Context extension — use these instead of hardcoded AppTheme constants
/// so UI adapts correctly to both dark and light mode.
extension AppThemeColors on BuildContext {
  /// Card / container background (surface)
  Color get cardColor => Theme.of(this).colorScheme.surface;

  /// Main scaffold background
  Color get scaffoldColor => Theme.of(this).scaffoldBackgroundColor;

  /// Primary text colour
  Color get onSurface => Theme.of(this).colorScheme.onSurface;

  /// Secondary / muted text colour
  Color get subText => Theme.of(this).colorScheme.onSurface.withValues(alpha: 0.55);

  /// Divider / border colour
  Color get borderColor => Theme.of(this).dividerColor;

  /// Whether the current theme is dark
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
