# 📚 Documentación — App Temporizador El Solar

Bienvenido a la documentación técnica de la aplicación de control de freidoras
para la **Sucursal Cañoto de El Solar**.

## Índice

| Documento | Descripción |
|-----------|-------------|
| [arquitectura.md](./arquitectura.md) | Estructura del proyecto y capas de la app |
| [base_de_datos.md](./base_de_datos.md) | Esquema SQLite, tablas, índices y migraciones |
| [flujo_temporizadores.md](./flujo_temporizadores.md) | Ciclo de vida completo de un temporizador |
| [modelos.md](./modelos.md) | Descripción de los modelos de datos |
| [pantallas.md](./pantallas.md) | Descripción de cada pantalla de la app |
| [build_deploy.md](./build_deploy.md) | Cómo compilar e instalar la APK |

---

## Resumen del proyecto

Aplicación Android desarrollada en **Flutter/Dart** para gestionar los tiempos
de cocción de las freidoras de la sucursal. Permite:

- Registrar empleados, freidoras y productos
- Crear temporizadores por producto/freidora con doble tap para iniciar
- Ciclo de dos fases: **cocción** → **tostado** (inicio manual)
- Pausar y reanudar temporizadores, con persistencia al cerrar la app
- Historial de cocciones exportable en PDF filtrado por fecha

**Stack:** Flutter 3.x · Dart 3.2 · SQLite (sqflite) · Provider · PDF/Printing
