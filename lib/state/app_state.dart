import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/empleado.dart';
import '../models/freidora.dart';
import '../models/log_entry.dart';
import '../models/producto.dart';
import '../models/temporizador.dart';
import '../services/audio_service.dart';
import '../services/database_helper.dart';

class AppState extends ChangeNotifier {

  // ── Listas en memoria ──────────────────────────────────────────────────────
  final List<Empleado> empleados = [];
  final List<Freidora> freidoras = [];
  final List<Producto> productos = [];
  final List<Temporizador> temporizadores = [];
  List<LogEntry> logs = [];

  /// Empleado activo — se registra en los logs de cocción.
  Empleado? empleadoActivo;

  // Timers del ciclo principal (cocción/tostado)
  final Map<int, Timer> _timers = {};
  // ID del log abierto por boquilla: _logIds[index] = logId boquilla activa
  final Map<int, int> _logIds = {};

  // ── Repaso — countdown paralelo e independiente ────────────────────────────
  // Timers del repaso por índice de temporizador
  final Map<int, Timer> _repasoTimers = {};
  // Segundos restantes del repaso por índice (0 = sin repaso activo)
  final Map<int, int> _repasoRestante = {};

  bool _disposed = false;

  // ── INICIALIZACIÓN ─────────────────────────────────────────────────────────

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
      final int? idLogActivo   = row['id_log_activo'] as int?;
      final int  dbId          = row['id_temporizador'] as int;

