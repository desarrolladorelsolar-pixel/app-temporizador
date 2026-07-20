// =============================================================================
// ESTADO GLOBAL — AppState
// =============================================================================
// Centraliza toda la lógica de negocio de la app.
// Extiende ChangeNotifier para que los widgets se reconstruyan reactivamente
// cuando se llama notifyListeners().
//
// RESPONSABILIDADES:
//   - Cargar y mantener en memoria: empleados, freidoras, productos, temporizadores, logs.
//   - CRUD de entidades (empleado, freidora, producto, temporizador).
//   - Gestionar el ciclo de vida de los temporizadores (start, tick, pause, resume, finish).
//   - Crear y cerrar registros en la tabla `log`.
//   - Persistir estado en SQLite para sobrevivir cierre de app.
//
// PATRÓN:
//   Los widgets leen datos via context.watch<AppState>() o context.read<AppState>().
//   AppState escribe en BD a través de DatabaseHelper.instance (singleton).
// =============================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/empleado.dart';
import '../models/freidora.dart';
import '../models/log_entry.dart';
import '../models/producto.dart';
import '../models/temporizador.dart';
import '../services/audio_service.dart';
import '../services/database_helper.dart';

/// Estado global de la aplicación — accesible desde cualquier widget via Provider.
class AppState extends ChangeNotifier {

  // ── Listas en memoria ──────────────────────────────────────────────────────
  // Cargadas desde SQLite al iniciar. Son la "fuente de verdad" para la UI.
  final List<Empleado> empleados = [];
  final List<Freidora> freidoras = [];
  final List<Producto> productos = [];
  final List<Temporizador> temporizadores = [];
  List<LogEntry> logs = [];

  /// Empleado seleccionado en los chips de turno.
  /// Es quien se registra como responsable en los logs de cocción.
  /// Se actualiza cuando el usuario toca un chip en HomeScreen.
  Empleado? empleadoActivo;

  // Mapa: índice del temporizador en la lista → su Timer.periodic activo.
  // Se usa para poder cancelar el timer al pausar o finalizar.
  final Map<int, Timer> _timers = {};

  // Mapa auxiliar: índice del temporizador → id del log abierto (sin fecha_hora_fin).
  // Necesario para cerrar el log correcto al finalizar el ciclo.
  final Map<int, int> _logIds = {};

  // Flag para evitar llamar notifyListeners() después de que el objeto fue disposed.
  // Previene el error "setState called after dispose".
  bool _disposed = false;

  // ── INICIALIZACIÓN ─────────────────────────────────────────────────────────

