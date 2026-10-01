import 'package:flutter/material.dart';

/// Design tokens. One calm accent; colour is otherwise reserved for status.
class AppColors {
  AppColors._();

  static const background = Color(0xFF0A0C0F);
  static const surface = Color(0xFF111418);
  static const surface2 = Color(0xFF171B21);
  static const surface3 = Color(0xFF1F242B);
  static const border = Color(0xFF232931);
  static const borderStrong = Color(0xFF2F3640);

  static const text = Color(0xFFECEEF1);
  static const text2 = Color(0xFFA1A9B4);
  static const text3 = Color(0xFF6B7480);

  static const accent = Color(0xFF4C8BF5);
  static const onAccent = Color(0xFFFFFFFF);
  static const success = Color(0xFF2FBF71);
  static const warning = Color(0xFFF5A524);
  static const danger = Color(0xFFF04848);

  /// Robot body colour in the robot views.
  static const robot = Color(0xFFE8B931);
  static const viewport = Color(0xFF0D1014);
  static const gridMinor = Color(0xFF161A20);
  static const gridMajor = Color(0xFF222830);
}

/// Type scale. Inter throughout; capitals only for small overlines.
class AppText {
  AppText._();

  static const _base = TextStyle(fontFamily: 'Inter', color: AppColors.text, height: 1.3);
  static const _tabular = [FontFeature.tabularFigures()];

  static final display = _base.copyWith(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.6, height: 1.15);
  static final title = _base.copyWith(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.2);
  static final body = _base.copyWith(fontSize: 15, fontWeight: FontWeight.w400);
  static final bodyStrong = _base.copyWith(fontSize: 15, fontWeight: FontWeight.w500);
  static final label = _base.copyWith(fontSize: 13, fontWeight: FontWeight.w500);
  static final caption = _base.copyWith(fontSize: 12.5, fontWeight: FontWeight.w400, color: AppColors.text2);
  static final overline = _base.copyWith(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.9,
    color: AppColors.text3,
  );
  static final metric = _base.copyWith(
    fontSize: 30,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.8,
    height: 1.1,
    fontFeatures: _tabular,
  );
  static final mono = _base.copyWith(fontSize: 13, fontWeight: FontWeight.w500, fontFeatures: _tabular);
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: AppColors.accent,
      onPrimary: AppColors.onAccent,
      secondary: AppColors.accent,
      onSecondary: AppColors.onAccent,
      tertiary: AppColors.warning,
      error: AppColors.danger,
      surface: AppColors.background,
      onSurface: AppColors.text,
      onSurfaceVariant: AppColors.text2,
      surfaceContainerLowest: AppColors.background,
      surfaceContainerLow: AppColors.surface,
      surfaceContainer: AppColors.surface,
      surfaceContainerHigh: AppColors.surface2,
      surfaceContainerHighest: AppColors.surface3,
      outline: AppColors.borderStrong,
      outlineVariant: AppColors.border,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppText.display,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.accent.withValues(alpha: 0.16),
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => AppText.label.copyWith(
            fontSize: 12,
            color: s.contains(WidgetState.selected) ? AppColors.text : AppColors.text3,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(size: 22, color: s.contains(WidgetState.selected) ? AppColors.accent : AppColors.text3),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1, space: 1),
      sliderTheme: SliderThemeData(
        trackHeight: 4,
        activeTrackColor: AppColors.accent,
        inactiveTrackColor: AppColors.surface3,
        thumbColor: AppColors.text,
        overlayShape: SliderComponentShape.noOverlay,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9, elevation: 2),
        tickMarkShape: SliderTickMarkShape.noTickMark,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.onAccent : AppColors.text2,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.accent : AppColors.surface3,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: AppColors.borderStrong,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface2,
        surfaceTintColor: Colors.transparent,
        textStyle: AppText.body,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppText.title.copyWith(fontSize: 19),
        contentTextStyle: AppText.body.copyWith(color: AppColors.text2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surface3,
        contentTextStyle: AppText.bodyStrong,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: AppColors.surface3, borderRadius: BorderRadius.circular(8)),
        textStyle: AppText.label,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
        linearTrackColor: AppColors.surface3,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface2,
        labelStyle: AppText.body.copyWith(color: AppColors.text2),
        floatingLabelStyle: AppText.label.copyWith(color: AppColors.accent),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
      ),
    );
  }
}
