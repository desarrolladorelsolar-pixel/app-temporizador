import 'freidora.dart';
import 'producto.dart';

/// Modelo de un temporizador activo en memoria.
///
/// CICLO DE ESTADOS:
///   'coccion'           → corriendo fase cocción (rojo)
///   'esperando_tostado' → cocción terminó, esperando doble tap (naranja pulsante)
///   'tostado'           → corriendo fase tostado (naranja)
///   'pausado'           → detenido manualmente, conserva tiempos
///   'listo_repaso'      → usuario tocó ↺, botón verde esperando doble tap
///   'repaso'            → corriendo countdown de repaso (verde)
class Temporizador {
  final int? id;
  final Freidora freidora;
  Producto producto; // mutable para reflejar ediciones en caliente

  int tiempoCoccionRestante;  // segundos
  int tiempoTostadoRestante;  // segundos
  int tiempoRepasoRestante;   // segundos (0 = sin repaso activo)
  int boquillaRepaso;         // 1 o 2 — boquilla elegida al iniciar repaso

  String estado;
  bool corriendo;
  String? estadoAntesDePausa; // 'coccion' | 'tostado' para reanudar en fase correcta
  DateTime? iniciadoEn;

  Temporizador({
    this.id,
    required this.freidora,
    required this.producto,
    required this.tiempoCoccionRestante,
    required this.tiempoTostadoRestante,
    this.tiempoRepasoRestante = 0,
    this.boquillaRepaso = 1,
    this.estado = 'coccion',
    this.corriendo = false,
    this.estadoAntesDePausa,
    this.iniciadoEn,
  });
}