  /// Carga todos los datos desde SQLite y reconstruye el estado en memoria.
  /// Se llama automáticamente al crear AppState en main.dart (`AppState()..init()`).
  Future<void> init() async {
    final db = DatabaseHelper.instance;

    // Carga paralela de datos maestros
    final e = await db.getEmpleados();
    final f = await db.getFreidoras();
    final p = await db.getProductos();
    final rows = await db.getTemporizadores();
    final l = await db.getLogs();

    // Actualiza las listas en memoria
    empleados ..clear() ..addAll(e);
    freidoras ..clear() ..addAll(f);
    productos ..clear() ..addAll(p);
    logs = l;

    // El primer empleado de la lista es el activo por defecto.
    // Solo se setea si no había uno ya (por si init() se llama más de una vez).
    if (empleados.isNotEmpty) empleadoActivo ??= empleados.first;

    temporizadores.clear();
    final ahora = DateTime.now();

    // Reconstruye cada temporizador según su estado guardado en BD
    for (final row in rows) {

      // Busca la freidora y el producto correspondientes por FK
      final freidora = freidoras.firstWhere(
        (fr) => fr.id == row['id_freidora'],
        orElse: () => Freidora(codigo: '??', descripcion: ''), // fallback si fue eliminada
      );
      final producto = productos.firstWhere(
        (pr) => pr.id == row['id_producto'],
        orElse: () => Producto(nombre: '??', tiempoCoccion: 0, tiempoTostado: 0),
      );

      final int totalCoccion = producto.tiempoCoccion * 60; // minutos → segundos
      final int totalTostado = producto.tiempoTostado * 60;
      final String? inicioEnStr = row['inicio_en'] as String?;
      final int? idLogActivo   = row['id_log_activo'] as int?;
      final int  dbId          = row['id_temporizador'] as int;

      if (inicioEnStr != null) {
        // ── Caso 1: Temporizador estaba CORRIENDO cuando cerraron la app ────
        final DateTime inicioEn     = DateTime.parse(inicioEnStr);
        final int      transcurrido = ahora.difference(inicioEn).inSeconds;
        final int      totalCiclo   = totalCoccion + totalTostado;

        if (transcurrido >= totalCiclo) {
          // El ciclo completo ya terminó mientras la app estaba cerrada.
          // Cerramos el log con la fecha real de finalización (no DateTime.now()).
          if (idLogActivo != null) {
            final DateTime finReal = inicioEn.add(Duration(seconds: totalCiclo));
            await db.cerrarLogConFecha(idLogActivo, finReal);
          }
          await db.detenerTemporizador(dbId);

          // Cargamos el temporizador ya reseteado, listo para usar de nuevo
          temporizadores.add(Temporizador(
            id: dbId,
            freidora: freidora,
            producto: producto,
            tiempoCoccionRestante: totalCoccion,
            tiempoTostadoRestante: totalTostado,
            estado: 'coccion',
            corriendo: false,
          ));

        } else {
          // Todavía le queda tiempo → calculamos en qué fase está
          int restanteCoccion;
          int restanteTostado;
          String fase;

          if (transcurrido < totalCoccion) {
            // Sigue en fase de cocción
            restanteCoccion = totalCoccion - transcurrido;
            restanteTostado = totalTostado;
            fase = 'coccion';
          } else {
            // Ya pasó a fase de tostado
            restanteCoccion = 0;
            restanteTostado = totalTostado - (transcurrido - totalCoccion);
            fase = 'tostado';
          }

          final t = Temporizador(
            id: dbId,
            freidora: freidora,
            producto: producto,
            tiempoCoccionRestante: restanteCoccion,
            tiempoTostadoRestante: restanteTostado,
            estado: fase,
            corriendo: true,
            iniciadoEn: inicioEn,
          );
          temporizadores.add(t);

          // Reanuda el Timer en memoria desde la posición calculada
          final idx = temporizadores.length - 1;
          if (idLogActivo != null) _logIds[idx] = idLogActivo;
          _timers[idx] =
              Timer.periodic(const Duration(seconds: 1), (_) => _tick(idx));
        }

      } else {
        // ── Caso 2: Temporizador DETENIDO, PAUSADO, o ESPERANDO TOSTADO ─────
        final String estadoBD      = row['estado'] as String? ?? 'detenido';
        final int? idLogGuardado   = row['id_log_activo'] as int?;
        final String? antePausa    = row['estado_antes_pausa'] as String?;
        final int? coccionGuardada = row['tiempo_coccion_restante'] as int?;
        final int? tostadoGuardado = row['tiempo_tostado_restante'] as int?;

        final int idx = temporizadores.length;

        if (estadoBD == 'pausado' && antePausa != null &&
            coccionGuardada != null && tostadoGuardado != null) {
          // Recupera el estado de pausa exacto con los tiempos guardados
          temporizadores.add(Temporizador(
            id: dbId,
            freidora: freidora,
            producto: producto,
            tiempoCoccionRestante: coccionGuardada,
            tiempoTostadoRestante: tostadoGuardado,
            estado: 'pausado',
            estadoAntesDePausa: antePausa,
            corriendo: false,
          ));
        } else if (estadoBD == 'pausado' &&
            antePausa == 'esperando_tostado' &&
            tostadoGuardado != null) {
          // Recupera el estado "esperando que el usuario inicie el tostado"
          temporizadores.add(Temporizador(
            id: dbId,
            freidora: freidora,
            producto: producto,
            tiempoCoccionRestante: 0,
            tiempoTostadoRestante: tostadoGuardado,
            estado: 'esperando_tostado',
            corriendo: false,
          ));
        } else {
          // Detenido normal — carga los tiempos completos del producto
          temporizadores.add(Temporizador(
            id: dbId,
            freidora: freidora,
            producto: producto,
            tiempoCoccionRestante: totalCoccion,
            tiempoTostadoRestante: totalTostado,
            estado: 'coccion',
            corriendo: false,
          ));
        }

        // Si había un log abierto (pausa/esperando_tostado), lo recupera
        // para poder cerrarlo correctamente cuando termine el ciclo
        if (idLogGuardado != null && idLogGuardado > 0) {
          _logIds[idx] = idLogGuardado;
        }
      }
    }

    notifyListeners(); // actualiza toda la UI con los datos cargados
  }

  // ── SELECCIÓN DE EMPLEADO ──────────────────────────────────────────────────

