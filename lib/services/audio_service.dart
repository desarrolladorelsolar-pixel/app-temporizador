// =============================================================================
// SERVICIO: AudioService
// =============================================================================
// Gestiona los sonidos de alerta de los temporizadores.
// Usa dos AudioPlayer independientes para que puedan sonar simultáneamente
// si varios temporizadores terminan al mismo tiempo.
//
// SONIDOS:
//   beep_tostado.m4a → suena al pasar de COCCIÓN a TOSTADO (alerta de cambio)
//   beep_fin.m4a     → suena al FINALIZAR el ciclo completo (alerta de listo)
//
// Los archivos de audio están en assets/sounds/ y se incluyen en el APK.
// =============================================================================

import 'package:audioplayers/audioplayers.dart';

/// Servicio estático de audio — no requiere instancia.
/// Todos los métodos son estáticos para acceso global desde AppState.
class AudioService {
  // Player dedicado para el beep de transición cocción→tostado
  static final AudioPlayer _playerTostado = AudioPlayer();

  // Player dedicado para el beep de fin de ciclo
  static final AudioPlayer _playerFin = AudioPlayer();

  /// Reproduce el beep de transición cuando termina la cocción
  /// y el temporizador pasa a esperar el inicio del tostado.
  static Future<void> sonarTostado() async {
    await _playerTostado.stop();          // para si estaba reproduciendo
    await _playerTostado.setVolume(1.0);  // volumen máximo
    await _playerTostado.play(AssetSource('sounds/beep_tostado.m4a'));
  }

  /// Reproduce el beep de finalización cuando termina el ciclo completo
  /// (ya sea solo cocción o cocción + tostado).
  static Future<void> sonarFin() async {
    await _playerFin.stop();
    await _playerFin.setVolume(1.0);
    await _playerFin.play(AssetSource('sounds/beep_fin.m4a'));
  }

  /// Libera los recursos de audio al cerrar la app.
  /// Llamar en el onDestroy de la app si se implementa.
  static Future<void> dispose() async {
    await _playerTostado.dispose();
    await _playerFin.dispose();
  }
}
