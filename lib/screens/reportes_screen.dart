import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/freidora.dart';
import '../models/log_entry.dart';
import '../services/pdf_service.dart';
import '../state/app_state.dart';
import '../widgets/app_bar_principal.dart';
import '../widgets/app_drawer.dart';
import 'reporte_freidora_screen.dart';

class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  bool _autenticado = false;
  final _pwdCtrl = TextEditingController();
  bool _errorPwd = false;
  bool _ocultarPwd = true;

  static const String _kPassword = 'pollosolarsito';

  // Filtros para exportación general
  static final DateFormat _fmtCorto = DateFormat('dd/MM/yyyy', 'es_ES');
  String _filtro = 'hoy';
  DateTime? _rangoDesde;
  DateTime? _rangoHasta;
  bool _generandoPdf = false;

  @override
  void dispose() {
    _pwdCtrl.dispose();
    super.dispose();
  }

  void _validarPassword() {
    if (_pwdCtrl.text.trim() == _kPassword) {
      context.read<AppState>().recargarLogs();
      setState(() { _autenticado = true; _errorPwd = false; });
    } else {
      setState(() => _errorPwd = true);
      _pwdCtrl.clear();
    }
  }

  List<LogEntry> _aplicarFiltro(List<LogEntry> todos) {
    final hoy = DateTime.now();
    switch (_filtro) {
      case 'hoy':
        return todos.where((l) {
          final f = l.fechaHoraInicio;
          return f.year == hoy.year && f.month == hoy.month && f.day == hoy.day;
        }).toList();
      case 'rango':
        if (_rangoDesde == null || _rangoHasta == null) return todos;
        final desde = DateTime(
            _rangoDesde!.year, _rangoDesde!.month, _rangoDesde!.day);
        final hasta = DateTime(
            _rangoHasta!.year, _rangoHasta!.month, _rangoHasta!.day, 23, 59, 59);
        return todos.where((l) =>
            !l.fechaHoraInicio.isBefore(desde) &&
            !l.fechaHoraInicio.isAfter(hasta)).toList();
      default: return todos;
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
          : DateTimeRange(
              start: ahora.subtract(const Duration(days: 6)), end: ahora),
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
      context.read<AppState>().recargarLogs();
    }
  }

  String get _etiquetaFiltro {
    if (_filtro == 'hoy') return 'Hoy, ${_fmtCorto.format(DateTime.now())}';
    if (_rangoDesde != null && _rangoHasta != null) {
      return '${_fmtCorto.format(_rangoDesde!)} → ${_fmtCorto.format(_rangoHasta!)}';
    }
    return 'Período';
  }

  Future<void> _descargarPdfGeneral() async {
    final todos = context.read<AppState>().logs;
    final filtrados = _aplicarFiltro(todos);
    if (filtrados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay registros para exportar.')));
      return;
    }
    setState(() => _generandoPdf = true);
    try {
      await PdfService.generarYCompartir(filtrados, etiqueta: _etiquetaFiltro);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al generar PDF: $e')));
      }
    } finally {
      if (mounted) setState(() => _generandoPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarPrincipal(pantallaActual: 'reportes'),
      drawer: const AppDrawer(pantallaActual: 'reportes'),
      body: SafeArea(
        child: _autenticado ? _buildDashboard() : _buildLogin(),
      ),
    );
  }

  // ── Login ──────────────────────────────────────────────────────────────────
  Widget _buildLogin() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.bar_chart_rounded,
              size: 72, color: Color(0xFFC62828)),
          const SizedBox(height: 16),
          const Text('REPORTES',
              style: TextStyle(color: Color(0xFFC62828),
                  fontWeight: FontWeight.bold, fontSize: 22, letterSpacing: 2)),
          const SizedBox(height: 8),
          Text('Ingresá la contraseña para acceder',
              style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          const SizedBox(height: 32),
          TextField(
            controller: _pwdCtrl,
            obscureText: _ocultarPwd,
            onSubmitted: (_) => _validarPassword(),
            decoration: InputDecoration(
              hintText: 'Contraseña',
              filled: true,
              fillColor: const Color(0xFFF1F1F1),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              errorText: _errorPwd ? 'Contraseña incorrecta' : null,
              suffixIcon: IconButton(
                icon: Icon(_ocultarPwd
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                    color: Colors.grey[500]),
                onPressed: () =>
                    setState(() => _ocultarPwd = !_ocultarPwd),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: _validarPassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC62828),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
              child: const Text('ACCEDER',
                  style: TextStyle(fontWeight: FontWeight.bold,
                      fontSize: 15, letterSpacing: 1)),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Dashboard ──────────────────────────────────────────────────────────────
  Widget _buildDashboard() {
    final appState = context.watch<AppState>();
    final freidoras = appState.freidoras;
    final filtrados = _aplicarFiltro(appState.logs);
    final double pad = MediaQuery.of(context).size.width >= 600 ? 32.0 : 16.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(pad, 14, pad, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Título + cerrar sesión
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('REPORTES',
                      style: TextStyle(color: Color(0xFFC62828),
                          fontWeight: FontWeight.bold,
                          fontSize: 13, letterSpacing: 1.2)),
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _autenticado = false; _pwdCtrl.clear();
                    }),
                    icon: const Icon(Icons.logout, size: 15,
                        color: Color(0xFF9E9E9E)),
                    label: const Text('Salir',
                        style: TextStyle(
                            color: Color(0xFF9E9E9E), fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // ── Filtros ──────────────────────────────────────────────
              Row(children: [
                _FiltroChip(
                  label: 'Hoy',
                  activo: _filtro == 'hoy',
                  onTap: () {
                    setState(() {
                      _filtro = 'hoy';
                      _rangoDesde = null;
                      _rangoHasta = null;
                    });
                    context.read<AppState>().recargarLogs();
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
              ]),
              const SizedBox(height: 10),

              // ── Resumen + botón PDF ───────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFCEAEA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  const Icon(Icons.receipt_long_outlined,
                      color: Color(0xFFC62828), size: 26),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_etiquetaFiltro,
                            style: const TextStyle(
                                color: Color(0xFFC62828),
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                        Text(
                          '${filtrados.length} cocción${filtrados.length == 1 ? '' : 'es'}',
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 12)),
                      ],
                    ),
                  ),
                  _generandoPdf
                      ? const SizedBox(width: 32, height: 32,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Color(0xFFC62828)))
                      : ElevatedButton.icon(
                          onPressed: _descargarPdfGeneral,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFC62828),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          icon: const Icon(
                              Icons.picture_as_pdf_outlined, size: 16),
                          label: const Text('PDF',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        ),
                ]),
              ),
            ],
          ),
        ),

        const Divider(height: 16),

        // ── Lista de freidoras ────────────────────────────────────────────
        Padding(
          padding: EdgeInsets.symmetric(horizontal: pad),
          child: const Text('POR FREIDORA',
              style: TextStyle(color: Color(0xFFC62828),
                  fontWeight: FontWeight.bold,
                  fontSize: 12, letterSpacing: 1.1)),
        ),
        const SizedBox(height: 6),

        Expanded(
          child: freidoras.isEmpty
              ? Center(
                  child: Text('No hay freidoras registradas',
                      style: TextStyle(
                          color: Colors.grey[400], fontSize: 15)))
              : ListView.builder(
                  padding: EdgeInsets.symmetric(
                      horizontal: pad, vertical: 4),
                  itemCount: freidoras.length,
                  itemBuilder: (ctx, i) =>
                      _TarjetaFreidoraReporte(freidora: freidoras[i]),
                ),
        ),
      ],
    );
  }
}

