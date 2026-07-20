# 🗄️ Base de Datos — SQLite

La app usa **SQLite** a través del paquete `sqflite`. El archivo de base de datos
se llama `elsolar.db` y se almacena en el directorio privado de la app en el dispositivo.

## Versión actual: 4

Cada versión agrega columnas mediante `ALTER TABLE` en `_onUpgrade`.

---

## Tablas

### `empleado`
| Columna      | Tipo    | Descripción                          |
|--------------|---------|--------------------------------------|
| id_empleado  | INTEGER | PK autoincremental                   |
| nombre       | TEXT    | Nombre completo del empleado         |
| ci           | TEXT    | Carnet de identidad (único)          |

---

### `freidora`
| Columna         | Tipo    | Descripción                              |
|-----------------|---------|------------------------------------------|
| id_freidora     | INTEGER | PK autoincremental                       |
| codigo_freidora | TEXT    | Código único (ej: "FR-01")               |
| descripcion     | TEXT    | Descripción opcional                     |
| estado          | TEXT    | 'activo' o 'inactivo' (soft delete)      |

> Las freidoras se marcan como 'inactivo' en vez de borrarse para no romper los logs históricos.

---

### `producto`
| Columna        | Tipo    | Descripción                              |
|----------------|---------|------------------------------------------|
| id_producto    | INTEGER | PK autoincremental                       |
| nombre         | TEXT    | Nombre del producto (ej: "Pollo Broaster")|
| tiempo_coccion | INTEGER | Tiempo de cocción en **segundos**         |
| tiempo_tostado | INTEGER | Tiempo de tostado en **segundos**         |
| estado         | TEXT    | 'activo' o 'inactivo' (soft delete)      |

> Los tiempos se guardan en segundos en la BD pero la UI los muestra en minutos.

---

### `temporizador`
| Columna                 | Tipo    | Descripción                                      |
|-------------------------|---------|--------------------------------------------------|
| id_temporizador         | INTEGER | PK autoincremental                               |
| id_freidora             | INTEGER | FK → freidora.id_freidora                        |
| id_producto             | INTEGER | FK → producto.id_producto                        |
| estado                  | TEXT    | 'detenido' / 'en_curso' / 'pausado'              |
| tiempo                  | INTEGER | Tiempo total del ciclo en segundos               |
| inicio_en               | TEXT    | ISO8601: cuándo empezó (null si detenido/pausado)|
| id_log_activo           | INTEGER | ID del log abierto durante el ciclo actual       |
| tiempo_coccion_restante | INTEGER | Segundos restantes de cocción (guardado al pausar)|
| tiempo_tostado_restante | INTEGER | Segundos restantes de tostado (guardado al pausar)|
| estado_antes_pausa      | TEXT    | Estado previo a la pausa para reanudar           |

> Los temporizadores son **plantillas reutilizables** — no se eliminan al finalizar un ciclo.

---

### `log`
| Columna           | Tipo    | Descripción                                     |
|-------------------|---------|-------------------------------------------------|
| id_log            | INTEGER | PK autoincremental                              |
| id_temporizador   | INTEGER | FK → temporizador.id_temporizador               |
| id_empleado       | INTEGER | FK → empleado.id_empleado                       |
| nombre_empleado   | TEXT    | Nombre del empleado al momento del registro     |
| nombre_freidora   | TEXT    | Código de la freidora al momento del registro   |
| nombre_producto   | TEXT    | Nombre del producto al momento del registro     |
| fecha_hora_inicio | TEXT    | ISO8601: inicio de cocción                      |
| fecha_hora_fin    | TEXT    | ISO8601: fin del ciclo (null si aún no terminó) |
| tipo              | TEXT    | 'coccion' (visible en PDF) o 'eliminacion'      |

> Los nombres se guardan como texto "fotográfico" para que el historial no cambie si luego se editan los datos maestros.

---

## Índices

```sql
idx_temporizador_freidora  → temporizador(id_freidora)
idx_temporizador_producto  → temporizador(id_producto)
idx_log_temporizador       → log(id_temporizador)
idx_log_empleado           → log(id_empleado)
idx_log_fecha_inicio       → log(fecha_hora_inicio)
```

---

## Optimizaciones de rendimiento

```sql
PRAGMA journal_mode = WAL;   -- Lecturas concurrentes sin bloquear escrituras
PRAGMA cache_size = -4000;   -- Cache de páginas: 4 MB
```

Se aplican automáticamente cada vez que se abre la BD.

---

## Historial de migraciones

| Versión | Cambio                                                              |
|---------|---------------------------------------------------------------------|
| v1      | Creación inicial de las 5 tablas e índices                          |
| v2      | Se añaden `inicio_en` e `id_log_activo` a `temporizador`            |
| v3      | Se añade columna `tipo` a `log`                                     |
| v4      | Se añaden `tiempo_coccion_restante`, `tiempo_tostado_restante` y `estado_antes_pausa` a `temporizador` para persistir el estado de pausa |
