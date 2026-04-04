import 'package:flutter/material.dart';

class FigmaPageTransitionsBuilder extends PageTransitionsBuilder {
  const FigmaPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.95, end: 1.0).animate(
          CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCirc,
          ),
        ),
        child: child,
      ),
    );
  }
}

class AppTheme {
  // Brand Colors
  static const Color americanWhite = Color(0xFFFFFFFF); // Gallery-White
  static const Color baseBlue = Color(0xFF1D2D44); // Deep American Blue
  static const Color americanRed = Color(0xFFB22234); // American Red
  static const Color textDark = Color(0xFF0F172A);
  static const Color textLight = Color(0xFF64748B);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: '.SF Pro Display', // Fallbacks to system sans-serif if not on Apple, giving a crisp native look
      scaffoldBackgroundColor: americanWhite,
      colorScheme: ColorScheme.light(
        primary: baseBlue,
        secondary: americanRed,
        background: americanWhite,
        surface: Colors.white,
        error: americanRed,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FigmaPageTransitionsBuilder(),
          TargetPlatform.iOS: FigmaPageTransitionsBuilder(),
          TargetPlatform.windows: FigmaPageTransitionsBuilder(),
          TargetPlatform.macOS: FigmaPageTransitionsBuilder(),
        },
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: baseBlue),
        titleTextStyle: TextStyle(
          color: baseBlue,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: baseBlue,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: baseBlue.withOpacity(0.3),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(color: textDark, fontWeight: FontWeight.w800, letterSpacing: -0.5),
        headlineMedium: TextStyle(color: textDark, fontWeight: FontWeight.w700, letterSpacing: -0.5),
        titleLarge: TextStyle(color: textDark, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: textDark, fontSize: 16),
        bodyMedium: TextStyle(color: textLight, fontSize: 14),
      ),
    );
  }
}