  /// Actualiza el empleado activo cuando el usuario toca un chip en HomeScreen.
  /// No llama notifyListeners() porque no necesita reconstruir la UI.
  void seleccionarEmpleado(Empleado e) {
    empleadoActivo = e;
  }

  // ── CRUD: EMPLEADOS ────────────────────────────────────────────────────────

  /// Inserta un nuevo empleado en BD y actualiza la lista en memoria.
  Future<void> agregarEmpleado(Empleado e) async {
    final id = await DatabaseHelper.instance.insertEmpleado(e);
    empleados.add(Empleado(id: id, nombre: e.nombre, carnet: e.carnet));
    notifyListeners();
  }

  /// Actualiza un empleado existente en BD y en memoria.
  Future<void> updateEmpleado(int index, Empleado actualizado) async {
    await DatabaseHelper.instance.updateEmpleado(actualizado);
    empleados[index] = actualizado;
    notifyListeners();
  }

  /// Elimina un empleado de BD y de la lista en memoria.
  Future<void> eliminarEmpleado(int index) async {
    final e = empleados[index];
    if (e.id != null) await DatabaseHelper.instance.deleteEmpleado(e.id!);
    empleados.removeAt(index);
    notifyListeners();
  }

  // ── CRUD: FREIDORAS ────────────────────────────────────────────────────────

  /// Inserta una nueva freidora en BD y actualiza la lista en memoria.
  Future<void> agregarFreidora(Freidora f) async {
    final id = await DatabaseHelper.instance.insertFreidora(f);
    freidoras.add(Freidora(
        id: id, codigo: f.codigo, descripcion: f.descripcion, estado: f.estado));
    notifyListeners();
  }

  /// Soft delete: marca la freidora como 'inactivo' en BD y la quita de la lista.
  Future<void> eliminarFreidora(int index) async {
    final f = freidoras[index];
    if (f.id != null) await DatabaseHelper.instance.deleteFreidora(f.id!);
    freidoras.removeAt(index);
    notifyListeners();
  }

  // ── CRUD: PRODUCTOS ────────────────────────────────────────────────────────

  /// Inserta un nuevo producto en BD y actualiza la lista en memoria.
  Future<void> agregarProducto(Producto p) async {
    final id = await DatabaseHelper.instance.insertProducto(p);
    productos.add(Producto(
        id: id,
        nombre: p.nombre,
        tiempoCoccion: p.tiempoCoccion,
        tiempoTostado: p.tiempoTostado));
    notifyListeners();
  }

  /// Actualiza un producto y también actualiza los temporizadores activos
  /// que usen ese producto para reflejar los nuevos tiempos al instante.
  Future<void> updateProducto(int index, Producto actualizado) async {
    await DatabaseHelper.instance.updateProducto(actualizado);
    productos[index] = actualizado;

    // Actualiza en caliente los temporizadores que usan este producto
    // Solo los que no están corriendo (para no interrumpir un ciclo activo)
    for (final t in temporizadores) {
      if (t.producto.id == actualizado.id && !t.corriendo) {
        t.producto = actualizado;
        t.tiempoCoccionRestante = actualizado.tiempoCoccion * 60;
        t.tiempoTostadoRestante = actualizado.tiempoTostado * 60;
      }
    }
    notifyListeners();
  }

  /// Soft delete del producto y eliminación de la lista en memoria.
  Future<void> eliminarProducto(int index) async {
    final p = productos[index];
    if (p.id != null) await DatabaseHelper.instance.deleteProducto(p.id!);
    productos.removeAt(index);
    notifyListeners();
  }

  // ── CRUD: TEMPORIZADORES ───────────────────────────────────────────────────

  /// Crea un nuevo temporizador en BD y lo agrega a la lista en memoria.
  /// Los temporizadores son plantillas reutilizables — no se borran al finalizar.
  Future<void> agregarTemporizador(Temporizador t) async {
    int dbId = 0;
    if (t.freidora.id != null && t.producto.id != null) {
      dbId = await DatabaseHelper.instance.insertTemporizador(
        idFreidora: t.freidora.id!,
        idProducto: t.producto.id!,
        tiempoSegundos: t.tiempoCoccionRestante + t.tiempoTostadoRestante,
      );
    }
    temporizadores.add(Temporizador(
      id: dbId,
      freidora: t.freidora,
      producto: t.producto,
      tiempoCoccionRestante: t.tiempoCoccionRestante,
      tiempoTostadoRestante: t.tiempoTostadoRestante,
      estado: t.estado,
      corriendo: t.corriendo,
    ));
    notifyListeners();
  }