// ── Chip de filtro ────────────────────────────────────────────────────────────
class _FiltroChip extends StatelessWidget {
  final String label;
  final bool activo;
  final VoidCallback onTap;
  const _FiltroChip(
      {required this.label, required this.activo, required this.onTap});

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
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: activo ? Colors.white : Colors.grey[700])),
      ),
    );
  }
}

// ── Tarjeta de freidora ───────────────────────────────────────────────────────
class _TarjetaFreidoraReporte extends StatelessWidget {
  final Freidora freidora;
  const _TarjetaFreidoraReporte({required this.freidora});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: const SizedBox(
          width: 44, height: 44,
          child: DecoratedBox(
            decoration: BoxDecoration(
                color: Color(0xFFFCEAEA), shape: BoxShape.circle),
            child: Icon(Icons.donut_large,
                color: Color(0xFFC62828), size: 24),
          ),
        ),
        title: Text(freidora.codigo,
            style: const TextStyle(fontWeight: FontWeight.bold,
                fontSize: 15, color: Color(0xFF212121))),
        subtitle: Text(
          freidora.descripcion.isEmpty
              ? 'Sin descripción'
              : freidora.descripcion,
          style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 13)),
        trailing: const Icon(Icons.chevron_right,
            color: Color(0xFFC62828)),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ReporteFreidoraScreen(freidora: freidora))),
      ),
    );
  }
}
