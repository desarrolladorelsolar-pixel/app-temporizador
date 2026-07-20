// =============================================================================
// MODELO: Empleado
// =============================================================================
// Representa a un trabajador del turno. Se usa para:
//   - Mostrar los chips de "Personal en turno" en la pantalla principal.
//   - Registrar quién inició cada cocción en el historial (log).
//
// Los datos se persisten en la tabla SQLite `empleado`.
// =============================================================================

/// Modelo de datos para un empleado de la sucursal.
///
/// El campo [id] es nulo cuando el objeto aún no fue guardado en la BD.
/// Una vez insertado, SQLite asigna un id autoincremental.
class Empleado {
  /// Identificador único en la BD (null si aún no fue insertado).
  final int? id;

  /// Nombre completo del empleado (ej: "Juan Pérez").
  final String nombre;

  /// Carnet de identidad — usado como identificador secundario único.
  final String carnet;

  Empleado({this.id, required this.nombre, required this.carnet});

  /// Convierte el objeto a un Map para insertar/actualizar en SQLite.
  /// El id solo se incluye si ya existe (para evitar conflictos con AUTOINCREMENT).
  Map<String, dynamic> toMap() => {
        if (id != null) 'id_empleado': id,
        'nombre': nombre,
        'ci': carnet,
      };

  /// Construye un Empleado a partir de una fila leída de SQLite.
  factory Empleado.fromMap(Map<String, dynamic> m) => Empleado(
        id: m['id_empleado'] as int?,
        nombre: m['nombre'] as String,
        carnet: m['ci'] as String,
      );
}
