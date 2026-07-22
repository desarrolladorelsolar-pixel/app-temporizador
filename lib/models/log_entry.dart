// =============================================================================
// MODELO: LogEntry — v2.0
// =============================================================================
// Representa un registro histórico de una fase de cocción.
// v2.0: cada ciclo genera DOS logs — uno por boquilla:
//   boquilla 1 → se abre al iniciar cocción, se cierra al terminar cocción
//   boquilla 2 → se abre al iniciar tostado, se cierra al terminar tostado
// Los logs anteriores (pre v5) tienen boquilla=1 por compatibilidad.
// =============================================================================

class LogEntry {
  final int? id;
  final int idTemporizador;
  final int idEmpleado;
  final String nombreEmpleado;  // dato "fotográfico" al momento del registro
  final String nombreFreidora;  // dato "fotográfico"
  final String nombreProducto;  // dato "fotográfico"
  final DateTime fechaHoraInicio;
  final DateTime? fechaHoraFin; // null si aún no terminó
  final String tipo;            // 'coccion' (visible) | 'eliminacion' (auditoría)
  final int boquilla;           // 1 = Boquilla 1 (cocción) | 2 = Boquilla 2 (tostado)

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
    this.boquilla = 1,
  });

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
        'boquilla': boquilla,
      };

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
        boquilla: m['boquilla'] as int? ?? 1,
      );

  /// Duración en formato "Xm Ys". Retorna '—' si el log aún no está cerrado.
  String get duracionFormateada {
    if (fechaHoraFin == null) return '—';
    final diff = fechaHoraFin!.difference(fechaHoraInicio);
    final m = diff.inMinutes;
    final s = diff.inSeconds % 60;
    return '${m}m ${s}s';
  }
}
