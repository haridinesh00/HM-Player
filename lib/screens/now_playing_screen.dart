import 'dart:async';
import 'dart:developer';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';

import '../providers/audio_provider.dart';
import '../providers/library_provider.dart';
import '../main.dart';
import '../services/audio_handler.dart';
import '../utils/extensions.dart';
import '../widgets/equalizer_widget.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  late final AnimationController _artworkController;
  late final Animation<double> _artworkScale;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _artworkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _artworkScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _artworkController, curve: Curves.easeOutBack),
    );

    // Animate artwork when playing state changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final audio = context.read<AudioProvider>();
      if (audio.isPlaying) _artworkController.forward();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _artworkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final audio = context.read<AudioProvider>();

    return Scaffold(
      backgroundColor: cs.surface,
      body: StreamBuilder<MediaItem?>(
        stream: audio.mediaItemStream,
        builder: (context, snapshot) {
          final item = snapshot.data;
          if (item == null) {
            return const Center(child: Text('Nothing playing'));
          }
          return _NowPlayingBody(
            item: item,
            tabController: _tabController,
            artworkScale: _artworkScale,
            artworkController: _artworkController,
          );
        },
      ),
    );
  }
}

class _NowPlayingBody extends StatelessWidget {
  final MediaItem item;
  final TabController tabController;
  final Animation<double> artworkScale;
  final AnimationController artworkController;

