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

  // Timers del ciclo principal (cocción/tostado/repaso)
  final Map<int, Timer> _timers = {};
  // ID del log abierto por fase activa
  final Map<int, int> _logIds = {};

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

  /// Actualiza el badge visual de todas las freidoras según temporizadores activos.
  /// 'en_uso' si hay algún temporizador corriendo con esa freidora, si no 'activo'.
  void _actualizarEstadoFreidoras() {
    final enUsoIds = temporizadores
        .where((t) => t.corriendo)
        .map((t) => t.freidora.id)
        .toSet();
    for (final f in freidoras) {
      f.estado = enUsoIds.contains(f.id) ? 'en_uso' : 'activo';
    }
  }

  @override
  void notifyListeners() {
    // Sincroniza el estado visual de freidoras en cada notificación
    _actualizarEstadoFreidoras();
    super.notifyListeners();
  }

  // ── CRUD: PRODUCTOS ────────────────────────────────────────────────────────

  Future<void> agregarProducto(Producto p) async {
    final id = await DatabaseHelper.instance.insertProducto(p);
    productos.add(Producto(
      id: id, nombre: p.nombre,
      tiempoCoccion: p.tiempoCoccion, tiempoTostado: p.tiempoTostado,
      tiempoRepaso: p.tiempoRepaso,
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
    _actualizarEstadoFreidoras();
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
    _actualizarEstadoFreidoras();
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
    _actualizarEstadoFreidoras();
    notifyListeners();
  }

  Future<void> eliminarTemporizador(int index) async {
    final t = temporizadores[index];
    _timers[index]?.cancel(); _timers.remove(index);
    _logIds.remove(index);
    if (t.id != null && t.id! > 0) {
      await DatabaseHelper.instance.deleteTemporizador(t.id!);
    }
    temporizadores.removeAt(index);
    _actualizarEstadoFreidoras();
    notifyListeners();
  }

  // ── REPASO ─────────────────────────────────────────────────────────────────

  /// Pone el temporizador en modo 'listo_repaso' con la boquilla elegida.
  /// El doble tap en el botón verde iniciará el countdown.
  void prepararRepaso(int index, int boquilla) {
    if (index >= temporizadores.length) return;
    final t = temporizadores[index];
    if (t.producto.tiempoRepaso <= 0) return;
    if (t.corriendo) return; // no interrumpir ciclo activo

    t.estadoAntesDePausa = t.estado; // guarda el estado previo
    t.estado = 'listo_repaso';
    t.boquillaRepaso = boquilla;
    t.tiempoRepasoRestante = t.producto.tiempoRepaso * 60;
    _actualizarEstadoFreidoras();
    notifyListeners();
  }

  /// Cancela el modo 'listo_repaso' y vuelve al estado anterior.
  void cancelarRepaso(int index) {
    if (index >= temporizadores.length) return;
    final t = temporizadores[index];
    if (t.estado != 'listo_repaso') return;
    t.estado = t.estadoAntesDePausa ?? 'coccion';
    t.estadoAntesDePausa = null;
    t.tiempoRepasoRestante = 0;
    _actualizarEstadoFreidoras();
    notifyListeners();
  }

  /// Inicia el countdown de repaso (llamado con doble tap en botón verde).
  Future<void> iniciarRepaso(int index) async {
    if (index >= temporizadores.length) return;
    final t = temporizadores[index];
    if (t.estado != 'listo_repaso') return;
    if (t.tiempoRepasoRestante <= 0) return;

    t.estado = 'repaso';
    t.corriendo = true;

    // Guardar log del repaso con la boquilla seleccionada
    final responsable = empleadoActivo ?? (empleados.isNotEmpty ? empleados.first : null);
    if (t.id != null && t.id! > 0 && responsable != null) {
      final ahora = DateTime.now();
      final logId = await DatabaseHelper.instance.insertLog(LogEntry(
        idTemporizador: t.id!,
        idEmpleado: responsable.id ?? 0,
        nombreEmpleado: responsable.nombre,
        nombreFreidora: t.freidora.codigo,
        nombreProducto: t.producto.nombre,
        fechaHoraInicio: ahora,
        tipo: 'repaso',
        boquilla: t.boquillaRepaso,
      ));
      _logIds[index] = logId; // reutiliza el mapa para cerrar el log al terminar
    }

    _timers[index] = Timer.periodic(
        const Duration(seconds: 1), (_) => _tickRepaso(index));
    _actualizarEstadoFreidoras();
    notifyListeners();
  }

  void _tickRepaso(int index) {
    if (index >= temporizadores.length) {
      _timers[index]?.cancel(); _timers.remove(index); return;
    }
    final t = temporizadores[index];
    if (t.tiempoRepasoRestante > 1) {
      t.tiempoRepasoRestante--;
    } else if (t.tiempoRepasoRestante == 1) {
      t.tiempoRepasoRestante = 0;
      _timers[index]?.cancel(); _timers.remove(index);

      // Cerrar log del repaso
      final logId = _logIds.remove(index);
      if (logId != null && logId > 0) {
        DatabaseHelper.instance.cerrarLogConFecha(logId, DateTime.now());
      }

      // Volver al estado anterior al repaso
      t.estado = t.estadoAntesDePausa ?? 'coccion';
      t.estadoAntesDePausa = null;
      t.corriendo = false;
      t.tiempoRepasoRestante = 0;
      AudioService.sonarFin();
      _actualizarEstadoFreidoras();
    }
    notifyListeners();
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
    _timers.clear();
    _logIds.clear();
    super.dispose();
  }
}
