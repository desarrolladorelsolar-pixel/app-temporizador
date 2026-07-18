import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/log_entry.dart';
import '../services/pdf_service.dart';
import '../state/app_state.dart';
import '../widgets/app_bar_principal.dart';
import '../widgets/app_drawer.dart';

// ── Pantalla de Historial ────────────────────────────────────────────────────
// No muestra registros en pantalla — solo permite descargar el PDF
// filtrado por fecha. Los logs se guardan en BD y se exportan desde aquí.
class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

enum _FiltroTipo { hoy, rango }

class _LogsScreenState extends State<LogsScreen> {
  static final DateFormat _fmtCorto = DateFormat('dd/MM/yyyy', 'es_ES');

  _FiltroTipo _filtro    = _FiltroTipo.hoy;
  DateTime?   _rangoDesde;
  DateTime?   _rangoHasta;
  bool        _generandoPdf = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().recargarLogs();
    });
  }

  // ── Filtra por fecha ──────────────────────────────────────────────────────
  List<LogEntry> _aplicarFiltro(List<LogEntry> todos) {
    final hoy = DateTime.now();
    switch (_filtro) {
      case _FiltroTipo.hoy:
        return todos.where((l) {
          final f = l.fechaHoraInicio;
          return f.year == hoy.year &&
                 f.month == hoy.month &&
                 f.day == hoy.day;
        }).toList();
      case _FiltroTipo.rango:
        if (_rangoDesde == null || _rangoHasta == null) return todos;
        final desde = DateTime(
            _rangoDesde!.year, _rangoDesde!.month, _rangoDesde!.day);
        final hasta = DateTime(
            _rangoHasta!.year, _rangoHasta!.month, _rangoHasta!.day, 23, 59, 59);
        return todos.where((l) =>
            !l.fechaHoraInicio.isBefore(desde) &&
            !l.fechaHoraInicio.isAfter(hasta)).toList();
    }
  }

  // ── Selector de rango ─────────────────────────────────────────────────────
  Future<void> _elegirRango() async {
    final ahora = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: ahora,
      initialDateRange: _rangoDesde != null && _rangoHasta != null
          ? DateTimeRange(start: _rangoDesde!, end: _rangoHasta!)
          : DateTimeRange(
              start: ahora.subtract(const Duration(days: 6)), end: ahora),
      locale: const Locale('es', 'ES'),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
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
        _filtro = _FiltroTipo.rango;
      });
    }
  }

  String get _etiquetaFiltro {
    switch (_filtro) {
      case _FiltroTipo.hoy:
        return 'Hoy, ${_fmtCorto.format(DateTime.now())}';
      case _FiltroTipo.rango:
        if (_rangoDesde == null || _rangoHasta == null) return 'Rango';
        return '${_fmtCorto.format(_rangoDesde!)} → ${_fmtCorto.format(_rangoHasta!)}';
    }
  }

  Future<void> _descargarPdf(List<LogEntry> logs) async {
    if (logs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No hay registros de cocción en ese período.')),
      );
      return;
    }
    setState(() => _generandoPdf = true);
    try {
      await PdfService.generarYCompartir(logs, etiqueta: _etiquetaFiltro);
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
    final todos     = context.watch<AppState>().logs;
    final filtrados = _aplicarFiltro(todos);
    final double anchoPantalla = MediaQuery.of(context).size.width;
    final double pad = anchoPantalla >= 600 ? 32.0 : 16.0;

    return Scaffold(
      appBar: const AppBarPrincipal(pantallaActual: 'logs'),
      drawer: const AppDrawer(pantallaActual: 'logs'),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(pad, 24, pad, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Título ────────────────────────────────────────────────
              const Text(
                'HISTORIAL DE COCCIONES',
                style: TextStyle(
                  color: Color(0xFFC62828),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Seleccioná un período y descargá el reporte en PDF.',
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),

              const SizedBox(height: 24),

              // ── Chips de filtro ───────────────────────────────────────
              Row(
                children: [
                  _FiltroChip(
                    label: 'Hoy',
                    icono: Icons.today_outlined,
                    activo: _filtro == _FiltroTipo.hoy,
                    onTap: () => setState(() => _filtro = _FiltroTipo.hoy),
                  ),
                  const SizedBox(width: 8),
                  _FiltroChip(
                    label: _filtro == _FiltroTipo.rango &&
                            _rangoDesde != null &&
                            _rangoHasta != null
                        ? '${_fmtCorto.format(_rangoDesde!)} → ${_fmtCorto.format(_rangoHasta!)}'
                        : 'Por fechas',
                    icono: Icons.date_range_outlined,
                    activo: _filtro == _FiltroTipo.rango,
                    onTap: _elegirRango,
                  ),
                ],
              ),

              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 20),

              // ── Resumen del período ───────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFCEAEA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long_outlined,
                        color: Color(0xFFC62828), size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _etiquetaFiltro,
                            style: const TextStyle(
                              color: Color(0xFFC62828),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${filtrados.length} cocción${filtrados.length == 1 ? '' : 'es'} registrada${filtrados.length == 1 ? '' : 's'}',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Botón PDF ─────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 50,
                child: _generandoPdf
                    ? const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Color(0xFFC62828),
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: () => _descargarPdf(filtrados),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC62828),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.picture_as_pdf_outlined,
                            size: 20),
                        label: const Text(
                          'DESCARGAR PDF',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Chip de filtro ───────────────────────────────────────────────────────────
class _FiltroChip extends StatelessWidget {
  final String label;
  final IconData icono;
  final bool activo;
  final VoidCallback onTap;

  const _FiltroChip({
    required this.label,
    required this.icono,
    required this.activo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: activo ? const Color(0xFFC62828) : const Color(0xFFF1F1F1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono,
                size: 15,
                color: activo ? Colors.white : Colors.grey[600]),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: activo ? Colors.white : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
