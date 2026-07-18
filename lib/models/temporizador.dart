import 'freidora.dart';
import 'producto.dart';

// ── Modelo: Temporizador ─────────────────────────────────────────────────────
// Estados:
//   'coccion'           → corriendo fase cocción
//   'esperando_tostado' → cocción terminó, esperando play manual para tostado
//   'tostado'           → corriendo fase tostado
//   'pausado'           → pausado en cocción o tostado
class Temporizador {
  final int? id;
  final Freidora freidora;
  Producto producto;

  int tiempoCoccionRestante;
  int tiempoTostadoRestante;
  String estado;
  bool corriendo;
  String? estadoAntesDePausa; // guarda 'coccion' o 'tostado' para reanudar

  DateTime? iniciadoEn;

  Temporizador({
    this.id,
    required this.freidora,
    required this.producto,
    required this.tiempoCoccionRestante,
    required this.tiempoTostadoRestante,
    this.estado = 'coccion',
    this.corriendo = false,
    this.estadoAntesDePausa,
    this.iniciadoEn,
  });
}