  const _NowPlayingBody({
    required this.item,
    required this.tabController,
    required this.artworkScale,
    required this.artworkController,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Column(
        children: [
          // ── Top bar ──────────────────────────────────────────
          _TopBar(item: item),

          // ── Tab bar ──────────────────────────────────────────
          TabBar(
            controller: tabController,
            tabs: const [
              Tab(text: 'Now Playing'),
              Tab(text: 'Queue'),
            ],
            dividerColor: Colors.transparent,
            indicatorColor: cs.primary,
          ),

          Expanded(
            child: TabBarView(
              controller: tabController,
              children: [
                _PlayerTab(
                  item: item,
                  artworkScale: artworkScale,
                  artworkController: artworkController,
                ),
                const _QueueTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Top Bar ─────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final MediaItem item;
  const _TopBar({required this.item});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'Now Playing',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface.withValues(alpha: 0.5),
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () => _showOptions(context),
          ),
        ],
      ),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outline,
                  borderRadius: BorderRadius.circular(2)),
            ),
            ListTile(
              leading: const Icon(Icons.equalizer_rounded),
              title: const Text('Equalizer'),
              onTap: () {
                Navigator.pop(ctx);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (ctx) => DraggableScrollableSheet(
                    initialChildSize: 0.65,
                    maxChildSize: 0.65,
                    minChildSize: 0.4,
                    expand: false,
                    builder: (_, controller) => SingleChildScrollView(
                      controller: controller,
                      padding: const EdgeInsets.all(24),
                      child: const EqualizerWidget(),
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: const Text('Sleep Timer'),
              onTap: () {
                Navigator.pop(ctx);
                _showSleepTimer(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showSleepTimer(BuildContext context) {
    final customController = TextEditingController();
    final presets = [5, 10, 15, 30, 45, 60];

    void startTimer(BuildContext dialogCtx, int minutes) {
      Navigator.pop(dialogCtx);

      // Cancel any existing timer
      _TopBar._sleepTimer?.cancel();

      _TopBar._sleepTimer = Timer(Duration(minutes: minutes), () {
        audioHandler.pause();
        _TopBar._sleepTimer = null;
      });

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sleep timer: $minutes min'),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Cancel',
            onPressed: () {
              _TopBar._sleepTimer?.cancel();
              _TopBar._sleepTimer = null;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Sleep timer cancelled'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ),
      );
    }

    showDialog(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: const Text('Sleep Timer'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Preset chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: presets.map((min) {
                  return ActionChip(
                    label: Text('$min min'),
                    backgroundColor: cs.secondaryContainer,
                    onPressed: () => startTimer(ctx, min),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              // Custom input
              TextField(
                controller: customController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Custom (minutes)',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.check_circle, color: cs.primary),
                    onPressed: () {
                      final val = int.tryParse(customController.text);
                      if (val != null && val > 0) {
                        startTimer(ctx, val);
                      }
                    },
                  ),
                ),
                onSubmitted: (text) {
                  final val = int.tryParse(text);
                  if (val != null && val > 0) {
                    startTimer(ctx, val);
                  }
                },
              ),
              // Cancel existing timer option
              if (_TopBar._sleepTimer != null) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  icon: const Icon(Icons.timer_off_outlined),
                  label: const Text('Cancel current timer'),
                  style: TextButton.styleFrom(foregroundColor: cs.error),
                  onPressed: () {
                    _TopBar._sleepTimer?.cancel();
                    _TopBar._sleepTimer = null;
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Sleep timer cancelled'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  static Timer? _sleepTimer;
}

// ─── Player Tab ───────────────────────────────────────────────
class _PlayerTab extends StatelessWidget {
  final MediaItem item;
  final Animation<double> artworkScale;
  final AnimationController artworkController;

  const _PlayerTab({
    required this.item,
    required this.artworkScale,
    required this.artworkController,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // ── Artwork ─────────────────────────────────────────
          _ArtworkSection(
            item: item,
            artworkScale: artworkScale,
            artworkController: artworkController,
          ),
          const SizedBox(height: 28),
          // ── Song Info ────────────────────────────────────────
          _SongInfo(item: item),
          const SizedBox(height: 20),
          // ── Progress ─────────────────────────────────────────
          _ProgressSection(),
          const SizedBox(height: 12),
          // ── Controls ─────────────────────────────────────────
          _ControlsSection(artworkController: artworkController),
          const SizedBox(height: 12),
          // ── Volume ───────────────────────────────────────────
          _VolumeSection(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── Artwork Section ─────────────────────────────────────────
class _ArtworkSection extends StatelessWidget {
  final MediaItem item;
  final Animation<double> artworkScale;
  final AnimationController artworkController;

  const _ArtworkSection({
    required this.item,
    required this.artworkScale,
    required this.artworkController,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final albumId = item.extras?['albumId'] as int?;

    return StreamBuilder<bool>(
      stream: context.read<AudioProvider>().playingStream,
      builder: (ctx, snap) {
        final playing = snap.data ?? false;
        if (playing) {
          artworkController.forward();
        } else {
          artworkController.reverse();
        }
        return ScaleTransition(
          scale: artworkScale,
          child: Hero(
            tag: 'album_art_${item.id}',
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: cs.primary.withValues(alpha: 0.3),
                    blurRadius: 40,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: albumId != null
                    ? QueryArtworkWidget(
                        id: albumId,
                        type: ArtworkType.ALBUM,
                        size: 800, // Fetch an optimal size to prevent memory crashes
                        quality: 100, 
                        artworkQuality: FilterQuality.high,
                        artworkBorder: BorderRadius.zero,
                        artworkWidth:
                            MediaQuery.of(context).size.width - 80,
                        artworkHeight:
                            MediaQuery.of(context).size.width - 80,
                        artworkFit: BoxFit.cover,
                        keepOldArtwork: true,
                        nullArtworkWidget: _fallback(cs),
                      )
                    : _fallback(cs),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _fallback(ColorScheme cs) {
    const size = 300.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primaryContainer, cs.secondaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(Icons.music_note_rounded, size: 100, color: cs.primary),
    );
  }
}

// ─── Song Info ───────────────────────────────────────────────
// ─── Song Info ───────────────────────────────────────────────
class _SongInfo extends StatelessWidget {
  final MediaItem item;
  const _SongInfo({required this.item});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final songId = item.extras?['songId'] as int?;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                item.artist ?? 'Unknown Artist',
                style: TextStyle(
                  fontSize: 15,
                  color: cs.onSurface.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                item.album ?? '',
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withValues(alpha: 0.45),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        
        // Fix: Listen to LibraryProvider instead of PlaylistProvider
        if (songId != null)
          Consumer<LibraryProvider>(
            builder: (context, libraryProvider, _) {
              final isFav = libraryProvider.isFavorite(songId);

              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: IconButton(
                  key: ValueKey(isFav),
                  icon: Icon(
                    isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: isFav ? cs.error : cs.onSurface.withValues(alpha: 0.4),
                    size: 28,
                  ),
                  onPressed: () {
                    try {
                       // Find the song and toggle it using the libraryProvider
                       final songModel = libraryProvider.songs.firstWhere((s) => s.id == songId);
                       libraryProvider.toggleFavorite(songModel);
                    } catch (e) {
                      log("Song not found in library for favorites");
                    }
                  },
                ),
              );
            },
          ),
      ],
    );
  }
}

// ─── Progress Section ────────────────────────────────────────
class _ProgressSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final audio = context.read<AudioProvider>();

    return StreamBuilder<PositionData>(
      stream: audio.positionDataStream,
      builder: (ctx, snap) {
        // Handle null safety gracefully
        final data = snap.data;
        final position = data?.position ?? Duration.zero;
        final duration = data?.duration ?? Duration.zero;
        
        // Prevent division by zero or errors before duration is known
        double progressValue = 0.0;
        if (duration.inMilliseconds > 0 && position.inMilliseconds > 0) {
           progressValue = position.inMilliseconds / duration.inMilliseconds;
        }

        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
              ),
              child: Slider(
                // Fix 2: Provide the clamped value
                value: progressValue.clamp(0.0, 1.0),
                onChanged: (v) {
                  // Fix 3: Calculate the seek duration correctly
                  if (duration.inMilliseconds > 0) {
                    final ms = (v * duration.inMilliseconds).round();
                    audio.seekTo(Duration(milliseconds: ms));
                  }
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    position.mmss, // Assuming you have an extension for .mmss
                    style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.6)),
                  ),
                  Text(
                    duration.mmss,
                    style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.6)),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Controls Section ────────────────────────────────────────
class _ControlsSection extends StatelessWidget {
  final AnimationController artworkController;
  const _ControlsSection({required this.artworkController});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final audio = context.read<AudioProvider>();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Shuffle
        StreamBuilder<bool>(
          stream: audio.shuffleModeStream,
          builder: (ctx, snap) {
            final on = snap.data ?? false;
            return IconButton(
              icon: const Icon(Icons.shuffle_rounded, size: 24),
              color: on ? cs.primary : cs.onSurface.withValues(alpha: 0.4),
              onPressed: audio.toggleShuffle,
            );
          },
        ),

        // Previous
        IconButton(
          icon: const Icon(Icons.skip_previous_rounded, size: 36),
          onPressed: audio.skipToPrevious,
          color: cs.onSurface,
        ),

        // Play / Pause
        StreamBuilder<bool>(
          stream: audio.playingStream,
          builder: (ctx, snap) {
            final playing = snap.data ?? false;
            return GestureDetector(
              onTap: audio.togglePlayPause,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: cs.primary.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  playing
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 38,
                  color: cs.onPrimary,
                ),
              ),
            );
          },
        ),

        // Next
        IconButton(
          icon: const Icon(Icons.skip_next_rounded, size: 36),
          onPressed: audio.skipToNext,
          color: cs.onSurface,
        ),

        // Repeat
        StreamBuilder<LoopMode>(
          stream: audio.loopModeStream,
          builder: (ctx, snap) {
            final mode = snap.data ?? LoopMode.off;
            return IconButton(
              icon: Icon(
                mode == LoopMode.one
                    ? Icons.repeat_one_rounded
                    : Icons.repeat_rounded,
                size: 24,
              ),
              color: mode == LoopMode.off
                  ? cs.onSurface.withValues(alpha: 0.4)
                  : cs.primary,
              onPressed: audio.cycleRepeatMode,
            );
          },
        ),
      ],
    );
  }
}

// ─── Volume Section ──────────────────────────────────────────
class _VolumeSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final audio = context.read<AudioProvider>();

    return StreamBuilder<double>(
      stream: audio.volumeStream,
      initialData: 1.0,
      builder: (ctx, snap) {
        final vol = snap.data ?? 1.0;
        return Row(
          children: [
            Icon(Icons.volume_down_rounded,
                size: 20, color: cs.onSurface.withValues(alpha: 0.5)),
            Expanded(
              child: Slider(
                value: vol,
                onChanged: audio.setVolume,
                min: 0,
                max: 1,
              ),
            ),
            Icon(Icons.volume_up_rounded,
                size: 20, color: cs.onSurface.withValues(alpha: 0.5)),
          ],
        );
      },
    );
  }
}

// ─── Queue Tab ────────────────────────────────────────────────
// ─── Queue Tab ────────────────────────────────────────────────
class _QueueTab extends StatelessWidget {
  const _QueueTab();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Fix 1: Use Consumer so it rebuilds anytime the AudioProvider notifies listeners
    return Consumer<AudioProvider>(
      builder: (ctx, audio, child) {
        final queue = audio.queue;
        final currentIdx = audio.currentIndex ?? 0;

        if (queue.isEmpty) {
          return const Center(child: Text('Queue is empty'));
        }

        return ReorderableListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 16),
          onReorder: (from, to) {
            // ReorderableListView behaves weirdly when moving items down, this fixes the math
            if (to > from) to -= 1; 
            audio.moveQueueItem(from, to);
          },
          itemCount: queue.length,
          itemBuilder: (ctx, i) {
            final item = queue[i];
            final isCurrent = i == currentIdx;

            return ListTile(
              // Fix 2: MUST use item.id for the key, NOT the index!
              // If you use the index, Flutter gets confused when an item is deleted.
              key: ValueKey(item.id), 
              
              leading: isCurrent
                  ? Icon(Icons.equalizer_rounded, color: cs.primary)
                  : Text('${i + 1}',
                      style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.4))),
              title: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight:
                      isCurrent ? FontWeight.w700 : FontWeight.w500,
                  color: isCurrent ? cs.primary : null,
                ),
              ),
              subtitle: Text(
                item.artist ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.close, size: 18,
                        color: cs.onSurface.withValues(alpha: 0.4)),
                    onPressed: () => audio.removeFromQueue(i),
                  ),
                  ReorderableDragStartListener(
                    index: i,
                    child: Icon(Icons.drag_handle,
                        color: cs.onSurface.withValues(alpha: 0.4)),
                  ),
                ],
              ),
              onTap: () => audio.skipToIndex(i),
            );
          },
        );
      },
    );
  }
}