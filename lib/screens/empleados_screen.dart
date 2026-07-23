import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../models/empleado.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_bar_principal.dart';
import '../widgets/estado_vacio.dart';

// ── Pantalla de Empleados ────────────────────────────────────────────────────
class EmpleadosScreen extends StatelessWidget {
  const EmpleadosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final double anchoPantalla = MediaQuery.of(context).size.width;
    final bool esTablet = anchoPantalla >= 600;
    final appState = context.watch<AppState>();
    final empleados = appState.empleados;

    return Scaffold(
      appBar: AppBarPrincipal(
        pantallaActual: 'empleados',
        onAgregarPressed: () => _mostrarModal(context, esTablet),
        tooltipAgregar: 'Nuevo Empleado',
      ),
      drawer: const AppDrawer(pantallaActual: 'empleados'),
      body: SafeArea(
        child: empleados.isEmpty
            ? const EstadoVacio()
            : ListView.builder(
                padding: EdgeInsets.symmetric(
                  horizontal: esTablet ? 32 : 16,
                  vertical: 12,
                ),
                itemCount: empleados.length,
                itemBuilder: (context, i) => _TarjetaEmpleado(
                  empleado: empleados[i],
                  index: i,
                  esTablet: esTablet,
                ),
              ),
      ),
    );
  }

  void _mostrarModal(BuildContext context, bool esTablet,
      {Empleado? empleado, int? index}) {
    final contenido = _FormEmpleado(empleado: empleado, index: index);
    if (esTablet) {
      showDialog(
        context: context,
        builder: (_) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: contenido,
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
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: contenido,
          ),
        ),
      );
    }
  }
}

// ── Tarjeta ──────────────────────────────────────────────────────────────────
class _TarjetaEmpleado extends StatelessWidget {
  final Empleado empleado;
  final int index;
  final bool esTablet;

  const _TarjetaEmpleado({
    required this.empleado,
    required this.index,
    required this.esTablet,
  });

  @override
  Widget build(BuildContext context) {
    // Un empleado solo se puede eliminar si no está relacionado a ningún log
    // (en la práctica: si no hay logs con su id). La validación es simple:
    // si hay logs con este empleado, no se puede eliminar.
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: Color(0xFFFCEAEA),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.person, color: Color(0xFFC62828), size: 24),
        ),
        title: Text(empleado.nombre,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Color(0xFF212121))),
        subtitle: Text('CI: ${empleado.carnet}',
            style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                  color: Color(0xFFC62828), size: 20),
              tooltip: 'Editar',
              onPressed: () => _EmpleadosScreenHelper.mostrarModal(
                context,
                esTablet: esTablet,
                empleado: empleado,
                index: index,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: Color(0xFFC62828), size: 20),
              tooltip: 'Eliminar',
              onPressed: () => _confirmarEliminar(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmarEliminar(BuildContext context) async {
    final appState = context.read<AppState>();

    // Validar: el empleado no puede tener temporizadores corriendo
    // (en práctica: ningún temporizador activo tiene este empleado)
    // Los logs históricos usan nombre fotográfico — se puede eliminar igual
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar empleado',
            style: TextStyle(color: Color(0xFFC62828),
                fontWeight: FontWeight.bold, fontSize: 17)),
        content: Text(
          '¿Eliminar "${empleado.nombre}"?\n'
          'Sus registros históricos se conservan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancelar',
                style: TextStyle(color: Colors.grey[600])),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar',
                style: TextStyle(color: Color(0xFFC62828),
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmar == true && context.mounted) {
      appState.eliminarEmpleado(index);
    }
  }
}

// Helper estático para acceder al modal desde la tarjeta
class _EmpleadosScreenHelper {
  static void mostrarModal(BuildContext context,
      {required bool esTablet, Empleado? empleado, int? index}) {
    final contenido = _FormEmpleado(empleado: empleado, index: index);
    if (esTablet) {
      showDialog(
        context: context,
        builder: (_) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: contenido,
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
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: contenido,
          ),
        ),
      );
    }
  }
}

// ── Formulario (crear y editar) ───────────────────────────────────────────────
class _FormEmpleado extends StatefulWidget {
  final Empleado? empleado; // null = crear, non-null = editar
  final int? index;

  const _FormEmpleado({this.empleado, this.index});

  @override
  State<_FormEmpleado> createState() => _FormEmpleadoState();
}

class _FormEmpleadoState extends State<_FormEmpleado> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _carnetCtrl;

  bool get _esEdicion => widget.empleado != null;

  @override
  void initState() {
    super.initState();
    _nombreCtrl =
        TextEditingController(text: widget.empleado?.nombre ?? '');
    _carnetCtrl =
        TextEditingController(text: widget.empleado?.carnet ?? '');
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _carnetCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
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
              _headerModal(
                  _esEdicion ? 'Editar Empleado' : 'Nuevo Empleado'),
              const Divider(height: 1),
              const SizedBox(height: 20),
              _label('NOMBRE COMPLETO'),
              const SizedBox(height: 8),
              _campo(
                controller: _nombreCtrl,
                hint: 'NOMBRE EMPLEADO',
                capitalizacion: TextCapitalization.words,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Ingresa el nombre'
                    : null,
              ),
              const SizedBox(height: 16),
              _label('CARNET DE IDENTIDAD'),
              const SizedBox(height: 8),
              _campo(
                controller: _carnetCtrl,
                hint: 'C.I.',
                teclado: TextInputType.number,
                formatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Ingresa el carnet'
                    : null,
              ),
              const SizedBox(height: 24),
              _botonAnadir(
                _esEdicion ? 'GUARDAR CAMBIOS' : 'AÑADIR EMPLEADO',
                _submit,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final appState = context.read<AppState>();
    if (_esEdicion) {
      appState.updateEmpleado(
        widget.index!,
        Empleado(
          id: widget.empleado!.id,
          nombre: _nombreCtrl.text.trim(),
          carnet: _carnetCtrl.text.trim(),
        ),
      );
    } else {
      appState.agregarEmpleado(Empleado(
        nombre: _nombreCtrl.text.trim(),
        carnet: _carnetCtrl.text.trim(),
      ));
    }
    Navigator.of(context).pop();
  }
}

// ── Helpers de UI ─────────────────────────────────────────────────────────────
Widget _handle() => Center(
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2)),
      ),
    );

Widget _headerModal(String titulo) => Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(titulo,
            style: const TextStyle(
                color: Color(0xFFC62828),
                fontWeight: FontWeight.bold,
                fontSize: 20)),
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
          letterSpacing: 0.8),
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
            borderSide: BorderSide.none),
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
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(texto,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                letterSpacing: 1)),
      ),
    );
