import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/empleado.dart';
import '../models/freidora.dart';
import '../models/log_entry.dart';
import '../models/producto.dart';
import '../models/temporizador.dart';
import '../services/audio_service.dart';
import '../services/database_helper.dart';

// ── Estado global de la app ──────────────────────────────────────────────────
// Combina ChangeNotifier (UI reactiva) con SQLite (persistencia).
class AppState extends ChangeNotifier {
  // ── Listas en memoria (cargadas desde SQLite al iniciar) ──────────────────
  final List<Empleado> empleados = [];
  final List<Freidora> freidoras = [];
  final List<Producto> productos = [];
  final List<Temporizador> temporizadores = [];
  List<LogEntry> logs = [];

  // Empleado seleccionado en los chips de turno — se usa en los logs
  Empleado? empleadoActivo;

  // Mapa: índice del temporizador → Timer activo
  final Map<int, Timer> _timers = {};
  // Flag para evitar notifyListeners después de dispose
  bool _disposed = false;

  // ── Inicialización: carga datos desde SQLite ──────────────────────────────
  Future<void> init() async {
    final db = DatabaseHelper.instance;
    final e = await db.getEmpleados();
    final f = await db.getFreidoras();
    final p = await db.getProductos();
    final rows = await db.getTemporizadores();
    final l = await db.getLogs();

    empleados ..clear() ..addAll(e);
    freidoras ..clear() ..addAll(f);
    productos ..clear() ..addAll(p);
    logs = l;

    // Seleccionar el primer empleado por defecto
    if (empleados.isNotEmpty) empleadoActivo ??= empleados.first;

    temporizadores.clear();
    final ahora = DateTime.now();

    for (final row in rows) {
      final freidora = freidoras.firstWhere(
        (fr) => fr.id == row['id_freidora'],
        orElse: () => Freidora(codigo: '??', descripcion: ''),
      );
      final producto = productos.firstWhere(
        (pr) => pr.id == row['id_producto'],
        orElse: () => Producto(nombre: '??', tiempoCoccion: 0, tiempoTostado: 0),
      );

      final int totalCoccion = producto.tiempoCoccion * 60;
      final int totalTostado = producto.tiempoTostado * 60;
      final String? inicioEnStr = row['inicio_en'] as String?;
      final int? idLogActivo  = row['id_log_activo'] as int?;
      final int  dbId         = row['id_temporizador'] as int;

      // ── Temporizador estaba corriendo cuando cerraron la app ─────────────
      if (inicioEnStr != null) {
        final DateTime inicioEn    = DateTime.parse(inicioEnStr);
        final int      transcurrido = ahora.difference(inicioEn).inSeconds;
        final int      totalCiclo   = totalCoccion + totalTostado;

        if (transcurrido >= totalCiclo) {
          // Ya terminó mientras la app estaba cerrada.
          // fecha_hora_fin = inicio_en + duración real del ciclo (no DateTime.now())
          if (idLogActivo != null) {
            final DateTime finReal =
                inicioEn.add(Duration(seconds: totalCiclo));
            await db.cerrarLogConFecha(idLogActivo, finReal);
          }
          await db.detenerTemporizador(dbId);
          // Lo cargamos ya reseteado
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
          // Todavía le queda tiempo → calcular dónde estamos en el ciclo
          int restanteCoccion;
          int restanteTostado;
          String fase;

          if (transcurrido < totalCoccion) {
            restanteCoccion = totalCoccion - transcurrido;
            restanteTostado = totalTostado;
            fase = 'coccion';
          } else {
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

          // Reanudar el Timer en memoria
          final idx = temporizadores.length - 1;
          if (idLogActivo != null) _logIds[idx] = idLogActivo;
          _timers[idx] =
              Timer.periodic(const Duration(seconds: 1), (_) => _tick(idx));
        }
      } else {
        // Sin inicio_en → puede ser: detenido, pausado, o esperando_tostado
        final String estadoBD      = row['estado'] as String? ?? 'detenido';
        final int? idLogGuardado   = row['id_log_activo'] as int?;
        final String? antePausa    = row['estado_antes_pausa'] as String?;
        final int? coccionGuardada = row['tiempo_coccion_restante'] as int?;
        final int? tostadoGuardado = row['tiempo_tostado_restante'] as int?;

        final int idx = temporizadores.length;

        if (estadoBD == 'pausado' && antePausa != null &&
            coccionGuardada != null && tostadoGuardado != null) {
          // ── Recuperar estado de pausa exacto ──────────────────────────
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
          // ── Recuperar estado esperando tostado ────────────────────────
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
          // Detenido normal
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

        // Recuperar logId activo si existe
        if (idLogGuardado != null && idLogGuardado > 0) {
          _logIds[idx] = idLogGuardado;
        }
      }
    }

    notifyListeners();
  }

  // ── CRUD: Empleados ───────────────────────────────────────────────────────

  /// Cambia el empleado activo (quien aparece como responsable en los logs)
  void seleccionarEmpleado(Empleado e) {
    empleadoActivo = e;
    // No notifyListeners() — no necesita rebuild del árbol completo
  }

  Future<void> agregarEmpleado(Empleado e) async {
    final id = await DatabaseHelper.instance.insertEmpleado(e);
    empleados.add(Empleado(id: id, nombre: e.nombre, carnet: e.carnet));
    notifyListeners();
  }

  Future<void> updateEmpleado(int index, Empleado actualizado) async {
    await DatabaseHelper.instance.updateEmpleado(actualizado);
    empleados[index] = actualizado;
    notifyListeners();
  }

  Future<void> updateProducto(int index, Producto actualizado) async {
    await DatabaseHelper.instance.updateProducto(actualizado);
    productos[index] = actualizado;

    // Actualizar también los temporizadores en memoria que usan este producto
    // para que sus tiempos reflejen el cambio de inmediato
    for (final t in temporizadores) {
      if (t.producto.id == actualizado.id && !t.corriendo) {
        // Reemplazar la referencia al producto y resetear los tiempos
        t.producto = actualizado;
        t.tiempoCoccionRestante = actualizado.tiempoCoccion * 60;
        t.tiempoTostadoRestante = actualizado.tiempoTostado * 60;
      }
    }

    notifyListeners();
  }

  Future<void> eliminarEmpleado(int index) async {
    final e = empleados[index];
    if (e.id != null) await DatabaseHelper.instance.deleteEmpleado(e.id!);
    empleados.removeAt(index);
    notifyListeners();
  }

  // ── CRUD: Freidoras ───────────────────────────────────────────────────────

  Future<void> agregarFreidora(Freidora f) async {
    final id = await DatabaseHelper.instance.insertFreidora(f);
    freidoras.add(Freidora(
        id: id, codigo: f.codigo, descripcion: f.descripcion, estado: f.estado));
    notifyListeners();
  }

  Future<void> eliminarFreidora(int index) async {
    final f = freidoras[index];
    if (f.id != null) await DatabaseHelper.instance.deleteFreidora(f.id!);
    freidoras.removeAt(index);
    notifyListeners();
  }

  // ── CRUD: Productos ───────────────────────────────────────────────────────

  Future<void> agregarProducto(Producto p) async {
    final id = await DatabaseHelper.instance.insertProducto(p);
    productos.add(Producto(
        id: id,
        nombre: p.nombre,
        tiempoCoccion: p.tiempoCoccion,
        tiempoTostado: p.tiempoTostado));
    notifyListeners();
  }

  Future<void> eliminarProducto(int index) async {
    final p = productos[index];
    if (p.id != null) await DatabaseHelper.instance.deleteProducto(p.id!);
    productos.removeAt(index);
    notifyListeners();
  }

  // ── CRUD: Temporizadores ──────────────────────────────────────────────────

  Future<void> agregarTemporizador(Temporizador t) async {
    // Si la freidora o el producto no tienen id, no podemos insertar en BD
    // (en producción siempre tendrán id al venir de SQLite)
    int dbId = 0;
    if (t.freidora.id != null && t.producto.id != null) {
      dbId = await DatabaseHelper.instance.insertTemporizador(
        idFreidora: t.freidora.id!,
        idProducto: t.producto.id!,
        tiempoSegundos:
            t.tiempoCoccionRestante + t.tiempoTostadoRestante,
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

  // ── Iniciar temporizador (cocción o tostado manual) ──────────────────────
  Future<void> toggleTemporizador(int index) async {
    final t = temporizadores[index];
    if (t.corriendo) return;

    final ahora = DateTime.now();

    if (t.estado == 'esperando_tostado') {
      // ── Iniciar tostado manualmente ──────────────────────────────────────
      // El log YA está abierto desde que inició cocción (_logIds[index] existe)
      // Solo actualizamos inicio_en en BD para el cálculo de tiempo restante
      t.iniciadoEn = ahora;
      t.estado = 'tostado';
      t.corriendo = true;

      if (t.id != null && t.id! > 0) {
        // Usamos el logId existente — NO creamos uno nuevo
        final logId = _logIds[index] ?? 0;
        await DatabaseHelper.instance.iniciarTemporizador(t.id!, ahora, logId);
      }

      _timers[index] =
          Timer.periodic(const Duration(seconds: 1), (_) => _tick(index));
      notifyListeners();
      return;
    }

    // ── Iniciar cocción ────────────────────────────────────────────────────
    // Usa el empleado seleccionado en los chips al momento de iniciar.
    // El tostado lo puede iniciar otro empleado pero el log
    // siempre registra al que inició la cocción.
    t.iniciadoEn = ahora;

    int logId = 0;
    // empleadoActivo es el campo de clase — refleja el chip seleccionado
    final responsable = empleadoActivo ?? 
        (empleados.isNotEmpty ? empleados.first : null);

    if (t.id != null && t.id! > 0 && responsable != null) {
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

    if (t.id != null && t.id! > 0) {
      await DatabaseHelper.instance.iniciarTemporizador(t.id!, ahora, logId);
    }

    t.corriendo = true;
    _timers[index] =
        Timer.periodic(const Duration(seconds: 1), (_) => _tick(index));
    notifyListeners();
  }

  // Mapa auxiliar: índice temporizador → id del log abierto
  final Map<int, int> _logIds = {};

  // ── Tick interno ──────────────────────────────────────────────────────────
  void _tick(int index) {
    if (index >= temporizadores.length) {
      _timers[index]?.cancel();
      _timers.remove(index);
      return;
    }

    final t = temporizadores[index];

    if (t.estado == 'coccion') {
      if (t.tiempoCoccionRestante > 1) {
        t.tiempoCoccionRestante--;
      } else if (t.tiempoCoccionRestante == 1) {
        t.tiempoCoccionRestante = 0;
        _timers[index]?.cancel();
        _timers.remove(index);
        t.corriendo = false;

        if (t.tiempoTostadoRestante > 0) {
          // ── Cocción terminó → esperar play manual para tostado ──────────
          // IMPORTANTE: NO llamar detenerTemporizador aquí porque borraría
          // id_log_activo. El log sigue abierto hasta que termine el tostado.
          t.estado = 'esperando_tostado';
          AudioService.sonarTostado();
          // Guardar estado en BD para recuperarlo al reabrir
          if (t.id != null && t.id! > 0) {
            DatabaseHelper.instance.pausarLogActivo(
              t.id!,
              tiempoCoccionRestante: 0,
              tiempoTostadoRestante: t.tiempoTostadoRestante,
              estadoAntesPausa: 'esperando_tostado',
            );
          }
        } else {
          // Sin tostado → finalizar y cerrar log
          _finalizarTemporizador(t, index);
          AudioService.sonarFin();
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
        _finalizarTemporizador(t, index);
      }
    }

    notifyListeners();
  }

  // ── Finaliza y cierra el log con fecha correcta ───────────────────────────
  void _finalizarTemporizador(Temporizador t, int index) {
    _timers[index]?.cancel();
    _timers.remove(index);

    final logId = _logIds.remove(index);
    final ahora = DateTime.now();

    if (logId != null && logId > 0) {
      // Cerrar log con la fecha/hora exacta de finalización
      DatabaseHelper.instance.cerrarLogConFecha(logId, ahora).then((_) async {
        logs = await DatabaseHelper.instance.getLogs();
        if (!_disposed) notifyListeners();
      });
    }

    // Limpiar temporizador en BD
    if (t.id != null && t.id! > 0) {
      DatabaseHelper.instance.detenerTemporizador(t.id!);
    }

    // Resetear en memoria para reusar
    t.tiempoCoccionRestante = t.producto.tiempoCoccion * 60;
    t.tiempoTostadoRestante = t.producto.tiempoTostado * 60;
    t.estado = 'coccion';
    t.corriendo = false;
    t.iniciadoEn = null;
    // notifyListeners() se llama en _tick() justo después
  }

  // ── Pausar temporizador ───────────────────────────────────────────────────
  void pausarTemporizador(int index) {
    final t = temporizadores[index];
    if (!t.corriendo) return;

    _timers[index]?.cancel();
    _timers.remove(index);

    t.estadoAntesDePausa = t.estado;
    t.estado = 'pausado';
    t.corriendo = false;

    // Guardar en BD: tiempos restantes + estado anterior para recuperar al reabrir
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

  // ── Reanudar temporizador pausado ─────────────────────────────────────────
  Future<void> reanudarTemporizador(int index) async {
    final t = temporizadores[index];
    if (t.estado != 'pausado') return;

    t.estado = t.estadoAntesDePausa ?? 'coccion';
    t.estadoAntesDePausa = null;
    t.corriendo = true;

    final ahora = DateTime.now();

    // Persistir nuevo inicio_en para que sobreviva cierre de app
    if (t.id != null && t.id! > 0) {
      await DatabaseHelper.instance.iniciarTemporizador(
          t.id!, ahora, _logIds[index] ?? 0);
    }

    _timers[index] =
        Timer.periodic(const Duration(seconds: 1), (_) => _tick(index));
    notifyListeners();
  }
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

  // ── Recargar logs desde BD ─────────────────────────────────────────────────
  Future<void> recargarLogs() async {
    logs = await DatabaseHelper.instance.getLogs();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    _logIds.clear();
    super.dispose();
  }
}
