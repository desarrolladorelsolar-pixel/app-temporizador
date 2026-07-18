// ── Modelo: Producto ─────────────────────────────────────────────────────────
class Producto {
  final int? id;
  final String nombre;
  final int tiempoCoccion; // en minutos
  final int tiempoTostado; // en minutos

  Producto({
    this.id,
    required this.nombre,
    required this.tiempoCoccion,
    required this.tiempoTostado,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id_producto': id,
        'nombre': nombre,
        'tiempo_coccion': tiempoCoccion * 60, // guardar en segundos
        'tiempo_tostado': tiempoTostado * 60,
        'estado': 'activo',
      };

  factory Producto.fromMap(Map<String, dynamic> m) => Producto(
        id: m['id_producto'] as int?,
        nombre: m['nombre'] as String,
        tiempoCoccion: ((m['tiempo_coccion'] as int? ?? 0) ~/ 60),
        tiempoTostado: ((m['tiempo_tostado'] as int? ?? 0) ~/ 60),
      );
}
