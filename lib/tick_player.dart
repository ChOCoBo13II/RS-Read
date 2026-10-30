import 'dart:convert';

import 'package:flutter_soloud/flutter_soloud.dart' show SoLoud;

import 'tick_sound_data.dart';

/// Suono del ticchettio. Il motore audio parte solo quando serve e, se
/// qualcosa va storto, la lettura continua senza suono.
class TickPlayer {
  TickPlayer._();

  static final TickPlayer instance = TickPlayer._();

  // Dimensione del buffer audio: più piccolo = meno ritardo del suono,
  // ma su telefoni lenti può scricchiolare. Se serve, si cambia qui.
  static const int _soundBuffer = 1024;

  Future<void>? _init;
  void Function(double volume)? _playFn;

  Future<void> ensureReady() => _init ??= _doInit();

  Future<void> _doInit() async {
    try {
      await SoLoud.instance.init(bufferSize: _soundBuffer);
      final source = await SoLoud.instance.loadMem(
        'tick.wav',
        base64Decode(tickWavBase64),
      );
      _playFn = (v) => SoLoud.instance.play(source, volume: v);
    } catch (_) {
      _playFn = null;
    }
  }

  void play(double volume) {
    final f = _playFn;
    if (f == null) return;
    try {
      f(volume);
    } catch (_) {
      _playFn = null;
    }
  }
}