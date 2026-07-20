# 📦 Modelos de Datos

Todos los modelos están en `lib/models/`. Cada uno implementa:
- `toMap()` → convierte a Map para insertar/actualizar en SQLite.
- `fromMap()` → construye el objeto desde una fila de SQLite.

---

## Empleado
```dart
class Empleado {
  final int? id;       // PK en BD (null antes de insertar)
  final String nombre; // Nombre completo
  final String carnet; // CI único
}
```

---

## Freidora
```dart
class Freidora {
  final int? id;
  final String codigo;       // Identificador único (ej: "FR-01")
  final String descripcion;  // Texto descriptivo opcional
  String estado;             // 'activo' | 'inactivo'
}
```
> El `estado` es mutable para permitir el soft delete.

---

## Producto
```dart
class Producto {
  final int? id;
  final String nombre;
  final int tiempoCoccion; // en MINUTOS (BD guarda en segundos)
  final int tiempoTostado; // en MINUTOS (BD guarda en segundos)
}
```
> El campo `producto` en `Temporizador` es **mutable** para reflejar ediciones en caliente.

---

## Temporizador
```dart
class Temporizador {
  final int? id;
  final Freidora freidora;
  Producto producto;              // mutable (edición en caliente)
  int tiempoCoccionRestante;      // segundos restantes
  int tiempoTostadoRestante;      // segundos restantes
  String estado;                  // 'coccion'|'esperando_tostado'|'tostado'|'pausado'
  bool corriendo;
  String? estadoAntesDePausa;     // para reanudar en la fase correcta
  DateTime? iniciadoEn;           // persiste en BD para sobrevivir cierre
}
```

---

## LogEntry
```dart
class LogEntry {
  final int? id;
  final int idTemporizador;
  final int idEmpleado;
  final String nombreEmpleado;  // foto del nombre al momento del registro
  final String nombreFreidora;  // foto del código al momento del registro
  final String nombreProducto;  // foto del nombre al momento del registro
  final DateTime fechaHoraInicio;
  final DateTime? fechaHoraFin; // null si el ciclo aún no terminó
  final String tipo;            // 'coccion' | 'eliminacion'
}
```
> `duracionFormateada` calcula la duración como "Xm Ys" si `fechaHoraFin != null`.
