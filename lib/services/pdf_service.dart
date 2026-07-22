import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/log_entry.dart';

class PdfService {
  static final DateFormat _fmtFecha = DateFormat('dd/MM/yyyy HH:mm', 'es_ES');

  // ── Historial general (logs_screen) ────────────────────────────────────────

  static Future<void> generarYCompartir(
    List<LogEntry> logs, {
    String etiqueta = '',
  }) async {
    final bytes = await _buildPdf(logs, etiqueta: etiqueta);
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'historial_elsolar_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
    );
  }

  static Future<Uint8List> _buildPdf(List<LogEntry> logs, {String etiqueta = ''}) async {
    final pdf = pw.Document();
    const PdfColor rojo      = PdfColor.fromInt(0xFFC62828);
    const PdfColor grisClaro = PdfColor.fromInt(0xFFF5F5F5);
    const PdfColor grisMedio = PdfColor.fromInt(0xFF757575);
    const PdfColor negro     = PdfColor.fromInt(0xFF212121);

    pdf.addPage(pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        buildBackground: (ctx) => pw.FullPage(
          ignoreMargins: true,
          child: pw.Container(color: PdfColors.white),
        ),
      ),
      header: (ctx) => _buildHeader(rojo, grisMedio),
      footer: (ctx) => _buildFooter(grisMedio, ctx),
      build: (ctx) => [
        _buildResumen(logs, etiqueta, rojo, grisMedio),
        pw.SizedBox(height: 16),
        _buildTabla(logs, rojo, grisClaro, negro, grisMedio),
      ],
    ));

    return pdf.save();
  }

  // ── Reporte por freidora ───────────────────────────────────────────────────

  static Future<void> generarReporteFreidora({
    required String nombreFreidora,
    required List<LogEntry> logsBoquilla1,
    required List<LogEntry> logsBoquilla2,
    required Map<String, dynamic> estadisticas,
    String etiquetaPeriodo = '',
  }) async {
    final bytes = await _buildPdfFreidora(
      nombreFreidora: nombreFreidora,
      logsBq1: logsBoquilla1,
      logsBq2: logsBoquilla2,
      stats: estadisticas,
      etiqueta: etiquetaPeriodo,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'reporte_${nombreFreidora.replaceAll(' ', '_')}'
          '_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  static Future<Uint8List> _buildPdfFreidora({
    required String nombreFreidora,
    required List<LogEntry> logsBq1,
    required List<LogEntry> logsBq2,
    required Map<String, dynamic> stats,
    required String etiqueta,
  }) async {
    final pdf = pw.Document();
    const PdfColor rojo      = PdfColor.fromInt(0xFFC62828);
    const PdfColor grisClaro = PdfColor.fromInt(0xFFF5F5F5);
    const PdfColor grisMedio = PdfColor.fromInt(0xFF757575);
    const PdfColor negro     = PdfColor.fromInt(0xFF212121);

    pdf.addPage(pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        buildBackground: (ctx) => pw.FullPage(
          ignoreMargins: true,
          child: pw.Container(color: PdfColors.white),
        ),
      ),
      header: (ctx) => _buildHeaderFreidora(nombreFreidora, etiqueta, rojo, grisMedio),
      footer: (ctx) => _buildFooter(grisMedio, ctx),
      build: (ctx) => [
        _buildEstadisticasPdf(stats, rojo, grisMedio),
        pw.SizedBox(height: 18),
        pw.Text('Boquilla 1 — Cocción (${logsBq1.length} registros)',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: rojo, fontSize: 11)),
        pw.SizedBox(height: 6),
        if (logsBq1.isEmpty)
          pw.Text('Sin registros', style: pw.TextStyle(color: grisMedio, fontSize: 9))
        else
          _buildTabla(logsBq1, rojo, grisClaro, negro, grisMedio),
        pw.SizedBox(height: 18),
        pw.Text('Boquilla 2 — Tostado (${logsBq2.length} registros)',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: rojo, fontSize: 11)),
        pw.SizedBox(height: 6),
        if (logsBq2.isEmpty)
          pw.Text('Sin registros', style: pw.TextStyle(color: grisMedio, fontSize: 9))
        else
          _buildTabla(logsBq2, rojo, grisClaro, negro, grisMedio),
      ],
    ));

    return pdf.save();
  }

  // ── Componentes compartidos ────────────────────────────────────────────────

  static pw.Widget _buildHeader(PdfColor rojo, PdfColor grisMedio) {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('EL SOLAR',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: rojo)),
          pw.Text('Historial de Cocciones',
              style: pw.TextStyle(fontSize: 12, color: grisMedio)),
        ]),
        pw.Text('Generado: ${_fmtFecha.format(DateTime.now())}',
            style: pw.TextStyle(fontSize: 9, color: grisMedio)),
      ]),
      pw.SizedBox(height: 6),
      pw.Divider(color: rojo, thickness: 2),
      pw.SizedBox(height: 8),
    ]);
  }

  static pw.Widget _buildHeaderFreidora(
      String nombreFreidora, String etiqueta, PdfColor rojo, PdfColor grisMedio) {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('EL SOLAR',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: rojo)),
          pw.Text('Reporte Freidora: $nombreFreidora',
              style: pw.TextStyle(fontSize: 11, color: grisMedio)),
          if (etiqueta.isNotEmpty)
            pw.Text('Período: $etiqueta',
                style: pw.TextStyle(fontSize: 9, color: grisMedio, fontStyle: pw.FontStyle.italic)),
        ]),
        pw.Text('Generado: ${_fmtFecha.format(DateTime.now())}',
            style: pw.TextStyle(fontSize: 9, color: grisMedio)),
      ]),
      pw.SizedBox(height: 6),
      pw.Divider(color: rojo, thickness: 2),
      pw.SizedBox(height: 8),
    ]);
  }

  static pw.Widget _buildFooter(PdfColor grisMedio, pw.Context context) {
    return pw.Column(children: [
      pw.Divider(color: grisMedio, thickness: 0.5),
      pw.SizedBox(height: 4),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('SUCURSAL CAÑOTO', style: pw.TextStyle(fontSize: 8, color: grisMedio)),
        pw.Text('Página ${context.pageNumber} de ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 8, color: grisMedio)),
      ]),
    ]);
  }

  static pw.Widget _buildResumen(
      List<LogEntry> logs, String etiqueta, PdfColor rojo, PdfColor grisMedio) {
    final int total = logs.length;
    final int completados = logs.where((l) => l.fechaHoraFin != null).length;
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      if (etiqueta.isNotEmpty)
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Text('Período: $etiqueta',
              style: pw.TextStyle(fontSize: 10, color: grisMedio, fontStyle: pw.FontStyle.italic)),
        ),
      pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: const PdfColor.fromInt(0xFFFCEAEA),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
          _statItem('Total cocciones', '$total', rojo),
          _statItem('Completadas', '$completados', rojo),
        ]),
      ),
    ]);
  }

  static pw.Widget _buildEstadisticasPdf(
      Map<String, dynamic> stats, PdfColor rojo, PdfColor grisMedio) {
    final int promSeg = stats['promedio_seg'] as int? ?? 0;
    final int pm = promSeg ~/ 60;
    final int ps = promSeg % 60;
    final String prom = promSeg > 0 ? '${pm}m ${ps}s' : '—';
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFFCEAEA),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
        _statItem('Cocción (B1)', '${stats['total_coccion'] ?? 0}', rojo),
        _statItem('Tostado (B2)', '${stats['total_tostado'] ?? 0}', rojo),
        _statItem('Prom. duración', prom, grisMedio),
      ]),
    );
  }

  static pw.Widget _statItem(String label, String valor, PdfColor color) {
    return pw.Column(children: [
      pw.Text(valor,
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: color)),
      pw.Text(label, style: pw.TextStyle(fontSize: 9, color: color)),
    ]);
  }

  static pw.Widget _buildTabla(
    List<LogEntry> logs,
    PdfColor rojo,
    PdfColor grisClaro,
    PdfColor negro,
    PdfColor grisMedio,
  ) {
    const headers = ['Empleado', 'Freidora', 'Producto', 'Inicio', 'Fin', 'Duración'];
    final columnWidths = {
      0: const pw.FlexColumnWidth(2.2),
      1: const pw.FlexColumnWidth(1.4),
      2: const pw.FlexColumnWidth(2.0),
      3: const pw.FlexColumnWidth(2.2),
      4: const pw.FlexColumnWidth(2.2),
      5: const pw.FlexColumnWidth(1.2),
    };
    return pw.TableHelper.fromTextArray(
      headers: headers,
      columnWidths: columnWidths,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
      headerDecoration: pw.BoxDecoration(color: rojo),
      headerAlignment: pw.Alignment.centerLeft,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      cellStyle: pw.TextStyle(fontSize: 9, color: negro),
      rowDecoration: pw.BoxDecoration(color: PdfColors.white),
      oddRowDecoration: pw.BoxDecoration(color: grisClaro),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.center,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.center,
        4: pw.Alignment.center,
        5: pw.Alignment.center,
      },
      data: logs.map((l) => [
        l.nombreEmpleado,
        l.nombreFreidora,
        l.nombreProducto,
        _fmtFecha.format(l.fechaHoraInicio),
        l.fechaHoraFin != null ? _fmtFecha.format(l.fechaHoraFin!) : '—',
        l.duracionFormateada,
      ]).toList(),
    );
  }
}
