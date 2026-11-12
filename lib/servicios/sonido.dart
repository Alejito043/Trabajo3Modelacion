import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import '../estado.dart';

class Sonido {
  static final Map<String, AudioPlayer> _players = {};

  static Future<void> _play(String nombre, {double volumen = 0.7}) async {
    if (!estado.sonido) return;
    try {
      final p = _players.putIfAbsent(nombre, () => AudioPlayer());
      await p.stop();
      await p.play(AssetSource('sonidos/$nombre.wav'), volume: volumen);
    } catch (_) {
      // Si el audio falla, la app sigue funcionando sin sonido.
    }
  }

  static void tap() {
    HapticFeedback.selectionClick();
    _play('tap', volumen: 0.5);
  }

  static void ding() {
    HapticFeedback.mediumImpact();
    _play('ding');
  }

  static void pop() => _play('pop', volumen: 0.35);

  static void error() {
    HapticFeedback.heavyImpact();
    _play('error', volumen: 0.5);
  }
}
