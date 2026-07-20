# ⏱️ Flujo de Vida de un Temporizador

## Diagrama de estados

```
[COCCIÓN] ──doble tap──▶ [CORRIENDO COCCIÓN] ──fin cocción──▶ [ESPERANDO TOSTADO]
    ▲                           │ pausa                               │ doble tap
    │                           ▼                                     ▼
    │                       [PAUSADO] ──doble tap──▶ [CORRIENDO TOSTADO] ──fin──▶ reset
    │                                                                               │
    └───────────────────────────────────────────────────────────────────────────────┘
```

---

## Descripción de cada estado

### `coccion` (botón play rojo, esperando doble tap)
- El temporizador está detenido en la fase de cocción.
- El usuario debe hacer **doble tap** para iniciar.
- Se registra el `empleadoActivo` seleccionado en los chips.
- Se crea un nuevo registro en la tabla `log` con `fecha_hora_inicio`.

### `corriendo cocción` (círculo rojo con countdown)
- `Timer.periodic` descuenta 1 segundo cada tick.
- El botón ⏸ (pausa) aparece en la esquina de la card.
- Al llegar a 0:
  - Si tiene tiempo de tostado → pasa a `esperando_tostado`.
  - Si no tiene tostado → finaliza directamente.

### `esperando_tostado` (botón naranja pulsante)
- La cocción terminó y suena el beep de transición.
- El timer se detiene pero el log sigue abierto.
- El estado se persiste en BD para sobrevivir cierre de app.
- El usuario debe hacer **doble tap** para iniciar el tostado.

### `corriendo tostado` (círculo naranja con countdown)
- Timer descuenta el tiempo de tostado.
- Al llegar a 0 → suena el beep final → el ciclo finaliza.

### `pausado` (botón gris con ícono play)
- El timer se detiene manualmente con el botón ⏸.
- Se persiste en BD: `tiempo_coccion_restante`, `tiempo_tostado_restante`, `estado_antes_pausa`.
- Al reabrir la app, el temporizador se reconstruye en estado pausado exacto.
- **Doble tap** para reanudar desde donde se detuvo.

---

## Persistencia al cerrar la app

| Estado al cerrar | Al reabrir |
|---|---|
| Corriendo cocción | Calcula tiempo transcurrido. Si ya terminó: cierra log con fecha real. Si le queda: reanuda automáticamente. |
| Esperando tostado | Aparece con botón naranja esperando doble tap |
| Corriendo tostado | Igual que cocción: calcula transcurrido |
| Pausado | Aparece en estado pausado con tiempo exacto conservado |
| Detenido | Aparece listo para iniciar |

---

## Ciclo del Log

```
doble tap cocción
    → INSERT log (fecha_hora_inicio, id_empleado, nombres...)
    → temporizador.id_log_activo = logId

cocción termina (con tostado)
    → pausarLogActivo() — guarda estado en BD, NO cierra el log

doble tap tostado
    → iniciarTemporizador() con el mismo logId

tostado termina
    → cerrarLogConFecha(logId, DateTime.now())
    → detenerTemporizador() — limpia inicio_en e id_log_activo
    → temporizador se resetea para reusar
```

> **Importante:** Un solo log cubre el ciclo completo (cocción + tostado).
> El empleado registrado es siempre el que inició la cocción,
> no quien inició el tostado.
