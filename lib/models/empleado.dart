// ── Modelo: Empleado ─────────────────────────────────────────────────────────
class Empleado {
  final int? id;
  final String nombre;
  final String carnet;

  Empleado({this.id, required this.nombre, required this.carnet});

  Map<String, dynamic> toMap() => {
        if (id != null) 'id_empleado': id,
        'nombre': nombre,
        'ci': carnet,
      };

  factory Empleado.fromMap(Map<String, dynamic> m) => Empleado(
        id: m['id_empleado'] as int?,
        nombre: m['nombre'] as String,
        carnet: m['ci'] as String,
      );
}
