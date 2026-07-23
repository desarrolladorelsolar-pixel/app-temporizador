import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/empleado.dart';
import '../models/freidora.dart';
import '../models/producto.dart';
import '../models/log_entry.dart';

// ── Singleton de base de datos SQLite ────────────────────────────────────────
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._();
  static Database? _db;

  DatabaseHelper._();

  Future<Database> get db async {
    if (_db == null) {
      _db = await _initDb();
      await _aplicarPragmas(_db!);
    }
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'elsolar.db');

    return openDatabase(
      path,
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // Aplica PRAGMAs de rendimiento después de abrir la BD
  Future<void> _aplicarPragmas(Database d) async {
    // WAL mode: lecturas concurrentes sin bloquear escrituras
    await d.rawQuery('PRAGMA journal_mode = WAL');
    // Cache de páginas: 4MB (default ~2MB)
    await d.rawQuery('PRAGMA cache_size = -4000');
  }

  // ── Migración de versiones ────────────────────────────────────────────────
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          'ALTER TABLE temporizador ADD COLUMN inicio_en TEXT');
      await db.execute(
          'ALTER TABLE temporizador ADD COLUMN id_log_activo INTEGER');
    }
    if (oldVersion < 3) {
      await db.execute(
          "ALTER TABLE log ADD COLUMN tipo TEXT NOT NULL DEFAULT 'coccion'");
    }
    if (oldVersion < 4) {
      await db.execute(
          'ALTER TABLE temporizador ADD COLUMN tiempo_coccion_restante INTEGER');
      await db.execute(
          'ALTER TABLE temporizador ADD COLUMN tiempo_tostado_restante INTEGER');
      await db.execute(
          'ALTER TABLE temporizador ADD COLUMN estado_antes_pausa TEXT');
    }
    if (oldVersion < 5) {
      // v5: tiempo de repaso + boquilla en producto, boquilla en log
      await db.execute(
          'ALTER TABLE producto ADD COLUMN tiempo_repaso INTEGER NOT NULL DEFAULT 0');
      await db.execute(
          'ALTER TABLE log ADD COLUMN boquilla INTEGER NOT NULL DEFAULT 1');
      // Índice para reportes por freidora
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_log_freidora ON log(nombre_freidora)');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('PRAGMA foreign_keys = ON;');

    await db.execute('''
      CREATE TABLE producto (
        id_producto        INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre             TEXT NOT NULL,
        tiempo_coccion     INTEGER NOT NULL,
        tiempo_tostado     INTEGER NOT NULL,
        tiempo_repaso      INTEGER NOT NULL DEFAULT 0,
        estado             TEXT NOT NULL DEFAULT 'activo'
          CHECK (estado IN ('activo','inactivo'))
      )
    ''');

    await db.execute('''
      CREATE TABLE freidora (
        id_freidora      INTEGER PRIMARY KEY AUTOINCREMENT,
        codigo_freidora  TEXT NOT NULL UNIQUE,
        descripcion      TEXT,
        estado           TEXT NOT NULL DEFAULT 'activo'
          CHECK (estado IN ('activo','inactivo'))
      )
    ''');

    await db.execute('''
      CREATE TABLE empleado (
        id_empleado  INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre       TEXT NOT NULL,
        ci           TEXT NOT NULL UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE temporizador (
        id_temporizador          INTEGER PRIMARY KEY AUTOINCREMENT,
        id_freidora              INTEGER NOT NULL,
        id_producto              INTEGER NOT NULL,
        estado                   TEXT NOT NULL DEFAULT 'detenido'
          CHECK (estado IN ('detenido','en_curso','pausado','finalizado')),        tiempo                   INTEGER NOT NULL,
        inicio_en                TEXT,
        id_log_activo            INTEGER,
        tiempo_coccion_restante  INTEGER,
        tiempo_tostado_restante  INTEGER,
        estado_antes_pausa       TEXT,
        FOREIGN KEY (id_freidora) REFERENCES freidora(id_freidora) ON DELETE RESTRICT,
        FOREIGN KEY (id_producto) REFERENCES producto(id_producto) ON DELETE RESTRICT
      )
    ''');

    await db.execute('''
      CREATE TABLE log (
        id_log             INTEGER PRIMARY KEY AUTOINCREMENT,
        id_temporizador    INTEGER NOT NULL,
        id_empleado        INTEGER NOT NULL,
        nombre_empleado    TEXT NOT NULL,
        nombre_freidora    TEXT NOT NULL,
        nombre_producto    TEXT NOT NULL,
        fecha_hora_inicio  TEXT NOT NULL,
        fecha_hora_fin     TEXT,
        tipo               TEXT NOT NULL DEFAULT 'coccion',
        boquilla           INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (id_temporizador) REFERENCES temporizador(id_temporizador) ON DELETE RESTRICT,
        FOREIGN KEY (id_empleado)     REFERENCES empleado(id_empleado) ON DELETE RESTRICT
      )
    ''');

    // Índices
    await db.execute(
        'CREATE INDEX idx_temporizador_freidora ON temporizador(id_freidora)');
    await db.execute(
        'CREATE INDEX idx_temporizador_producto ON temporizador(id_producto)');
    await db.execute(
        'CREATE INDEX idx_log_temporizador ON log(id_temporizador)');
    await db.execute(
        'CREATE INDEX idx_log_empleado ON log(id_empleado)');
    await db.execute(
        'CREATE INDEX idx_log_fecha_inicio ON log(fecha_hora_inicio)');
    await db.execute(
        'CREATE INDEX idx_log_freidora ON log(nombre_freidora)');
  }

  // ── EMPLEADOS ──────────────────────────────────────────────────────────────

  Future<int> insertEmpleado(Empleado e) async {
    final d = await db;
    return d.insert('empleado', e.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Empleado>> getEmpleados() async {
    final d = await db;
    // Columnas explícitas — evita traer datos innecesarios
    final rows = await d.query('empleado',
        columns: ['id_empleado', 'nombre', 'ci'],
        orderBy: 'nombre ASC');
    return rows.map(Empleado.fromMap).toList();
  }

  Future<int> deleteEmpleado(int id) async {
    final d = await db;
    return d.delete('empleado', where: 'id_empleado = ?', whereArgs: [id]);
  }

  Future<void> updateEmpleado(Empleado e) async {
    final d = await db;
    await d.update('empleado', e.toMap(),
        where: 'id_empleado = ?', whereArgs: [e.id]);
  }

  // ── FREIDORAS ──────────────────────────────────────────────────────────────

  Future<int> insertFreidora(Freidora f) async {
    final d = await db;
    return d.insert('freidora', f.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Freidora>> getFreidoras() async {
    final d = await db;
    final rows = await d.query('freidora',
        columns: ['id_freidora', 'codigo_freidora', 'descripcion', 'estado'],
        where: "estado = 'activo'",
        orderBy: 'codigo_freidora ASC');
    return rows.map(Freidora.fromMap).toList();
  }

  Future<int> deleteFreidora(int id) async {
    final d = await db;
    // Soft delete para no romper FK con logs históricos
    return d.update(
      'freidora',
      {'estado': 'inactivo'},
      where: 'id_freidora = ?',
      whereArgs: [id],
    );
  }

  // ── PRODUCTOS ──────────────────────────────────────────────────────────────

  Future<int> insertProducto(Producto p) async {
    final d = await db;
    return d.insert('producto', p.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Producto>> getProductos() async {
    final d = await db;
    final rows = await d.query('producto',
        columns: ['id_producto', 'nombre', 'tiempo_coccion', 'tiempo_tostado', 'tiempo_repaso'],
        where: "estado = 'activo'",
        orderBy: 'nombre ASC');
    return rows.map(Producto.fromMap).toList();
  }

  Future<int> deleteProducto(int id) async {
    final d = await db;
    return d.update(
      'producto',
      {'estado': 'inactivo'},
      where: 'id_producto = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateProducto(Producto p) async {
    final d = await db;
    await d.update(
      'producto',
      {
        'nombre': p.nombre,
        'tiempo_coccion': p.tiempoCoccion * 60,
        'tiempo_tostado': p.tiempoTostado * 60,
        'tiempo_repaso': p.tiempoRepaso * 60,
      },
      where: 'id_producto = ?',
      whereArgs: [p.id],
    );
  }

  // ── TEMPORIZADORES ─────────────────────────────────────────────────────────

  /// Inserta un temporizador y devuelve su id generado
  Future<int> insertTemporizador({
    required int idFreidora,
    required int idProducto,
    required int tiempoSegundos,
  }) async {
    final d = await db;
    return d.insert('temporizador', {
      'id_freidora': idFreidora,
      'id_producto': idProducto,
      'estado': 'detenido',
      'tiempo': tiempoSegundos,
    });
  }

  /// Devuelve todos los temporizadores activos (no finalizados)
  Future<List<Map<String, dynamic>>> getTemporizadores() async {
    final d = await db;
    return d.query(
      'temporizador',
      columns: [
        'id_temporizador', 'id_freidora', 'id_producto',
        'estado', 'tiempo', 'inicio_en', 'id_log_activo',
        'tiempo_coccion_restante', 'tiempo_tostado_restante', 'estado_antes_pausa'
      ],
      where: "estado != 'finalizado'",
      orderBy: 'id_temporizador ASC',
    );
  }

  /// Elimina un temporizador por su id
  Future<void> deleteTemporizador(int id) async {
    final d = await db;
    await d.delete('temporizador',
        where: 'id_temporizador = ?', whereArgs: [id]);
  }

  Future<void> updateEstadoTemporizador(int id, String estado) async {
    final d = await db;
    await d.update(
      'temporizador',
      {'estado': estado},
      where: 'id_temporizador = ?',
      whereArgs: [id],
    );
  }

  /// Guarda el momento de inicio y el id del log activo en la fila
  Future<void> iniciarTemporizador(
      int id, DateTime inicioEn, int idLogActivo) async {
    final d = await db;
    await d.update(
      'temporizador',
      {
        'estado': 'en_curso',
        'inicio_en': inicioEn.toIso8601String(),
        'id_log_activo': idLogActivo,
      },
      where: 'id_temporizador = ?',
      whereArgs: [id],
    );
  }

  /// Resetea el temporizador a detenido (al completar o al recargar ya vencido)
  Future<void> detenerTemporizador(int id) async {
    final d = await db;
    await d.update(
      'temporizador',
      {'estado': 'detenido', 'inicio_en': null, 'id_log_activo': null},
      where: 'id_temporizador = ?',
      whereArgs: [id],
    );
  }

  /// Pausa: limpia inicio_en pero conserva id_log_activo y guarda
  /// el tiempo restante y el estado para recuperarlos al reabrir
  Future<void> pausarLogActivo(int id,
      {required int tiempoCoccionRestante,
      required int tiempoTostadoRestante,
      required String estadoAntesPausa}) async {
    final d = await db;
    await d.update(
      'temporizador',
      {
        'estado': 'pausado',
        'inicio_en': null,
        'tiempo_coccion_restante': tiempoCoccionRestante,
        'tiempo_tostado_restante': tiempoTostadoRestante,
        'estado_antes_pausa': estadoAntesPausa,
      },
      where: 'id_temporizador = ?',
      whereArgs: [id],
    );
  }

  // ── LOGS ───────────────────────────────────────────────────────────────────

  Future<int> insertLog(LogEntry log) async {
    final d = await db;
    return d.insert('log', log.toMap());
  }

  /// Cierra el log: registra la fecha/hora de fin
  Future<void> cerrarLog(int idLog) async {
    final d = await db;
    await d.update(
      'log',
      {'fecha_hora_fin': DateTime.now().toIso8601String()},
      where: 'id_log = ?',
      whereArgs: [idLog],
    );
  }

  /// Cierra el log con una fecha/hora de fin explícita
  /// (usado cuando el temporizador terminó con la app cerrada)
  Future<void> cerrarLogConFecha(int idLog, DateTime finEn) async {
    final d = await db;
    await d.update(
      'log',
      {'fecha_hora_fin': finEn.toIso8601String()},
      where: 'id_log = ?',
      whereArgs: [idLog],
    );
  }

  /// Devuelve solo logs de cocción con columnas explícitas
  Future<List<LogEntry>> getLogs() async {
    final d = await db;
    final rows = await d.query(
      'log',
      columns: [
        'id_log', 'id_temporizador', 'id_empleado',
        'nombre_empleado', 'nombre_freidora', 'nombre_producto',
        'fecha_hora_inicio', 'fecha_hora_fin', 'tipo'
      ],
      where: "tipo = 'coccion'",      orderBy: 'fecha_hora_inicio DESC',
      // Límite de seguridad — evita cargar miles de logs en RAM
      limit: 500,
    );
    return rows.map(LogEntry.fromMap).toList();
  }

  /// Logs de un rango de fechas (fechas en formato ISO8601 YYYY-MM-DD)
  Future<List<LogEntry>> getLogsPorFecha(String desde, String hasta) async {
    final d = await db;
    final rows = await d.query(
      'log',
      where: "fecha_hora_inicio >= ? AND fecha_hora_inicio <= ?",
      whereArgs: ['${desde}T00:00:00', '${hasta}T23:59:59'],
      orderBy: 'fecha_hora_inicio DESC',
    );
    return rows.map(LogEntry.fromMap).toList();
  }

  // ── REPORTES ───────────────────────────────────────────────────────────────

  /// Logs de una freidora filtrados por boquilla y/o rango de fechas.
  /// Incluye cocción, tostado Y repaso (tipos 'coccion' y 'repaso').
  /// [boquilla] null = ambas, 1 = cocción/repaso B1, 2 = tostado/repaso B2.
  Future<List<LogEntry>> getLogsPorFreidora({
    required String nombreFreidora,
    int? boquilla,
    String? desde,
    String? hasta,
  }) async {
    final d = await db;

    final List<String> condiciones = [
      "(tipo = 'coccion' OR tipo = 'repaso')",  // incluye repaso
      "nombre_freidora = ?",
    ];
    final List<dynamic> args = [nombreFreidora];

    if (boquilla != null) {
      condiciones.add('boquilla = ?');
      args.add(boquilla);
    }
    if (desde != null) {
      condiciones.add("fecha_hora_inicio >= ?");
      args.add('${desde}T00:00:00');
    }
    if (hasta != null) {
      condiciones.add("fecha_hora_inicio <= ?");
      args.add('${hasta}T23:59:59');
    }

    final rows = await d.query(
      'log',
      where: condiciones.join(' AND '),
      whereArgs: args,
      orderBy: 'fecha_hora_inicio DESC',
      limit: 500,
    );
    return rows.map(LogEntry.fromMap).toList();
  }

  /// Estadísticas para el reporte de freidora.
  /// Devuelve: totalCoccion, totalTostado, totalRepaso,
  ///           totalSegB1 (cocción+repaso B1), totalSegB2 (tostado+repaso B2),
  ///           totalSegGeneral (suma total de todos los tiempos).
  Future<Map<String, dynamic>> getEstadisticasFreidora({
    required String nombreFreidora,
    String? desde,
    String? hasta,
  }) async {
    final d = await db;

    String where =
        "(tipo = 'coccion' OR tipo = 'repaso') "
        "AND nombre_freidora = ? "
        "AND fecha_hora_fin IS NOT NULL";
    final List<dynamic> args = [nombreFreidora];

    if (desde != null) where += " AND fecha_hora_inicio >= '${desde}T00:00:00'";
    if (hasta != null) where += " AND fecha_hora_inicio <= '${hasta}T23:59:59'";

    final rows = await d.rawQuery('''
      SELECT
        SUM(CASE WHEN tipo = 'coccion' AND boquilla = 1 THEN 1 ELSE 0 END)
            AS total_coccion,
        SUM(CASE WHEN tipo = 'coccion' AND boquilla = 2 THEN 1 ELSE 0 END)
            AS total_tostado,
        SUM(CASE WHEN tipo = 'repaso' THEN 1 ELSE 0 END)
            AS total_repaso,
        CAST(SUM(CASE WHEN boquilla = 1
          THEN (julianday(fecha_hora_fin) - julianday(fecha_hora_inicio)) * 86400
          ELSE 0 END) AS INTEGER) AS seg_b1,
        CAST(SUM(CASE WHEN boquilla = 2
          THEN (julianday(fecha_hora_fin) - julianday(fecha_hora_inicio)) * 86400
          ELSE 0 END) AS INTEGER) AS seg_b2,
        CAST(SUM(
          (julianday(fecha_hora_fin) - julianday(fecha_hora_inicio)) * 86400
        ) AS INTEGER) AS seg_total
      FROM log
      WHERE $where
    ''', args);

    if (rows.isEmpty) {
      return {
        'total_coccion': 0, 'total_tostado': 0, 'total_repaso': 0,
        'seg_b1': 0, 'seg_b2': 0, 'seg_total': 0,
      };
    }
    final r = rows.first;
    return {
      'total_coccion': r['total_coccion'] as int? ?? 0,
      'total_tostado': r['total_tostado'] as int? ?? 0,
      'total_repaso':  r['total_repaso']  as int? ?? 0,
      'seg_b1':        r['seg_b1']        as int? ?? 0,
      'seg_b2':        r['seg_b2']        as int? ?? 0,
      'seg_total':     r['seg_total']     as int? ?? 0,
    };
  }
}
