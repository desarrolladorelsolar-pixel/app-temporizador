// =============================================================================
// MODELO: Freidora
// =============================================================================
// Representa una freidora física de la sucursal (ej: "FR-01").
// Se usa para asignarla a un temporizador y registrar su código en los logs.
//
// Los datos se persisten en la tabla SQLite `freidora`.
// El borrado es SOFT DELETE (estado → 'inactivo') para no romper los logs
// históricos que referencian a la freidora.
// =============================================================================

/// Modelo de datos para una freidora de la sucursal.
class Freidora {
  /// Identificador único en la BD (null si aún no fue insertado).
  final int? id;

  /// Código de identificación de la freidora (ej: "FR-01", "FREIDORA A").
  final String codigo;

  /// Descripción opcional (ej: "Freidora grande de pollo").
  final String descripcion;

  /// Estado en la BD: 'activo' | 'inactivo'.
  /// Las freidoras inactivas no aparecen en las listas pero sus
  /// registros históricos en `log` se mantienen intactos.
  String estado;

  Freidora({
    this.id,
    required this.codigo,
    required this.descripcion,
    this.estado = 'activo',
  });

  /// Convierte el objeto a un Map para insertar/actualizar en SQLite.
  Map<String, dynamic> toMap() => {
        if (id != null) 'id_freidora': id,
        'codigo_freidora': codigo,
        'descripcion': descripcion,
        'estado': estado,
      };

  /// Construye una Freidora a partir de una fila leída de SQLite.
  factory Freidora.fromMap(Map<String, dynamic> m) => Freidora(
        id: m['id_freidora'] as int?,
        codigo: m['codigo_freidora'] as String,
        descripcion: m['descripcion'] as String? ?? '',
        estado: m['estado'] as String? ?? 'activo',
      );
}
