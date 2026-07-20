// =============================================================================
// MODELO: LogEntry
// =============================================================================
// Representa un registro histórico de una cocción completada.
// Se guarda en la tabla SQLite `log` y NO se modifica una vez cerrado.
//
// DATOS "FOTOGRÁFICOS":
//   Los campos nombre_empleado, nombre_freidora y nombre_producto se guardan
//   como texto en el momento del registro. Esto garantiza que el historial
//   no se altere aunque luego se editen o eliminen esos datos maestros.
//
// TIPOS:
//   'coccion'    → registro normal de un ciclo completado (aparece en PDF)
//   'eliminacion'→ auditoría interna (NO aparece en la app ni en PDF)
// =============================================================================

/// Modelo de un registro del historial de cocciones.
class LogEntry {
  /// Identificador único en la BD.
  final int? id;

  /// ID del temporizador que generó este log (referencia FK).
  final int idTemporizador;

  /// ID del empleado que inició la cocción (referencia FK).
  final int idEmpleado;

  /// Nombre del empleado en el momento del registro (dato fotográfico).
  final String nombreEmpleado;

  /// Código de la freidora en el momento del registro (dato fotográfico).
  final String nombreFreidora;

  /// Nombre del producto en el momento del registro (dato fotográfico).
  final String nombreProducto;

  /// Fecha y hora exacta en que se presionó play para iniciar la cocción.
  final DateTime fechaHoraInicio;

  /// Fecha y hora exacta de finalización del ciclo completo (cocción + tostado).
  /// Es null si el ciclo aún no terminó (log abierto).
  final DateTime? fechaHoraFin;

  /// Tipo del registro: 'coccion' (visible) | 'eliminacion' (auditoría interna).
  final String tipo;

  LogEntry({
    this.id,
    required this.idTemporizador,
    required this.idEmpleado,
    required this.nombreEmpleado,
    required this.nombreFreidora,
    required this.nombreProducto,
    required this.fechaHoraInicio,
    this.fechaHoraFin,
    this.tipo = 'coccion',
  });

  /// Convierte el objeto a un Map para insertar en SQLite.
  Map<String, dynamic> toMap() => {
        if (id != null) 'id_log': id,
        'id_temporizador': idTemporizador,
        'id_empleado': idEmpleado,
        'nombre_empleado': nombreEmpleado,
        'nombre_freidora': nombreFreidora,
        'nombre_producto': nombreProducto,
        'fecha_hora_inicio': fechaHoraInicio.toIso8601String(),
        'fecha_hora_fin': fechaHoraFin?.toIso8601String(),
        'tipo': tipo,
      };

  /// Construye un LogEntry desde una fila de SQLite.
  factory LogEntry.fromMap(Map<String, dynamic> m) => LogEntry(
        id: m['id_log'] as int?,
        idTemporizador: m['id_temporizador'] as int,
        idEmpleado: m['id_empleado'] as int,
        nombreEmpleado: m['nombre_empleado'] as String,
        nombreFreidora: m['nombre_freidora'] as String,
        nombreProducto: m['nombre_producto'] as String,
        fechaHoraInicio: DateTime.parse(m['fecha_hora_inicio'] as String),
        fechaHoraFin: m['fecha_hora_fin'] != null
            ? DateTime.parse(m['fecha_hora_fin'] as String)
            : null,
        tipo: m['tipo'] as String? ?? 'coccion',
      );

  /// Retorna la duración del ciclo en formato legible "Xm Ys".
  /// Retorna '—' si el log aún está abierto (sin fecha_hora_fin).
  String get duracionFormateada {
    if (fechaHoraFin == null) return '—';
    final diff = fechaHoraFin!.difference(fechaHoraInicio);
    final m = diff.inMinutes;
    final s = diff.inSeconds % 60;
    return '${m}m ${s}s';
  }
}
