import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/log_entry.dart';

// ── Servicio de generación y exportación de PDF ──────────────────────────────
class PdfService {
  static final DateFormat _fmtFecha =
      DateFormat('dd/MM/yyyy HH:mm', 'es_ES');

  /// Genera el PDF con los logs dados y abre el diálogo de impresión/compartir
  static Future<void> generarYCompartir(
    List<LogEntry> logs, {
    String etiqueta = '',
  }) async {
    final Uint8List bytes = await _buildPdf(logs, etiqueta: etiqueta);
    await Printing.sharePdf(
      bytes: bytes,
      filename:
          'historial_elsolar_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
    );
  }

  // ── Construcción del documento ────────────────────────────────────────────
  static Future<Uint8List> _buildPdf(
    List<LogEntry> logs, {
    String etiqueta = '',
  }) async {
    final pdf = pw.Document();

    const PdfColor rojo = PdfColor.fromInt(0xFFC62828);
    const PdfColor grisClaro = PdfColor.fromInt(0xFFF5F5F5);
    const PdfColor grisMedio = PdfColor.fromInt(0xFF757575);
    const PdfColor negro = PdfColor.fromInt(0xFF212121);

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 28),
          buildBackground: (context) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Container(color: PdfColors.white),
          ),
        ),
        header: (context) => _buildHeader(rojo, grisMedio),
        footer: (context) => _buildFooter(grisMedio, context),
        build: (context) => [
          _buildResumen(logs, etiqueta, rojo, grisMedio),
          pw.SizedBox(height: 16),
          _buildTabla(logs, rojo, grisClaro, negro, grisMedio),
        ],
      ),
    );

    return pdf.save();
  }

  // ── Header ────────────────────────────────────────────────────────────────
  static pw.Widget _buildHeader(PdfColor rojo, PdfColor grisMedio) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'EL SOLAR',
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: rojo,
                  ),
                ),
                pw.Text(
                  'Historial de Cocciones',
                  style: pw.TextStyle(
                    fontSize: 12,
                    color: grisMedio,
                  ),
                ),
              ],
            ),
            pw.Text(
              'Generado: ${_fmtFecha.format(DateTime.now())}',
              style: pw.TextStyle(fontSize: 9, color: grisMedio),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Divider(color: rojo, thickness: 2),
        pw.SizedBox(height: 8),
      ],
    );
  }

  // ── Footer ────────────────────────────────────────────────────────────────
  static pw.Widget _buildFooter(
      PdfColor grisMedio, pw.Context context) {
    return pw.Column(
      children: [
        pw.Divider(color: grisMedio, thickness: 0.5),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('SUCURSAL CAÑOTO',
                style: pw.TextStyle(fontSize: 8, color: grisMedio)),
            pw.Text(
              'Página ${context.pageNumber} de ${context.pagesCount}',
              style: pw.TextStyle(fontSize: 8, color: grisMedio),
            ),
          ],
        ),
      ],
    );
  }

  // ── Resumen ───────────────────────────────────────────────────────────────
  static pw.Widget _buildResumen(
      List<LogEntry> logs, String etiqueta, PdfColor rojo, PdfColor grisMedio) {
    final int total = logs.length;
    final int completados = logs.where((l) => l.fechaHoraFin != null).length;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Etiqueta del período filtrado
        if (etiqueta.isNotEmpty)
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Text(
              'Período: $etiqueta',
              style: pw.TextStyle(
                  fontSize: 10,
                  color: grisMedio,
                  fontStyle: pw.FontStyle.italic),
            ),
          ),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: const PdfColor.fromInt(0xFFFCEAEA),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _statItem('Total cocciones', '$total', rojo),
              _statItem('Completadas', '$completados', rojo),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _statItem(String label, String valor, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(valor,
            style: pw.TextStyle(
                fontSize: 20, fontWeight: pw.FontWeight.bold, color: color)),
        pw.Text(label,
            style: pw.TextStyle(fontSize: 9, color: color)),
      ],
    );
  }

  // ── Tabla ─────────────────────────────────────────────────────────────────
  static pw.Widget _buildTabla(
    List<LogEntry> logs,
    PdfColor rojo,
    PdfColor grisClaro,
    PdfColor negro,
    PdfColor grisMedio,
  ) {
    const headers = [
      'Empleado',
      'Freidora',
      'Producto',
      'Inicio',
      'Fin',
      'Duración',
    ];

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
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
        fontSize: 9,
      ),
      headerDecoration: pw.BoxDecoration(color: rojo),
      headerAlignment: pw.Alignment.centerLeft,
      cellPadding:
          const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
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
      data: logs
          .map((l) => [
                l.nombreEmpleado,
                l.nombreFreidora,
                l.nombreProducto,
                _fmtFecha.format(l.fechaHoraInicio),
                l.fechaHoraFin != null
                    ? _fmtFecha.format(l.fechaHoraFin!)
                    : '—',
                l.duracionFormateada,
              ])
          .toList(),
    );
  }
}
