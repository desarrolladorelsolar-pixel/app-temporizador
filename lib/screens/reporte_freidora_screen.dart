import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/freidora.dart';
import '../models/log_entry.dart';
import '../services/database_helper.dart';
import '../services/pdf_service.dart';

/// Reporte detallado de una freidora con historial por boquilla.
/// Carga datos directamente desde DatabaseHelper (no necesita AppState).
class ReporteFreidoraScreen extends StatefulWidget {
  final Freidora freidora;
  const ReporteFreidoraScreen({super.key, required this.freidora});

  @override
  State<ReporteFreidoraScreen> createState() => _ReporteFreidoraScreenState();
}

class _ReporteFreidoraScreenState extends State<ReporteFreidoraScreen> {
  static final DateFormat _fmtCorto  = DateFormat('dd/MM/yyyy', 'es_ES');
  static final DateFormat _fmtFecha  = DateFormat('dd/MM/yyyy HH:mm', 'es_ES');
  static final DateFormat _fmtIso    = DateFormat('yyyy-MM-dd');

  // 'hoy' | 'rango'
  String _filtro = 'hoy';
  DateTime? _rangoDesde;
  DateTime? _rangoHasta;

  List<LogEntry> _logsBq1 = [];
  List<LogEntry> _logsBq2 = [];
  Map<String, dynamic> _stats = {
    'total_coccion': 0, 'total_tostado': 0, 'promedio_seg': 0
  };
  bool _cargando = true;
  bool _generandoPdf = false;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  String? _calcularDesde() {
    if (_filtro == 'hoy') return _fmtIso.format(DateTime.now());
    if (_filtro == 'rango' && _rangoDesde != null) return _fmtIso.format(_rangoDesde!);
    return null;
  }

  String? _calcularHasta() {
    if (_filtro == 'hoy') return _fmtIso.format(DateTime.now());
    if (_filtro == 'rango' && _rangoHasta != null) return _fmtIso.format(_rangoHasta!);
    return null;
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    final db = DatabaseHelper.instance;
    final desde = _calcularDesde();
    final hasta = _calcularHasta();

    final b1 = await db.getLogsPorFreidora(
        nombreFreidora: widget.freidora.codigo, boquilla: 1,
        desde: desde, hasta: hasta);
    final b2 = await db.getLogsPorFreidora(
        nombreFreidora: widget.freidora.codigo, boquilla: 2,
        desde: desde, hasta: hasta);
    final stats = await db.getEstadisticasFreidora(
        nombreFreidora: widget.freidora.codigo,
        desde: desde, hasta: hasta);

    if (mounted) {
      setState(() {
        _logsBq1 = b1; _logsBq2 = b2; _stats = stats; _cargando = false;
      });
    }
  }

