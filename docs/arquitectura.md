# 🏗️ Arquitectura del Proyecto

## Estructura de carpetas

```
lib/
├── main.dart                    # Punto de entrada, configuración de tema y Provider
├── models/                      # Modelos de datos (entidades de negocio)
│   ├── empleado.dart
│   ├── freidora.dart
│   ├── producto.dart
│   ├── temporizador.dart
│   └── log_entry.dart
├── state/                       # Estado global de la app
│   └── app_state.dart           # ChangeNotifier con toda la lógica de negocio
├── services/                    # Servicios externos
│   ├── database_helper.dart     # Singleton SQLite
│   ├── audio_service.dart       # Reproducción de beeps
│   └── pdf_service.dart         # Generación y exportación de PDF
├── screens/                     # Pantallas completas
│   ├── splash_screen.dart       # Pantalla de carga con animación
│   ├── home_screen.dart         # Pantalla principal (grid de temporizadores)
│   ├── empleados_screen.dart    # CRUD de empleados
│   ├── freidoras_screen.dart    # CRUD de freidoras
│   ├── productos_screen.dart    # CRUD de productos
│   ├── gestion_temporizadores_screen.dart  # Gestión y eliminación de temporizadores
│   └── logs_screen.dart         # Historial con filtros y exportación PDF
└── widgets/                     # Widgets reutilizables
    ├── app_bar_principal.dart   # AppBar con logo + franja roja
    ├── app_drawer.dart          # Menú lateral de navegación
    ├── timer_card.dart          # Card de temporizador (StatefulWidget)
    ├── employee_chip.dart       # Chip de empleado en turno
    ├── estado_vacio.dart        # Placeholder cuando no hay datos
    └── new_timer_modal.dart     # Modal para crear nuevo temporizador
```

## Patrón de arquitectura

La app usa **Provider + ChangeNotifier** como gestión de estado:

```
UI (Widgets/Screens)
      ↕ context.watch / context.read
AppState (ChangeNotifier)
      ↕ async calls
DatabaseHelper (SQLite Singleton)
```

- **UI** solo lee y dibuja. No contiene lógica de negocio.
- **AppState** centraliza toda la lógica: timers, CRUD, logs.
- **DatabaseHelper** es el único punto de acceso a SQLite.

## Flujo de datos al iniciar la app

```
main() → AppState.init()
           ├── getEmpleados()    → empleados[]
           ├── getFreidoras()    → freidoras[]
           ├── getProductos()    → productos[]
           ├── getTemporizadores() → reconstruye estado (corriendo/pausado/detenido)
           └── getLogs()         → logs[]
         → notifyListeners() → UI se actualiza
```
