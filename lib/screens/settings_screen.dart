// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:music_player/screens/folder_settings_screen.dart';
import 'package:provider/provider.dart';

import '../providers/library_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/equalizer_widget.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final lib = context.read<LibraryProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        children: [
          // ── Appearance ────────────────────────────────────────
          const _SectionHeader('Appearance'),
          ListTile(
            leading: const Icon(Icons.dark_mode_outlined),
            title: const Text('Theme'),
            subtitle: Text(_themeName(theme.themeMode)),
            onTap: () => _showThemePicker(context, theme),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.palette_outlined),
            title: const Text('Dynamic color from artwork'),
            subtitle: const Text('Extract accent colors from album art'),
            value: theme.useDynamicColor,
            onChanged: theme.toggleDynamicColor,
          ),

          // ── Library ───────────────────────────────────────────
          const _SectionHeader('Library'),
          ListTile(
            leading: const Icon(Icons.refresh_rounded),
            title: const Text('Rescan library'),
            subtitle: Text('${lib.songs.length} songs found'),
            onTap: () {
              lib.scanLibrary();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Rescanning library…')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.folder_open_rounded),
            title: const Text('Manage Library Folders'),
            subtitle: const Text('Choose which folders to scan for music'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FolderSettingsScreen(),
                ),
              );
            },
          ),

          // ── Audio ─────────────────────────────────────────────
          const _SectionHeader('Audio'),
          ListTile(
            leading: const Icon(Icons.equalizer_rounded),
            title: const Text('Equalizer'),
            onTap: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              builder: (ctx) => DraggableScrollableSheet(
                initialChildSize: 0.75,
                expand: false,
                builder: (_, controller) => SingleChildScrollView(
                  controller: controller,
                  padding: const EdgeInsets.all(24),
                  child: const EqualizerWidget(),
                ),
              ),
            ),
          ),

          // ── About ─────────────────────────────────────────────
          const _SectionHeader('About'),
          const ListTile(
            leading: Icon(Icons.music_note_rounded),
            title: Text('HM Player'),
            subtitle: Text('Version 1.0.0 • Offline & Ad-free'),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            subtitle: const Text('Read our privacy policy'),
            onTap: () {
               // In a real app, use url_launcher
               // For now, we'll show a dialog or just a toast
               _showPrivacyPolicy(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.storage_outlined),
            title: const Text('Storage'),
            subtitle: Text(
              '${lib.songs.length} songs • ${lib.albums.length} albums • ${lib.artists.length} artists',
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _themeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'Follow system';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

  void _showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'HM Player is committed to your privacy. We do not collect, store, or transmit any personal data. '
              'We only access your device storage to scan for music files.',
            ),
            SizedBox(height: 16),
            Text(
              'Full policy available at:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('hm-player.haridinesh.site/privacy-policy/'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showThemePicker(BuildContext context, ThemeProvider theme) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Choose Theme',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            for (final mode in ThemeMode.values)
              RadioListTile<ThemeMode>(
                title: Text(_themeName(mode)),
                value: mode,
                groupValue: theme.themeMode,
                onChanged: (v) {
                  if (v != null) {
                    theme.setThemeMode(v);
                    Navigator.pop(ctx);
                  }
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: cs.primary,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}
