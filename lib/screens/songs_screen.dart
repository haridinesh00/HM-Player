// lib/screens/songs_screen.dart
import 'package:flutter/material.dart';
import 'package:music_player/models/models.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../providers/audio_provider.dart';
import '../providers/library_provider.dart';
import '../widgets/song_tile.dart';

class SongsScreen extends StatelessWidget {
  const SongsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryProvider>();
    final audio = context.read<AudioProvider>();

    switch (lib.state) {
      case LibraryState.initial:
      case LibraryState.loading:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Scanning music library…'),
            ],
          ),
        );

      case LibraryState.noPermission:
        return _NoPermission(onGrant: () => lib.init());

      case LibraryState.error:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 12),
              Text(lib.error),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: lib.scanLibrary,
                child: const Text('Retry'),
              ),
            ],
          ),
        );

      case LibraryState.ready:
        if (lib.songs.isEmpty) {
          return const _EmptyLibrary();
        }
        return _SongsList(songs: lib.songs, audio: audio);
    }
  }
}

class _SongsList extends StatelessWidget {
  final List<Song> songs;
  final AudioProvider audio;

  const _SongsList({required this.songs, required this.audio});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Text(
                  '${songs.length} songs',
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                // Play all
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  label: const Text('Play all'),
                  onPressed: () => audio.playAll(songs),
                ),
                const SizedBox(width: 8),
                // Shuffle
                IconButton.filledTonal(
                  icon: const Icon(Icons.shuffle_rounded, size: 20),
                  onPressed: () => audio.playAll(songs, shuffle: true),
                  tooltip: 'Shuffle all',
                ),
              ],
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) {
              final song = songs[i];
              return StreamBuilder(
                stream: context.read<AudioProvider>().currentIndexStream,
                builder: (ctx, snap) {
                  final currentIdx = snap.data;
                  final queue = context.read<AudioProvider>().queue;
                  final isPlaying = currentIdx != null &&
                      currentIdx < queue.length &&
                      queue[currentIdx].id == song.data;
                  return SongTile(
                    song: song,
                    queue: songs,
                    isPlaying: isPlaying,
                  );
                },
              );
            },
            childCount: songs.length,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
      ],
    );
  }
}

class _NoPermission extends StatelessWidget {
  final VoidCallback onGrant;
  const _NoPermission({required this.onGrant});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.library_music_rounded,
                    size: 48,
                    color: Theme.of(context).colorScheme.onPrimaryContainer),
              ),
              const SizedBox(height: 32),
              const Text(
                'Let\'s find your music!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'HM Player needs your permission to scan your device for audio files. We respect your privacy and don\'t collect any personal information.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color:
                      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 40),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.lock_open_rounded),
                label: const Text('Grant Access', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: onGrant,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                   // Open settings if they already denied twice
                   // import 'package:permission_handler/permission_handler.dart';
                   openAppSettings();
                },
                child: const Text('Already denied? Open Settings'),
              ),
            ],
          ),
        ),
      );
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.music_off_outlined,
                size: 80,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            const Text(
              'No music found',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Add some audio files to your device storage.',
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
}