  Future<void> _elegirRango() async {
    final ahora = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: ahora,
      initialDateRange: _rangoDesde != null && _rangoHasta != null
          ? DateTimeRange(start: _rangoDesde!, end: _rangoHasta!)
          : DateTimeRange(start: ahora.subtract(const Duration(days: 6)), end: ahora),
      locale: const Locale('es', 'ES'),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFFC62828),
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _rangoDesde = picked.start;
        _rangoHasta = picked.end;
        _filtro = 'rango';
      });
      _cargarDatos();
    }
  }

  String get _etiquetaPeriodo {
    if (_filtro == 'hoy') return 'Hoy, ${_fmtCorto.format(DateTime.now())}';
    if (_rangoDesde != null && _rangoHasta != null) {
      return '${_fmtCorto.format(_rangoDesde!)} → ${_fmtCorto.format(_rangoHasta!)}';
    }
    return 'Período';
  }

  Future<void> _exportarPdf() async {
    if (_logsBq1.isEmpty && _logsBq2.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay registros para exportar.')),
      );
      return;
    }
    setState(() => _generandoPdf = true);
    try {
      await PdfService.generarReporteFreidora(
        nombreFreidora: widget.freidora.codigo,
        logsBoquilla1: _logsBq1,
        logsBoquilla2: _logsBq2,
        estadisticas: _stats,
        etiquetaPeriodo: _etiquetaPeriodo,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al generar PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _generandoPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.freidora.codigo),
          backgroundColor: const Color(0xFFC62828),
          foregroundColor: Colors.white,
          centerTitle: true,
          actions: [
            if (_generandoPdf)
              const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_outlined),
                tooltip: 'Exportar PDF',
                onPressed: _exportarPdf,
              ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // ── Filtros ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    _FiltroChip(
                      label: 'Hoy',
                      activo: _filtro == 'hoy',
                      onTap: () {
                        setState(() { _filtro = 'hoy'; _rangoDesde = null; _rangoHasta = null; });
                        _cargarDatos();
                      },
                    ),
                    const SizedBox(width: 8),
                    _FiltroChip(
                      label: _filtro == 'rango' && _rangoDesde != null
                          ? '${_fmtCorto.format(_rangoDesde!)} → ${_fmtCorto.format(_rangoHasta!)}'
                          : 'Por fechas',
                      activo: _filtro == 'rango',
                      onTap: _elegirRango,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // ── Estadísticas ───────────────────────────────────────────
              if (!_cargando)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _TarjetaEstadisticas(stats: _stats),
                ),

              const SizedBox(height: 8),

              // ── Tabs ───────────────────────────────────────────────────
              const TabBar(
                labelColor: Color(0xFFC62828),
                unselectedLabelColor: Color(0xFF9E9E9E),
                indicatorColor: Color(0xFFC62828),
                labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: [
                  Tab(text: 'B1 — Cocción'),
                  Tab(text: 'B2 — Tostado'),
                ],
              ),

              // ── Contenido ─────────────────────────────────────────────
              Expanded(
                child: _cargando
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFFC62828)))
                    : TabBarView(
                        children: [
                          _ListaLogs(logs: _logsBq1, fmtFecha: _fmtFecha,
                              etiquetaVacia: 'Sin registros de cocción'),
                          _ListaLogs(logs: _logsBq2, fmtFecha: _fmtFecha,
                              etiquetaVacia: 'Sin registros de tostado'),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tarjeta de estadísticas ───────────────────────────────────────────────────
class _TarjetaEstadisticas extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _TarjetaEstadisticas({required this.stats});

  String _fmtSeg(int seg) {
    if (seg <= 0) return '0m';
    final h = seg ~/ 3600;
    final m = (seg % 3600) ~/ 60;
    final s = seg % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0 && s > 0) return '${m}m ${s}s';
    if (m > 0) return '${m}m';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final int segB1    = stats['seg_b1']    as int? ?? 0;
    final int segB2    = stats['seg_b2']    as int? ?? 0;
    final int segTotal = stats['seg_total'] as int? ?? 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFCEAEA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Fila superior: contadores
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _Stat(label: 'Cocción (B1)',
                  valor: '${stats['total_coccion'] ?? 0}'),
              const _Divisor(),
              _Stat(label: 'Tostado (B2)',
                  valor: '${stats['total_tostado'] ?? 0}'),
              const _Divisor(),
              _Stat(label: 'Repasos',
                  valor: '${stats['total_repaso'] ?? 0}'),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFEF9A9A)),
          const SizedBox(height: 10),
          // Fila inferior: tiempo total por boquilla y global
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _Stat(label: 'Tiempo B1', valor: _fmtSeg(segB1),
                  small: true),
              const _Divisor(),
              _Stat(label: 'Tiempo B2', valor: _fmtSeg(segB2),
                  small: true),
              const _Divisor(),
              _Stat(label: 'Total usado', valor: _fmtSeg(segTotal),
                  small: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String valor;
  final bool small;
  const _Stat({required this.label, required this.valor, this.small = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(valor,
            style: TextStyle(
                fontSize: small ? 16 : 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFC62828))),
        Text(label,
            style: const TextStyle(
                fontSize: 10, color: Color(0xFFC62828))),
      ],
    );
  }
}

class _Divisor extends StatelessWidget {
  const _Divisor();
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 36, color: const Color(0xFFEF9A9A));
  }
}

// ── Lista de logs por boquilla ────────────────────────────────────────────────
class _ListaLogs extends StatelessWidget {
  final List<LogEntry> logs;
  final DateFormat fmtFecha;
  final String etiquetaVacia;

  const _ListaLogs({
    required this.logs,
    required this.fmtFecha,
    required this.etiquetaVacia,
  });

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return Center(
        child: Text(etiquetaVacia,
            style: const TextStyle(color: Color(0xFFBDBDBD), fontSize: 14)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: logs.length,
      itemBuilder: (ctx, i) => _LogTile(log: logs[i], fmtFecha: fmtFecha),
    );
  }
}

class _LogTile extends StatelessWidget {
  final LogEntry log;
  final DateFormat fmtFecha;
  const _LogTile({required this.log, required this.fmtFecha});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFFF1F1F1))),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(log.nombreProducto,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF212121))),
                  const SizedBox(height: 3),
                  Text(log.nombreEmpleado,
                      style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 12)),
                  Text(fmtFecha.format(log.fechaHoraInicio),
                      style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 11)),
                ],
              ),
            ),
            Text(
              log.duracionFormateada,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFFC62828)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Chip de filtro ────────────────────────────────────────────────────────────
class _FiltroChip extends StatelessWidget {
  final String label;
  final bool activo;
  final VoidCallback onTap;
  const _FiltroChip({required this.label, required this.activo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: activo ? const Color(0xFFC62828) : const Color(0xFFF1F1F1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: activo ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }
}
