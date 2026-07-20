# 📱 Pantallas de la App

## Navegación general

Todas las pantallas comparten el mismo `AppBar` (logo + franja roja) y el mismo `Drawer` lateral.
La navegación entre pantallas usa `pushAndRemoveUntil` sin animación (cambio instantáneo).

---

## SplashScreen
**Archivo:** `lib/screens/splash_screen.dart`

Pantalla de carga que se muestra al abrir la app.
- Logo `logocolor.png` con animación fade-in + rebote elástico.
- Franja roja inferior que aparece con el logo.
- Fade-out de toda la pantalla al terminar (2.2 segundos total).
- Navega automáticamente a `HomeScreen` al finalizar.

---

## HomeScreen — Pantalla Principal
**Archivo:** `lib/screens/home_screen.dart`

Pantalla central de la app. Muestra:
- **Chips de empleados** (sección "Personal en Turno") — el chip seleccionado define quién inicia las cocciones.
- **Grid de TimerCards** — 2 columnas en móvil, 3 en tablets grandes.
- Botón `+` en el AppBar para crear nuevos temporizadores.

Cada `TimerCard` muestra:
- Nombre del producto y código de freidora.
- Botón play (doble tap para iniciar).
- Botón ⏸ mientras corre (con confirmación para pausar).
- Círculo de progreso con countdown cuando está corriendo.

---

## EmpleadosScreen
**Archivo:** `lib/screens/empleados_screen.dart`

CRUD de empleados:
- Lista de empleados registrados.
- Botón ✏️ en cada tarjeta para editar nombre y CI.
- Botón `+` en AppBar para agregar nuevo empleado.

---

## FreidorasScreen
**Archivo:** `lib/screens/freidoras_screen.dart`

CRUD de freidoras:
- Lista de freidoras activas con badge "Disponible".
- Botón `+` para agregar nueva freidora.
- El borrado es soft delete (estado → 'inactivo').

---

## ProductosScreen
**Archivo:** `lib/screens/productos_screen.dart`

CRUD de productos:
- Lista de productos con tiempos de cocción y tostado.
- Botón ✏️ para editar — los cambios se reflejan en los temporizadores activos al instante.
- Botón `+` para agregar nuevo producto.

---

## GestionTemporizadoresScreen
**Archivo:** `lib/screens/gestion_temporizadores_screen.dart`

Administración de temporizadores (acceso desde Menú → Gestionar Temporizadores):
- Lista todos los temporizadores creados.
- Si está en uso (corriendo), muestra badge "En uso" — no se puede eliminar.
- Si está libre, muestra botón 🗑️ con confirmación para eliminar.

---

## LogsScreen — Historial
**Archivo:** `lib/screens/logs_screen.dart`

Exportación del historial de cocciones en PDF:
- Chip "Hoy" — filtra cocciones del día actual.
- Chip "Por fechas" — abre selector de rango de fechas (calendario en español).
- Contador de cocciones en el período seleccionado.
- Botón **Descargar PDF** — genera y comparte el reporte (WhatsApp, Drive, etc.).

---

## AppBar + Drawer

**AppBar** (`lib/widgets/app_bar_principal.dart`):
- Fondo blanco con `logocolor.png` centrado.
- Botón hamburguesa (rojo) a la izquierda.
- Botón `+` (círculo rojo) a la derecha — opcional por pantalla.
- Franja roja de 4px en la parte inferior.

**Drawer** (`lib/widgets/app_drawer.dart`):
- Menú lateral con íconos.
- Ítem activo resaltado en rojo con fondo rosado.
- "Gestionar Temporizadores" aparece sangrado debajo de "Temporizadores".
- Footer con versión: "SUCURSAL CAÑOTO V1.0".
