// =============================================================================
// MODELO: Producto
// =============================================================================
// Representa un producto de cocina (ej: "Pollo Broaster").
// Cada producto define los tiempos de cocción y tostado que se usan
// como valores por defecto al crear un temporizador.
//
// Los datos se persisten en la tabla SQLite `producto`.
// IMPORTANTE: los tiempos se guardan en SEGUNDOS en la BD,
// pero el modelo los expone en MINUTOS para facilitar la UI.
// =============================================================================

/// Modelo de datos para un producto de cocina.
class Producto {
  /// Identificador único en la BD (null si aún no fue insertado).
  final int? id;

  /// Nombre del producto (ej: "Pollo Broaster", "Alitas").
  final String nombre;

  /// Tiempo de cocción en MINUTOS (se convierte a segundos al guardar en BD).
  final int tiempoCoccion;

  /// Tiempo de tostado en MINUTOS (se convierte a segundos al guardar en BD).
  final int tiempoTostado;

  Producto({
    this.id,
    required this.nombre,
    required this.tiempoCoccion,
    required this.tiempoTostado,
  });

  /// Convierte el objeto a un Map para SQLite.
  /// Los tiempos se multiplican por 60 para guardarlos en segundos.
  Map<String, dynamic> toMap() => {
        if (id != null) 'id_producto': id,
        'nombre': nombre,
        'tiempo_coccion': tiempoCoccion * 60, // minutos → segundos
        'tiempo_tostado': tiempoTostado * 60, // minutos → segundos
        'estado': 'activo',
      };

  /// Construye un Producto a partir de una fila de SQLite.
  /// Los tiempos se dividen por 60 para convertir de segundos a minutos.
  factory Producto.fromMap(Map<String, dynamic> m) => Producto(
        id: m['id_producto'] as int?,
        nombre: m['nombre'] as String,
        tiempoCoccion: ((m['tiempo_coccion'] as int? ?? 0) ~/ 60), // segundos → minutos
        tiempoTostado: ((m['tiempo_tostado'] as int? ?? 0) ~/ 60), // segundos → minutos
      );
}