  // ── CICLO DE VIDA DEL TEMPORIZADOR ─────────────────────────────────────────

  /// Inicia un temporizador (cocción o tostado según el estado actual).
  /// Se llama con doble tap en la TimerCard.
  Future<void> toggleTemporizador(int index) async {
    final t = temporizadores[index];
    if (t.corriendo) return; // ya corriendo, ignorar

    final ahora = DateTime.now();

    if (t.estado == 'esperando_tostado') {
      // ── Iniciar tostado manualmente ──────────────────────────────────────
      // El log YA está abierto (se creó al iniciar cocción).
      // Solo actualizamos inicio_en en BD para el cálculo de tiempo restante.
      t.iniciadoEn = ahora;
      t.estado = 'tostado';
      t.corriendo = true;

      if (t.id != null && t.id! > 0) {
        final logId = _logIds[index] ?? 0; // mismo log abierto de cocción
        await DatabaseHelper.instance.iniciarTemporizador(t.id!, ahora, logId);
      }

      _timers[index] =
          Timer.periodic(const Duration(seconds: 1), (_) => _tick(index));
      notifyListeners();
      return;
    }

    // ── Iniciar cocción ────────────────────────────────────────────────────
    // Determina el responsable: empleadoActivo (chip seleccionado) o el primero de la lista.
    t.iniciadoEn = ahora;
    final responsable = empleadoActivo ??
        (empleados.isNotEmpty ? empleados.first : null);

    int logId = 0;
    if (t.id != null && t.id! > 0 && responsable != null) {
      // Abre el log con los datos "fotográficos" del momento actual
      logId = await DatabaseHelper.instance.insertLog(
        LogEntry(
          idTemporizador: t.id!,
          idEmpleado: responsable.id ?? 0,
          nombreEmpleado: responsable.nombre,
          nombreFreidora: t.freidora.codigo,
          nombreProducto: t.producto.nombre,
          fechaHoraInicio: ahora,
        ),
      );
      _logIds[index] = logId;
    }

    // Persiste inicio_en en BD para que si la app se cierra,
    // al reabrir se calcule el tiempo transcurrido correctamente
    if (t.id != null && t.id! > 0) {
      await DatabaseHelper.instance.iniciarTemporizador(t.id!, ahora, logId);
    }

    t.corriendo = true;
    _timers[index] =
        Timer.periodic(const Duration(seconds: 1), (_) => _tick(index));
    notifyListeners();
  }

  /// Tick interno: descuenta 1 segundo cada vez que Timer.periodic dispara.
  void _tick(int index) {
    if (index >= temporizadores.length) {
      // El temporizador fue eliminado mientras corría — cancela el timer
      _timers[index]?.cancel();
      _timers.remove(index);
      return;
    }

    final t = temporizadores[index];

    if (t.estado == 'coccion') {
      if (t.tiempoCoccionRestante > 1) {
        t.tiempoCoccionRestante--; // descuenta 1 segundo

      } else if (t.tiempoCoccionRestante == 1) {
        // Último segundo de cocción
        t.tiempoCoccionRestante = 0;
        _timers[index]?.cancel();
        _timers.remove(index);
        t.corriendo = false;

        if (t.tiempoTostadoRestante > 0) {
          // Pasa a esperar que el usuario inicie el tostado manualmente
          // IMPORTANTE: NO se llama detenerTemporizador porque borraría id_log_activo.
          // El log sigue abierto hasta que termine el tostado.
          t.estado = 'esperando_tostado';
          AudioService.sonarTostado(); // beep de alerta

          // Persiste en BD: tiempos restantes de tostado para recuperar al reabrir
          if (t.id != null && t.id! > 0) {
            DatabaseHelper.instance.pausarLogActivo(
              t.id!,
              tiempoCoccionRestante: 0,
              tiempoTostadoRestante: t.tiempoTostadoRestante,
              estadoAntesPausa: 'esperando_tostado',
            );
          }
        } else {
          // Sin tostado → finaliza el ciclo completo
          _finalizarTemporizador(t, index);
          AudioService.sonarFin(); // beep de fin
        }
      }

    } else if (t.estado == 'tostado') {
      if (t.tiempoTostadoRestante > 1) {
        t.tiempoTostadoRestante--;

      } else if (t.tiempoTostadoRestante == 1) {
        t.tiempoTostadoRestante = 0;
        _finalizarTemporizador(t, index);
        AudioService.sonarFin();
      } else {
        _finalizarTemporizador(t, index); // fallback
      }
    }

    notifyListeners(); // actualiza la UI con el nuevo tiempo restante
  }