      if (inicioEnStr != null) {
        final DateTime inicioEn     = DateTime.parse(inicioEnStr);
        final int      transcurrido = ahora.difference(inicioEn).inSeconds;
        final int      totalCiclo   = totalCoccion + totalTostado;

        if (transcurrido >= totalCiclo) {
          if (idLogActivo != null) {
            final DateTime finReal = inicioEn.add(Duration(seconds: totalCiclo));
            await db.cerrarLogConFecha(idLogActivo, finReal);
          }
          await db.detenerTemporizador(dbId);
          temporizadores.add(Temporizador(
            id: dbId, freidora: freidora, producto: producto,
            tiempoCoccionRestante: totalCoccion,
            tiempoTostadoRestante: totalTostado,
            estado: 'coccion', corriendo: false,
          ));
        } else {
          int restanteCoccion; int restanteTostado; String fase;
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
            id: dbId, freidora: freidora, producto: producto,
            tiempoCoccionRestante: restanteCoccion,
            tiempoTostadoRestante: restanteTostado,
            estado: fase, corriendo: true, iniciadoEn: inicioEn,
          );
          temporizadores.add(t);
          final idx = temporizadores.length - 1;
          if (idLogActivo != null) _logIds[idx] = idLogActivo;
          _timers[idx] = Timer.periodic(const Duration(seconds: 1), (_) => _tick(idx));
        }
      } else {
        final String estadoBD      = row['estado'] as String? ?? 'detenido';
        final int? idLogGuardado   = row['id_log_activo'] as int?;
        final String? antePausa    = row['estado_antes_pausa'] as String?;
        final int? coccionGuardada = row['tiempo_coccion_restante'] as int?;
        final int? tostadoGuardado = row['tiempo_tostado_restante'] as int?;
        final int idx = temporizadores.length;

        if (estadoBD == 'pausado' && antePausa != null &&
            coccionGuardada != null && tostadoGuardado != null) {
          temporizadores.add(Temporizador(
            id: dbId, freidora: freidora, producto: producto,
            tiempoCoccionRestante: coccionGuardada,
            tiempoTostadoRestante: tostadoGuardado,
            estado: 'pausado', estadoAntesDePausa: antePausa, corriendo: false,
          ));
        } else if (estadoBD == 'pausado' &&
            antePausa == 'esperando_tostado' && tostadoGuardado != null) {
          temporizadores.add(Temporizador(
            id: dbId, freidora: freidora, producto: producto,
            tiempoCoccionRestante: 0,
            tiempoTostadoRestante: tostadoGuardado,
            estado: 'esperando_tostado', corriendo: false,
          ));
        } else {
          temporizadores.add(Temporizador(
            id: dbId, freidora: freidora, producto: producto,
            tiempoCoccionRestante: totalCoccion,
            tiempoTostadoRestante: totalTostado,
            estado: 'coccion', corriendo: false,
          ));
        }
        if (idLogGuardado != null && idLogGuardado > 0) {
          _logIds[idx] = idLogGuardado;
        }
      }
    }

    notifyListeners();
  }

  // ── SELECCIÓN DE EMPLEADO ──────────────────────────────────────────────────

  void seleccionarEmpleado(Empleado e) {
    empleadoActivo = e;
  }

  // ── CRUD: EMPLEADOS ────────────────────────────────────────────────────────

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

  Future<void> eliminarEmpleado(int index) async {
    final e = empleados[index];
    if (e.id != null) await DatabaseHelper.instance.deleteEmpleado(e.id!);
    empleados.removeAt(index);
    notifyListeners();
  }

  // ── CRUD: FREIDORAS ────────────────────────────────────────────────────────

  Future<void> agregarFreidora(Freidora f) async {
    final id = await DatabaseHelper.instance.insertFreidora(f);
    freidoras.add(Freidora(id: id, codigo: f.codigo, descripcion: f.descripcion, estado: f.estado));
    notifyListeners();
  }

  Future<void> eliminarFreidora(int index) async {
    final f = freidoras[index];
    if (f.id != null) await DatabaseHelper.instance.deleteFreidora(f.id!);
    freidoras.removeAt(index);
    notifyListeners();
  }

  // ── CRUD: PRODUCTOS ────────────────────────────────────────────────────────

  Future<void> agregarProducto(Producto p) async {
    final id = await DatabaseHelper.instance.insertProducto(p);
    productos.add(Producto(
      id: id, nombre: p.nombre,
      tiempoCoccion: p.tiempoCoccion, tiempoTostado: p.tiempoTostado,
      tiempoRepaso: p.tiempoRepaso, boquillaRepaso: p.boquillaRepaso,
    ));
    notifyListeners();
  }

  Future<void> updateProducto(int index, Producto actualizado) async {
    await DatabaseHelper.instance.updateProducto(actualizado);
    productos[index] = actualizado;
    for (final t in temporizadores) {
      if (t.producto.id == actualizado.id && !t.corriendo) {
        t.producto = actualizado;
        t.tiempoCoccionRestante = actualizado.tiempoCoccion * 60;
        t.tiempoTostadoRestante = actualizado.tiempoTostado * 60;
      }
    }
    notifyListeners();
  }

  Future<void> eliminarProducto(int index) async {
    final p = productos[index];
    if (p.id != null) await DatabaseHelper.instance.deleteProducto(p.id!);
    productos.removeAt(index);
    notifyListeners();
  }

  // ── CRUD: TEMPORIZADORES ───────────────────────────────────────────────────

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
      id: dbId, freidora: t.freidora, producto: t.producto,
      tiempoCoccionRestante: t.tiempoCoccionRestante,
      tiempoTostadoRestante: t.tiempoTostadoRestante,
      estado: t.estado, corriendo: t.corriendo,
    ));
    notifyListeners();
  }

  // ── CICLO DE TEMPORIZADOR ──────────────────────────────────────────────────

  Future<void> toggleTemporizador(int index) async {
    final t = temporizadores[index];
    if (t.corriendo) return;

    final ahora = DateTime.now();

    if (t.estado == 'esperando_tostado') {
      // ── Iniciar tostado (boquilla 2) ────────────────────────────────────
      t.iniciadoEn = ahora;
      t.estado = 'tostado';
      t.corriendo = true;

      // Abrir nuevo log para boquilla 2
      final responsable = empleadoActivo ?? (empleados.isNotEmpty ? empleados.first : null);
      int logId = 0;
      if (t.id != null && t.id! > 0 && responsable != null) {
        logId = await DatabaseHelper.instance.insertLog(LogEntry(
          idTemporizador: t.id!,
          idEmpleado: responsable.id ?? 0,
          nombreEmpleado: responsable.nombre,
          nombreFreidora: t.freidora.codigo,
          nombreProducto: t.producto.nombre,
          fechaHoraInicio: ahora,
          boquilla: 2, // ← tostado = boquilla 2
        ));
        _logIds[index] = logId;
      }

      if (t.id != null && t.id! > 0) {
        await DatabaseHelper.instance.iniciarTemporizador(t.id!, ahora, logId);
      }

      _timers[index] = Timer.periodic(const Duration(seconds: 1), (_) => _tick(index));
      notifyListeners();
      return;
    }

    // ── Iniciar cocción (boquilla 1) ────────────────────────────────────────
    t.iniciadoEn = ahora;
    final responsable = empleadoActivo ?? (empleados.isNotEmpty ? empleados.first : null);

    int logId = 0;
    if (t.id != null && t.id! > 0 && responsable != null) {
      logId = await DatabaseHelper.instance.insertLog(LogEntry(
        idTemporizador: t.id!,
        idEmpleado: responsable.id ?? 0,
        nombreEmpleado: responsable.nombre,
        nombreFreidora: t.freidora.codigo,
        nombreProducto: t.producto.nombre,
        fechaHoraInicio: ahora,
        boquilla: 1, // ← cocción = boquilla 1
      ));
      _logIds[index] = logId;
    }

    if (t.id != null && t.id! > 0) {
      await DatabaseHelper.instance.iniciarTemporizador(t.id!, ahora, logId);
    }

    t.corriendo = true;
    _timers[index] = Timer.periodic(const Duration(seconds: 1), (_) => _tick(index));
    notifyListeners();
  }

  void _tick(int index) {
    if (index >= temporizadores.length) {
      _timers[index]?.cancel(); _timers.remove(index); return;
    }
    final t = temporizadores[index];

    if (t.estado == 'coccion') {
      if (t.tiempoCoccionRestante > 1) {
        t.tiempoCoccionRestante--;
      } else if (t.tiempoCoccionRestante == 1) {
        t.tiempoCoccionRestante = 0;
        _timers[index]?.cancel(); _timers.remove(index);
        t.corriendo = false;

        // Cerrar log de cocción (boquilla 1)
        final logId = _logIds.remove(index);
        if (logId != null && logId > 0) {
          DatabaseHelper.instance.cerrarLogConFecha(logId, DateTime.now());
        }

        if (t.tiempoTostadoRestante > 0) {
          t.estado = 'esperando_tostado';
          AudioService.sonarTostado();
          if (t.id != null && t.id! > 0) {
            DatabaseHelper.instance.pausarLogActivo(
              t.id!,
              tiempoCoccionRestante: 0,
              tiempoTostadoRestante: t.tiempoTostadoRestante,
              estadoAntesPausa: 'esperando_tostado',
            );
          }
        } else {
          _resetTemporizador(t, index);
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

  // Finaliza el tostado y cierra su log (boquilla 2)
  void _finalizarTemporizador(Temporizador t, int index) {
    _timers[index]?.cancel(); _timers.remove(index);

    final logId = _logIds.remove(index);
    final ahora = DateTime.now();
    if (logId != null && logId > 0) {
      DatabaseHelper.instance.cerrarLogConFecha(logId, ahora).then((_) async {
        logs = await DatabaseHelper.instance.getLogs();
        if (!_disposed) notifyListeners();
      });
    }

    if (t.id != null && t.id! > 0) {
      DatabaseHelper.instance.detenerTemporizador(t.id!);
    }
    _resetTemporizador(t, index);
  }

  // Resetea sin cerrar log (para ciclos sin tostado)
  void _resetTemporizador(Temporizador t, int index) {
    if (t.id != null && t.id! > 0) {
      DatabaseHelper.instance.detenerTemporizador(t.id!);
    }
    t.tiempoCoccionRestante = t.producto.tiempoCoccion * 60;
    t.tiempoTostadoRestante = t.producto.tiempoTostado * 60;
    t.estado = 'coccion';
    t.corriendo = false;
    t.iniciadoEn = null;
  }

  void pausarTemporizador(int index) {
    final t = temporizadores[index];
    if (!t.corriendo) return;
    _timers[index]?.cancel(); _timers.remove(index);
    t.estadoAntesDePausa = t.estado;
    t.estado = 'pausado';
    t.corriendo = false;
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

  Future<void> reanudarTemporizador(int index) async {
    final t = temporizadores[index];
    if (t.estado != 'pausado') return;
    t.estado = t.estadoAntesDePausa ?? 'coccion';
    t.estadoAntesDePausa = null;
    t.corriendo = true;
    final ahora = DateTime.now();
    if (t.id != null && t.id! > 0) {
      await DatabaseHelper.instance.iniciarTemporizador(t.id!, ahora, _logIds[index] ?? 0);
    }
    _timers[index] = Timer.periodic(const Duration(seconds: 1), (_) => _tick(index));
    notifyListeners();
  }

  Future<void> eliminarTemporizador(int index) async {
    final t = temporizadores[index];
    _timers[index]?.cancel(); _timers.remove(index);
    _logIds.remove(index);
    _cancelarRepaso(index);
    if (t.id != null && t.id! > 0) {
      await DatabaseHelper.instance.deleteTemporizador(t.id!);
    }
    temporizadores.removeAt(index);
    notifyListeners();
  }

  // ── REPASO ─────────────────────────────────────────────────────────────────

  /// true si hay un repaso activo para [index]
  bool tieneRepasoActivo(int index) => (_repasoRestante[index] ?? 0) > 0;

  /// Segundos restantes del repaso (0 si no hay repaso)
  int segundosRepaso(int index) => _repasoRestante[index] ?? 0;

  /// Inicia el countdown de repaso. Si ya hay uno activo, lo reinicia.
  void iniciarRepaso(int index) {
    if (index >= temporizadores.length) return;
    final t = temporizadores[index];
    if (t.producto.tiempoRepaso <= 0) return;

    // Cancela el anterior si existía
    _cancelarRepaso(index);

    _repasoRestante[index] = t.producto.tiempoRepaso * 60;
    _repasoTimers[index] = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _tickRepaso(index),
    );
    notifyListeners();
  }

  void _tickRepaso(int index) {
    final seg = (_repasoRestante[index] ?? 0) - 1;
    if (seg <= 0) {
      _repasoRestante[index] = 0;
      _repasoTimers[index]?.cancel();
      _repasoTimers.remove(index);
      AudioService.sonarFin(); // beep al terminar el repaso
    } else {
      _repasoRestante[index] = seg;
    }
    notifyListeners();
  }

  void _cancelarRepaso(int index) {
    _repasoTimers[index]?.cancel();
    _repasoTimers.remove(index);
    _repasoRestante.remove(index);
  }

  // ── LOGS ───────────────────────────────────────────────────────────────────

  Future<void> recargarLogs() async {
    logs = await DatabaseHelper.instance.getLogs();
    notifyListeners();
  }

  // ── DISPOSE ────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _disposed = true;
    for (final t in _timers.values) t.cancel();
    for (final t in _repasoTimers.values) t.cancel();
    _timers.clear();
    _logIds.clear();
    _repasoTimers.clear();
    _repasoRestante.clear();
    super.dispose();
  }
}
