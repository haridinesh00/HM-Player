// lib/app.dart
import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart'; // To access your global 'audioHandler'
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';

class MusicPlayerApp extends StatefulWidget {
  const MusicPlayerApp({super.key});

  static const _seed = Color(0xFF6750A4);

  @override
  State<MusicPlayerApp> createState() => _MusicPlayerAppState();
}

class _MusicPlayerAppState extends State<MusicPlayerApp> {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  // Store system Material You colors once fetched
  ColorScheme? _systemLightScheme;
  ColorScheme? _systemDarkScheme;

  @override
  void initState() {
    super.initState();
    _initAppLinks();
    _loadSystemColors();
  }

  Future<void> _loadSystemColors() async {
    try {
      // Use the dynamic_color package utility to get system colors
      final corePalette = await DynamicColorPlugin.getCorePalette();
      if (corePalette != null) {
        setState(() {
          _systemLightScheme = corePalette.toColorScheme(brightness: Brightness.light);
          _systemDarkScheme = corePalette.toColorScheme(brightness: Brightness.dark);
        });
      } else {
        // Try accent color fallback
        final accentColor = await DynamicColorPlugin.getAccentColor();
        if (accentColor != null) {
          setState(() {
            _systemLightScheme = ColorScheme.fromSeed(
              seedColor: accentColor,
              brightness: Brightness.light,
            );
            _systemDarkScheme = ColorScheme.fromSeed(
              seedColor: accentColor,
              brightness: Brightness.dark,
            );
          });
        }
      }
    } catch (e) {
      debugPrint('[DynamicColor] Failed to load system colors: $e');
    }
  }

  Future<void> _initAppLinks() async {
    _appLinks = AppLinks();

    // SCENARIO 1: App is completely closed (Cold Start)
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        audioHandler.playFromUri(initialUri);
      }
    } catch (e) {
      debugPrint('Error handling initial link: $e');
    }

    // SCENARIO 2: App is already running in the background
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      audioHandler.playFromUri(uri);
    });
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    ColorScheme lightScheme;
    ColorScheme darkScheme;

    // When artwork-derived dynamic colors are available, use those
    if (themeProvider.useDynamicColor && themeProvider.dynamicScheme != null) {
      final seed = themeProvider.dynamicScheme!.primary;
      debugPrint('[DynamicColor] Building theme with artwork seed: $seed');
      lightScheme = ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.light,
      );
      darkScheme = ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.dark,
      );
    } else {
      // Fall back to system Material You colors or default seed
      lightScheme = _systemLightScheme ??
          ColorScheme.fromSeed(
            seedColor: MusicPlayerApp._seed,
            brightness: Brightness.light,
          );
      darkScheme = _systemDarkScheme ??
          ColorScheme.fromSeed(
            seedColor: MusicPlayerApp._seed,
            brightness: Brightness.dark,
          );
    }

    return MaterialApp(
      title: 'HM Player',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      theme: ThemeProvider.buildTheme(
        brightness: Brightness.light,
        override: lightScheme,
      ),
      darkTheme: ThemeProvider.buildTheme(
        brightness: Brightness.dark,
        override: darkScheme,
      ),
      home: const HomeScreen(),
    );
  }
}