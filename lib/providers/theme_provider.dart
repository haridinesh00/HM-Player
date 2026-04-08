// lib/providers/theme_provider.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  // Dynamic palette extracted from current album art
  ColorScheme? _dynamicScheme;
  ColorScheme? get dynamicScheme => _dynamicScheme;

  Color get dominantColor =>
      _dynamicScheme?.primary ?? const Color(0xFF6750A4);
  Color get dominantSurface =>
      _dynamicScheme?.surface ?? const Color(0xFF1C1B1F);

  bool _useDynamicColor = true;
  bool get useDynamicColor => _useDynamicColor;

  ThemeProvider() {
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIdx = prefs.getInt('theme_mode') ?? 0;
    _themeMode = ThemeMode.values[modeIdx];
    _useDynamicColor = prefs.getBool('dynamic_color') ?? true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', mode.index);
    notifyListeners();
  }

  Future<void> toggleDynamicColor(bool value) async {
    _useDynamicColor = value;
    if (!value) {
      _dynamicScheme = null;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dynamic_color', value);
    notifyListeners();
  }

  // Called whenever the current song changes
  int _extractionId = 0; // debounce rapid changes

  Future<void> extractColorsFromArtwork({
    int? songId,
    int? albumId,
  }) async {
    final thisId = ++_extractionId;

    if (!_useDynamicColor) {
      _dynamicScheme = null;
      notifyListeners();
      return;
    }

    if (songId == null && albumId == null) {
      _dynamicScheme = null;
      notifyListeners();
      return;
    }

    try {
      final query = OnAudioQuery();
      Uint8List? artBytes;

      // Try song-level artwork first (ArtworkType.AUDIO with songId)
      if (songId != null) {
        artBytes = await query.queryArtwork(
          songId,
          ArtworkType.AUDIO,
          size: 200,
          quality: 80,
        );
        if (thisId != _extractionId) return;
      }

      // Fallback to album-level artwork
      if ((artBytes == null || artBytes.isEmpty) && albumId != null) {
        artBytes = await query.queryArtwork(
          albumId,
          ArtworkType.ALBUM,
          size: 200,
          quality: 80,
        );
        if (thisId != _extractionId) return;
      }

      if (artBytes == null || artBytes.isEmpty) {
        debugPrint('[DynamicColor] No artwork bytes for songId=$songId, albumId=$albumId');
        return; // Keep last valid scheme
      }

      final image = MemoryImage(artBytes);
      final palette = await PaletteGenerator.fromImageProvider(
        image,
        maximumColorCount: 16,
        timeout: const Duration(seconds: 5),
      );

      if (thisId != _extractionId) return;

      final dominant = palette.dominantColor?.color ??
          palette.vibrantColor?.color ??
          palette.mutedColor?.color;

      if (dominant == null) {
        debugPrint('[DynamicColor] No dominant color found in palette');
        return;
      }

      debugPrint('[DynamicColor] Extracted color: $dominant');

      _dynamicScheme = ColorScheme.fromSeed(
        seedColor: dominant,
        brightness: Brightness.dark,
      );
    } catch (e) {
      debugPrint('[DynamicColor] Error extracting colors: $e');
    }
    notifyListeners();
  }

  // ─── Material 3 themes ───────────────────────────────────────
  static ThemeData buildTheme({
    required Brightness brightness,
    Color seedColor = const Color(0xFF6750A4),
    ColorScheme? override,
  }) {
    final scheme = override ??
        ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: brightness,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: scheme.primaryContainer,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        thumbColor: scheme.primary,
        inactiveTrackColor: scheme.primary.withValues(alpha: 0.24),
        overlayColor: scheme.primary.withValues(alpha: 0.12),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: scheme.surfaceContainerHigh,
      ),
    );
  }
}
