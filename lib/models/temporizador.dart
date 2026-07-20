// =============================================================================
// MODELO: Temporizador
// =============================================================================
// Representa una instancia de temporizador activo en la pantalla principal.
// Un temporizador combina una Freidora + un Producto y gestiona
// el ciclo de cocción (dos fases: cocción y tostado).
//
// CICLO DE ESTADOS:
//   'coccion'           → Timer corriendo en fase de cocción (rojo)
//   'esperando_tostado' → Cocción terminó, esperando doble tap para tostado
//   'tostado'           → Timer corriendo en fase de tostado (naranja)
//   'pausado'           → Timer detenido manualmente, conserva tiempo restante
//
// Los temporizadores son PLANTILLAS REUTILIZABLES — no se borran al finalizar.
// Se reinician automáticamente para poder usarse de nuevo.
// Los registros de uso se guardan en la tabla `log`.
// =============================================================================

import 'freidora.dart';
import 'producto.dart';

/// Modelo de un temporizador activo en memoria.
///
/// Este objeto vive en RAM (en AppState) y se reconstruye desde la BD
/// cada vez que se abre la app.
class Temporizador {
  /// ID en la tabla `temporizador` de SQLite (null si aún no fue guardado).
  final int? id;

  /// Freidora asignada a este temporizador.
  final Freidora freidora;

  /// Producto asignado — es mutable para reflejar ediciones del producto en caliente.
  Producto producto;

  /// Segundos restantes de la fase de cocción.
  int tiempoCoccionRestante;

  /// Segundos restantes de la fase de tostado.
  int tiempoTostadoRestante;

  /// Estado actual del ciclo: 'coccion' | 'esperando_tostado' | 'tostado' | 'pausado'.
  String estado;

  /// true si el Timer.periodic está activo en memoria.
  bool corriendo;

  /// Guarda el estado previo a la pausa ('coccion' o 'tostado')
  /// para poder reanudar en la fase correcta.
  String? estadoAntesDePausa;

  /// Momento exacto en que se inició el ciclo actual.
  /// Se persiste en la BD (columna `inicio_en`) para que si la app
  /// se cierra, al reabrir se calcule el tiempo transcurrido.
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
