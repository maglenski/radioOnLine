import 'package:flutter/material.dart';

import 'home_page.dart';

/// Nome que aparece para o usuário.
const appName = 'Sintonia';

class AppColors {
  static const background = Color(0xFF0B1220);
  static const surface = Color(0xFF141D2E);
  static const surfaceHigh = Color(0xFF1C2740);
  static const accent = Color(0xFFFFB020); // âmbar
  static const accentSoft = Color(0xFFFFD27A);
  static const live = Color(0xFFFF5A5F);
  static const textMuted = Color(0xFF8A97B0);
}

class RadioApp extends StatelessWidget {
  const RadioApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.accent,
      onPrimary: AppColors.background,
      secondary: AppColors.accentSoft,
      surface: AppColors.background,
      surfaceContainer: AppColors.surface,
      surfaceContainerHigh: AppColors.surfaceHigh,
    );

    return MaterialApp(
      title: appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.surface,
          indicatorColor: AppColors.accent.withValues(alpha: 0.18),
          iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
                color: s.contains(WidgetState.selected) ? AppColors.accent : AppColors.textMuted,
              )),
        ),
        sliderTheme: const SliderThemeData(
          activeTrackColor: AppColors.accent,
          thumbColor: AppColors.accent,
          inactiveTrackColor: AppColors.surfaceHigh,
          trackHeight: 4,
        ),
      ),
      home: const HomePage(),
    );
  }
}
