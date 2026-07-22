// =============================================================================
// MODELO: Producto — v2.0
// =============================================================================
// Cada producto define 3 tiempos:
//   tiempoCoccion  → Boquilla 1 (ciclo principal)
//   tiempoTostado  → Boquilla 2 (ciclo principal)
//   tiempoRepaso   → la boquilla configurada en boquillaRepaso (independiente)
//
// boquillaRepaso indica dónde corre el repaso:
//   1 → misma boquilla que cocción (Boquilla 1)
//   2 → misma boquilla que tostado (Boquilla 2)
// =============================================================================

class Producto {
  final int? id;
  final String nombre;
  final int tiempoCoccion;   // en MINUTOS (BD guarda en segundos)
  final int tiempoTostado;   // en MINUTOS (BD guarda en segundos)
  final int tiempoRepaso;    // en MINUTOS, 0 = sin repaso (BD guarda en segundos)
  final int boquillaRepaso;  // 1 = Boquilla 1 (cocción) | 2 = Boquilla 2 (tostado)

  Producto({
    this.id,
    required this.nombre,
    required this.tiempoCoccion,
    required this.tiempoTostado,
    this.tiempoRepaso = 0,
    this.boquillaRepaso = 1,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id_producto': id,
        'nombre': nombre,
        'tiempo_coccion': tiempoCoccion * 60,
        'tiempo_tostado': tiempoTostado * 60,
        'tiempo_repaso': tiempoRepaso * 60,
        'id_boquilla_repaso': boquillaRepaso,
        'estado': 'activo',
      };

  factory Producto.fromMap(Map<String, dynamic> m) => Producto(
        id: m['id_producto'] as int?,
        nombre: m['nombre'] as String,
        tiempoCoccion: ((m['tiempo_coccion'] as int? ?? 0) ~/ 60),
        tiempoTostado: ((m['tiempo_tostado'] as int? ?? 0) ~/ 60),
        tiempoRepaso: ((m['tiempo_repaso'] as int? ?? 0) ~/ 60),
        boquillaRepaso: m['id_boquilla_repaso'] as int? ?? 1,
      );
}
