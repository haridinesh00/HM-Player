// lib/providers/audio_provider.dart
import 'package:rxdart/rxdart.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../providers/theme_provider.dart';
import '../services/audio_handler.dart';
import '../models/models.dart';

class AudioProvider extends ChangeNotifier {
  final MusicAudioHandler _handler;
  final ThemeProvider _themeProvider;

  List<Song> _songs = [];
  List<Song> get songs => _songs;

  Song? get currentSong {
    final item = _handler.mediaItem.value;
    if (item == null) return null;
    final idx = _handler.currentIndex;
    if (idx != null && idx < _songs.length) return _songs[idx];
    return null;
  }

  bool get isPlaying => _handler.playing;
  Duration get position => _handler.position;
  Duration get duration => _handler.duration ?? Duration.zero;
  int? get currentIndex => _handler.currentIndex;
  List<MediaItem> get queue => _handler.queue.value;

  Stream<PositionData> get positionDataStream => _handler.positionDataStream;
  Stream<bool> get playingStream => _handler.playingStream;
  Stream<int?> get currentIndexStream => _handler.currentIndexStream;
  Stream<LoopMode> get loopModeStream => _handler.loopModeStream;
  Stream<bool> get shuffleModeStream => _handler.shuffleModeStream;
  ValueStream<MediaItem?> get mediaItemStream => _handler.mediaItem;

  AudioProvider(this._handler, this._themeProvider) {
    // Rebuild UI on state changes
    _handler.playbackState.listen((_) => notifyListeners());
    _handler.mediaItem.listen((item) {
      notifyListeners();
      // Extract dynamic colors from the new song's artwork
      final songId = item?.extras?['songId'] as int?;
      final albumId = item?.extras?['albumId'] as int?;
      _themeProvider.extractColorsFromArtwork(
        songId: songId,
        albumId: albumId,
      );
    });
    _handler.queue.listen((_) => notifyListeners());
  }

  // ─── Play ────────────────────────────────────────────────────
  Future<void> playSong(Song song, List<Song> queue) async {
    _songs = queue;
    final idx = queue.indexOf(song);
    final mediaItems = queue.map((s) => s.toMediaItem()).toList();
    await _handler.playFromSongs(
      songs: mediaItems,
      startIndex: idx < 0 ? 0 : idx,
    );
    notifyListeners();
  }

  Future<void> playAll(List<Song> songs, {bool shuffle = false}) async {
    if (songs.isEmpty) return;
    _songs = List.from(songs);
    final list = shuffle ? (List<Song>.from(songs)..shuffle()) : songs;
    final mediaItems = list.map((s) => s.toMediaItem()).toList();
    await _handler.playFromSongs(songs: mediaItems, startIndex: 0);
    notifyListeners();
  }

  // ─── Controls ────────────────────────────────────────────────
  Future<void> play() => _handler.play();
  Future<void> pause() => _handler.pause();
  Future<void> togglePlayPause() =>
      isPlaying ? _handler.pause() : _handler.play();
  Future<void> seekTo(Duration position) => _handler.seek(position);
  Future<void> skipToNext() => _handler.skipToNext();
  Future<void> skipToPrevious() => _handler.skipToPrevious();
  Future<void> skipToIndex(int index) => _handler.skipToQueueItem(index);

  // ─── Shuffle ─────────────────────────────────────────────────
  Future<void> toggleShuffle() async {
    final current = await _handler.shuffleModeStream.first;
    await _handler.setShuffleMode(
      current
          ? AudioServiceShuffleMode.none
          : AudioServiceShuffleMode.all,
    );
  }

  // ─── Repeat ──────────────────────────────────────────────────
  Future<void> cycleRepeatMode() async {
    final current = await _handler.loopModeStream.first;
    final next = {
      LoopMode.off: LoopMode.all,
      LoopMode.all: LoopMode.one,
      LoopMode.one: LoopMode.off,
    }[current]!;
    await _handler.setRepeatMode({
      LoopMode.off: AudioServiceRepeatMode.none,
      LoopMode.all: AudioServiceRepeatMode.all,
      LoopMode.one: AudioServiceRepeatMode.one,
    }[next]!);
  }

  // ─── Queue Management ────────────────────────────────────────
  Future<void> addToQueue(Song song) =>
      _handler.addToQueue(song.toMediaItem());
  Future<void> addNextInQueue(Song song) =>
      _handler.addNextInQueue(song.toMediaItem());
  Future<void> removeFromQueue(int index) => _handler.removeFromQueue(index);
  Future<void> moveQueueItem(int from, int to) =>
      _handler.moveQueueItem(from, to);

  // ─── Volume ──────────────────────────────────────────────────
  Future<void> setVolume(double v) => _handler.setVolume(v);
  Stream<double> get volumeStream => _handler.volumeStream;
  // Expose the equalizer so the UI sliders can talk to it
  AndroidEqualizer get equalizer => _handler.equalizer;
}
