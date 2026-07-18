import 'package:audioplayers/audioplayers.dart';

// ── Servicio de audio para los temporizadores ────────────────────────────────
// Maneja dos players independientes para que puedan sonar simultáneamente
// si hay varios temporizadores activos al mismo tiempo.
class AudioService {
  // Player dedicado para el sonido de transición cocción→tostado
  static final AudioPlayer _playerTostado = AudioPlayer();

  // Player dedicado para el sonido de fin de tostado
  static final AudioPlayer _playerFin = AudioPlayer();

  /// Sonido al pasar de COCCIÓN a TOSTADO — un beep medio
  static Future<void> sonarTostado() async {
    await _playerTostado.stop();
    await _playerTostado.setVolume(1.0);
    await _playerTostado.play(AssetSource('sounds/beep_tostado.m4a'));
  }

  /// Sonido al FINALIZAR el tostado — tres beeps agudos
  static Future<void> sonarFin() async {
    await _playerFin.stop();
    await _playerFin.setVolume(1.0);
    await _playerFin.play(AssetSource('sounds/beep_fin.m4a'));
  }

  /// Liberar recursos al cerrar la app
  static Future<void> dispose() async {
    await _playerTostado.dispose();
    await _playerFin.dispose();
  }
}
