// ── Modelo: LogEntry ─────────────────────────────────────────────────────────
// tipo: 'coccion' | 'eliminacion'
class LogEntry {
  final int? id;
  final int idTemporizador;
  final int idEmpleado;
  final String nombreEmpleado;
  final String nombreFreidora;
  final String nombreProducto;
  final DateTime fechaHoraInicio;
  final DateTime? fechaHoraFin;
  final String tipo; // 'coccion' | 'eliminacion'

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

  String get duracionFormateada {
    if (fechaHoraFin == null) return '—';
    final diff = fechaHoraFin!.difference(fechaHoraInicio);
    final m = diff.inMinutes;
    final s = diff.inSeconds % 60;
    return '${m}m ${s}s';
  }
}
