// ── Modelo: Freidora ─────────────────────────────────────────────────────────
class Freidora {
  final int? id;
  final String codigo;
  final String descripcion;
  String estado; // 'activo' | 'inactivo'

  Freidora({
    this.id,
    required this.codigo,
    required this.descripcion,
    this.estado = 'activo',
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id_freidora': id,
        'codigo_freidora': codigo,
        'descripcion': descripcion,
        'estado': estado,
      };

  factory Freidora.fromMap(Map<String, dynamic> m) => Freidora(
        id: m['id_freidora'] as int?,
        codigo: m['codigo_freidora'] as String,
        descripcion: m['descripcion'] as String? ?? '',
        estado: m['estado'] as String? ?? 'activo',
      );
}
