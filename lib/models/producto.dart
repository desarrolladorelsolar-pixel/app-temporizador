class Producto {
  final int? id;
  final String nombre;
  final int tiempoCoccion;   // en MINUTOS (BD guarda en segundos)
  final int tiempoTostado;   // en MINUTOS (BD guarda en segundos)
  final int tiempoRepaso;    // en MINUTOS, 0 = sin repaso (BD guarda en segundos)
  // La boquilla del repaso se elige al momento de iniciar en la TimerCard

  Producto({
    this.id,
    required this.nombre,
    required this.tiempoCoccion,
    required this.tiempoTostado,
    this.tiempoRepaso = 0,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id_producto': id,
        'nombre': nombre,
        'tiempo_coccion': tiempoCoccion * 60,
        'tiempo_tostado': tiempoTostado * 60,
        'tiempo_repaso': tiempoRepaso * 60,
        'estado': 'activo',
      };

  factory Producto.fromMap(Map<String, dynamic> m) => Producto(
        id: m['id_producto'] as int?,
        nombre: m['nombre'] as String,
        tiempoCoccion: ((m['tiempo_coccion'] as int? ?? 0) ~/ 60),
        tiempoTostado: ((m['tiempo_tostado'] as int? ?? 0) ~/ 60),
        tiempoRepaso: ((m['tiempo_repaso'] as int? ?? 0) ~/ 60),
      );
}