  /// Cierra el log con la fecha exacta de fin y resetea el temporizador
  /// para que quede listo para usarse de nuevo.
  void _finalizarTemporizador(Temporizador t, int index) {
    _timers[index]?.cancel();
    _timers.remove(index);

    final logId = _logIds.remove(index);
    final ahora = DateTime.now();

    if (logId != null && logId > 0) {
      // Cierra el log con la fecha/hora exacta de finalización
      DatabaseHelper.instance.cerrarLogConFecha(logId, ahora).then((_) async {
        logs = await DatabaseHelper.instance.getLogs(); // refresca la lista
        if (!_disposed) notifyListeners();
      });
    }

    // Resetea la fila en BD (limpia inicio_en e id_log_activo)
    if (t.id != null && t.id! > 0) {
      DatabaseHelper.instance.detenerTemporizador(t.id!);
    }

    // Resetea el temporizador en memoria con los tiempos originales del producto
    t.tiempoCoccionRestante = t.producto.tiempoCoccion * 60;
    t.tiempoTostadoRestante = t.producto.tiempoTostado * 60;
    t.estado = 'coccion';
    t.corriendo = false;
    t.iniciadoEn = null;
    // notifyListeners() se llama desde _tick() justo después de esta llamada
  }

  /// Pausa el temporizador y guarda el estado exacto en BD
  /// para recuperarlo si la app se cierra mientras está pausado.
  void pausarTemporizador(int index) {
    final t = temporizadores[index];
    if (!t.corriendo) return;

    _timers[index]?.cancel();
    _timers.remove(index);

    t.estadoAntesDePausa = t.estado; // guarda si estaba en 'coccion' o 'tostado'
    t.estado = 'pausado';
    t.corriendo = false;

    // Persiste en BD: tiempos restantes y fase previa para recuperar al reabrir
    // NO se borra id_log_activo — el log sigue abierto para cerrarlo al terminar
    if (t.id != null && t.id! > 0) {
      DatabaseHelper.instance.pausarLogActivo(
        t.id!,
        tiempoCoccionRestante: t.tiempoCoccionRestante,
        tiempoTostadoRestante: t.tiempoTostadoRestante,
        estadoAntesPausa: t.estadoAntesDePausa!,
      );
    }

    notifyListeners();
  }

  /// Reanuda un temporizador pausado desde el tiempo exacto donde se detuvo.
  Future<void> reanudarTemporizador(int index) async {
    final t = temporizadores[index];
    if (t.estado != 'pausado') return;

    // Restaura el estado previo a la pausa
    t.estado = t.estadoAntesDePausa ?? 'coccion';
    t.estadoAntesDePausa = null;
    t.corriendo = true;

    final ahora = DateTime.now();

    // Persiste el nuevo inicio_en para que si cierran la app,
    // al reabrir se calcule el tiempo transcurrido desde este punto
    if (t.id != null && t.id! > 0) {
      await DatabaseHelper.instance.iniciarTemporizador(
          t.id!, ahora, _logIds[index] ?? 0);
    }

    _timers[index] =
        Timer.periodic(const Duration(seconds: 1), (_) => _tick(index));
    notifyListeners();
  }

  /// Elimina permanentemente un temporizador de BD y de memoria.
  /// Solo se puede eliminar si no está corriendo (la UI lo controla).
  Future<void> eliminarTemporizador(int index) async {
    final t = temporizadores[index];
    _timers[index]?.cancel();
    _timers.remove(index);
    _logIds.remove(index);

    if (t.id != null && t.id! > 0) {
      await DatabaseHelper.instance.deleteTemporizador(t.id!);
    }

    temporizadores.removeAt(index);
    notifyListeners();
  }

  // ── LOGS ───────────────────────────────────────────────────────────────────

  /// Recarga la lista de logs desde BD.
  /// Llamado al entrar a la pantalla de Historial.
  Future<void> recargarLogs() async {
    logs = await DatabaseHelper.instance.getLogs();
    notifyListeners();
  }

  // ── DISPOSE ────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _disposed = true; // evita llamadas a notifyListeners() post-dispose

    // Cancela todos los timers activos para liberar recursos
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    _logIds.clear();

    super.dispose();
  }
}
