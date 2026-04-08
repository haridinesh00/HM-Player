import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 👇 Added this back!
import '../providers/audio_provider.dart';

class EqualizerWidget extends StatefulWidget {
  const EqualizerWidget({super.key});

  @override
  State<EqualizerWidget> createState() => _EqualizerWidgetState();
}

class _EqualizerWidgetState extends State<EqualizerWidget> {
  String _activePreset = 'Custom';

  static const _presets = {
    'Flat': [0.0, 0.0, 0.0, 0.0, 0.0],
    'Bass Boost': [6.0, 4.0, 0.0, 0.0, 0.0],
    'Treble Boost': [0.0, 0.0, 0.0, 4.0, 6.0],
    'Vocal': [-2.0, 0.0, 4.0, 4.0, 2.0],
    'Rock': [4.0, 2.0, -2.0, 2.0, 4.0],
    'Pop': [-1.0, 2.0, 4.0, 2.0, -1.0],
    'Jazz': [2.0, 1.0, 0.0, 2.0, 3.0],
    'Classical': [3.0, 2.0, 0.0, 2.0, 3.0],
  };

  @override
  void initState() {
    super.initState();
    _loadPrefs(); // 👇 Load the preset when the bottom sheet opens
  }

  // ─── Persistence Logic ──────────────────────────────────────────
  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    // Use 'mounted' check since this is async and the sheet might close quickly
    if (mounted) { 
      setState(() {
        _activePreset = prefs.getString('eq_active_preset') ?? 'Custom';
      });
    }
  }

  Future<void> _savePrefs(String presetName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('eq_active_preset', presetName);
  }

  void _applyPreset(String name, List<AndroidEqualizerBand> bands, double min, double max) {
    final preset = _presets[name]!;

    for (int i = 0; i < bands.length; i++) {
      int presetIndex = (i * 5 / bands.length).floor().clamp(0, 4);
      double targetGain = preset[presetIndex].clamp(min, max);
      bands[i].setGain(targetGain);
    }

    setState(() {
      _activePreset = name;
    });
    
    _savePrefs(name); // 👇 Save it to memory!
  }

  @override
  Widget build(BuildContext context) {
    final eq = context.read<AudioProvider>().equalizer;

    return FutureBuilder<AndroidEqualizerParameters>(
      future: eq.parameters,
      builder: (context, snapshot) {
        final params = snapshot.data;
        
        if (params == null) {
          return const SizedBox(
            height: 300,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Custom EQ',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                StreamBuilder<bool>(
                  stream: eq.enabledStream,
                  initialData: eq.enabled,
                  builder: (context, enabledSnap) {
                    final isEnabled = enabledSnap.data ?? false;
                    return Switch(
                      value: isEnabled,
                      onChanged: (value) async {
                        await eq.setEnabled(value);
                        setState(() {}); 
                      },
                    );
                  }
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ── Presets ─────────────────────────────────────────────
            StreamBuilder<bool>(
              stream: eq.enabledStream,
              initialData: eq.enabled,
              builder: (context, enabledSnap) {
                final isEnabled = enabledSnap.data ?? false;
                
                return AnimatedOpacity(
                  opacity: isEnabled ? 1.0 : 0.4,
                  duration: const Duration(milliseconds: 200),
                  child: IgnorePointer(
                    ignoring: !isEnabled,
                    child: SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: const Text('Custom'),
                              selected: _activePreset == 'Custom',
                              onSelected: (_) {
                                setState(() => _activePreset = 'Custom');
                                _savePrefs('Custom');
                              },
                            ),
                          ),
                          ..._presets.keys.map((name) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(name),
                              selected: _activePreset == name,
                              onSelected: (_) => _applyPreset(name, params.bands, params.minDecibels, params.maxDecibels),
                            ),
                          )),
                        ],
                      ),
                    ),
                  ),
                );
              }
            ),
            const SizedBox(height: 32),
            
            // ── Bands ───────────────────────────────────────────────
            StreamBuilder<bool>(
              stream: eq.enabledStream,
              initialData: eq.enabled,
              builder: (context, enabledSnap) {
                final isEnabled = enabledSnap.data ?? false;
                
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: params.bands.map((band) {
                      return _buildSlider(band, params.minDecibels, params.maxDecibels, isEnabled);
                    }).toList(),
                  ),
                );
              }
            ),
          ],
        );
      },
    );
  }

  Widget _buildSlider(AndroidEqualizerBand band, double min, double max, bool isEnabled) {
    final cs = Theme.of(context).colorScheme;
    
    final freq = band.centerFrequency;
    final freqText = freq >= 1000 
        ? '${(freq / 1000).toStringAsFixed(0)}k' 
        : '${freq.round()}';

    return StreamBuilder<double>(
      stream: band.gainStream,
      initialData: band.gain,
      builder: (context, snapshot) {
        final currentGain = snapshot.data ?? 0.0;
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Column(
            children: [
              Text(
                '${currentGain > 0 ? '+' : ''}${currentGain.round()} dB',
                style: TextStyle(
                  fontSize: 12,
                  color: isEnabled ? cs.primary : cs.onSurface.withValues(alpha: 0.4),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 220,
                child: RotatedBox(
                  quarterTurns: 3,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      disabledActiveTrackColor: cs.onSurface.withValues(alpha: 0.2),
                      disabledInactiveTrackColor: cs.onSurface.withValues(alpha: 0.1),
                      disabledThumbColor: cs.onSurface.withValues(alpha: 0.4),
                    ),
                    child: Slider(
                      min: min,
                      max: max,
                      value: currentGain,
                      onChanged: isEnabled 
                          ? (newValue) {
                              band.setGain(newValue); 
                              // 👇 If they drag a slider manually, switch to "Custom" AND save it
                              if (_activePreset != 'Custom') {
                                setState(() {
                                  _activePreset = 'Custom';
                                });
                                _savePrefs('Custom');
                              }
                            }
                          : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                freqText,
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        );
      }
    );
  }
}