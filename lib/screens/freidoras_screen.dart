import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../models/freidora.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_bar_principal.dart';
import '../widgets/estado_vacio.dart';

// ── Pantalla de Freidoras ────────────────────────────────────────────────────
class FreidorasScreen extends StatelessWidget {
  const FreidorasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final double anchoPantalla = MediaQuery.of(context).size.width;
    final bool esTablet = anchoPantalla >= 600;
    final double pad = esTablet ? 32.0 : 16.0;
    final freidoras = context.watch<AppState>().freidoras;

    return Scaffold(
      appBar: AppBarPrincipal(
        pantallaActual: 'freidoras',
        onAgregarPressed: () => _mostrarModal(context, esTablet),
        tooltipAgregar: 'Nueva Freidora',
      ),
      drawer: const AppDrawer(pantallaActual: 'freidoras'),
      body: SafeArea(
        child: freidoras.isEmpty
            ? const EstadoVacio()
            : ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: pad, vertical: 12),
                itemCount: freidoras.length,
                itemBuilder: (context, i) =>
                    _TarjetaFreidora(freidora: freidoras[i]),
              ),
      ),
    );
  }

  void _mostrarModal(BuildContext context, bool esTablet) {
    if (esTablet) {
      showDialog(
        context: context,
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: const _FormFreidora(),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (_, __) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: const _FormFreidora(),
          ),
        ),
      );
    }
  }
}

// ── Tarjeta de freidora ───────────────────────────────────────────────────────
class _TarjetaFreidora extends StatelessWidget {
  final dynamic freidora;
  const _TarjetaFreidora({required this.freidora});

  @override
  Widget build(BuildContext context) {
    final bool activa = freidora.estado == 'activo';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12))),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: const SizedBox(
          width: 44,
          height: 44,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xFFFCEAEA),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.donut_large, color: Color(0xFFC62828), size: 24),
          ),
        ),
        title: Text(
          freidora.codigo,
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Color(0xFF212121)),
        ),
        subtitle: Text(
          freidora.descripcion,
          style: const TextStyle(color: Color(0xFF757575), fontSize: 13),
        ),
        trailing: _Badge(activa: activa),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final bool activa;
  const _Badge({required this.activa});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: activa ? const Color(0xFFE8F5E9) : const Color(0xFFFCEAEA),
        borderRadius: const BorderRadius.all(Radius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          activa ? 'Disponible' : 'Inactiva',
          style: TextStyle(
            color: activa ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

// ── Formulario ───────────────────────────────────────────────────────────────
class _FormFreidora extends StatefulWidget {
  const _FormFreidora();

  @override
  State<_FormFreidora> createState() => _FormFreidoraState();
}

class _FormFreidoraState extends State<_FormFreidora> {
  final _formKey = GlobalKey<FormState>();
  final _codigoCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();

  @override
  void dispose() {
    _codigoCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _handle(),
              _headerModal('Nueva Freidora'),
              const Divider(height: 1),
              const SizedBox(height: 20),
              _label('CÓDIGO DE FREIDORA'),
              const SizedBox(height: 8),
              _campo(
                controller: _codigoCtrl,
                hint: 'CODIGO',
                capitalizacion: TextCapitalization.characters,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Ingresa el código' : null,
              ),
              const SizedBox(height: 16),
              _label('DESCRIPCIÓN'),
              const SizedBox(height: 8),
              _campo(
                controller: _descripcionCtrl,
                hint: 'DESCRIPCION',
                capitalizacion: TextCapitalization.sentences,
                maxLines: 2,
                validator: (v) =>
                    (v == null || v.trim().isEmpty)
                        ? 'Ingresa la descripción'
                        : null,
              ),
              const SizedBox(height: 24),
              _botonAnadir('AÑADIR FREIDORA', _submit),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      context.read<AppState>().agregarFreidora(Freidora(
        codigo: _codigoCtrl.text.trim().toUpperCase(),
        descripcion: _descripcionCtrl.text.trim(),
        estado: 'activo', // ← debe coincidir con el CHECK de SQLite
      ));
      Navigator.of(context).pop();
    }
  }
}

// ── Helpers reutilizados (importados desde empleados_screen via barrel no es
//    posible sin crear un archivo separado, así que se repiten aquí — en el
//    siguiente paso se pueden mover a lib/widgets/form_helpers.dart) ──────────
Widget _handle() => Center(
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );

Widget _headerModal(String titulo) => Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            color: Color(0xFFC62828),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.close, color: Colors.black54),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ),
      ],
    );

Widget _label(String texto) => Text(
      texto,
      style: const TextStyle(
        color: Color(0xFFC62828),
        fontWeight: FontWeight.bold,
        fontSize: 11,
        letterSpacing: 0.8,
      ),
    );

Widget _campo({
  required TextEditingController controller,
  required String hint,
  TextCapitalization capitalizacion = TextCapitalization.none,
  TextInputType teclado = TextInputType.text,
  List<TextInputFormatter>? formatters,
  String? Function(String?)? validator,
  int maxLines = 1,
}) =>
    TextFormField(
      controller: controller,
      keyboardType: teclado,
      inputFormatters: formatters,
      textCapitalization: capitalizacion,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF1F1F1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      validator: validator,
    );

Widget _botonAnadir(String texto, VoidCallback onPressed) => SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFC62828),
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          texto,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            letterSpacing: 1,
          ),
        ),
      ),
    );
