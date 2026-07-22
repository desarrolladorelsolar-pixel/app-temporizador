import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../models/producto.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_bar_principal.dart';
import '../widgets/estado_vacio.dart';

// ── Pantalla de Productos ────────────────────────────────────────────────────
class ProductosScreen extends StatelessWidget {
  const ProductosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final double anchoPantalla = MediaQuery.of(context).size.width;
    final bool esTablet = anchoPantalla >= 600;
    final appState = context.watch<AppState>();
    final productos = appState.productos;

    return Scaffold(
      appBar: AppBarPrincipal(
        pantallaActual: 'productos',
        onAgregarPressed: () =>
            _ProductosScreenHelper.mostrarModal(context, esTablet: esTablet),
        tooltipAgregar: 'Nuevo Producto',
      ),
      drawer: const AppDrawer(pantallaActual: 'productos'),
      body: SafeArea(
        child: productos.isEmpty
            ? const EstadoVacio()
            : ListView.builder(
                padding: EdgeInsets.symmetric(
                  horizontal: esTablet ? 32 : 16,
                  vertical: 12,
                ),
                itemCount: productos.length,
                itemBuilder: (context, i) => _TarjetaProducto(
                  producto: productos[i],
                  index: i,
                  esTablet: esTablet,
                ),
              ),
      ),
    );
  }
}

// ── Tarjeta ──────────────────────────────────────────────────────────────────
class _TarjetaProducto extends StatelessWidget {
  final Producto producto;
  final int index;
  final bool esTablet;

  const _TarjetaProducto({
    required this.producto,
    required this.index,
    required this.esTablet,
  });

  @override
  Widget build(BuildContext context) {
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
          child: const Icon(Icons.fastfood,
              color: Color(0xFFC62828), size: 22),
        ),
        title: Text(
          producto.nombre,
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Color(0xFF212121)),
        ),
        subtitle: Text(
          'B1 Cocción: ${producto.tiempoCoccion} min · B2 Tostado: ${producto.tiempoTostado} min'
          '${producto.tiempoRepaso > 0 ? ' · Repaso B${producto.boquillaRepaso}: ${producto.tiempoRepaso} min' : ''}',
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit_outlined,
              color: Color(0xFFC62828), size: 20),
          tooltip: 'Editar',
          onPressed: () => _ProductosScreenHelper.mostrarModal(
            context,
            esTablet: esTablet,
            producto: producto,
            index: index,
          ),
        ),
      ),
    );
  }
}

// ── Helper estático para abrir el modal ──────────────────────────────────────
class _ProductosScreenHelper {
  static void mostrarModal(BuildContext context,
      {required bool esTablet, Producto? producto, int? index}) {
    final contenido = _FormProducto(producto: producto, index: index);
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
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
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
class _FormProducto extends StatefulWidget {
  final Producto? producto; // null = crear, non-null = editar
  final int? index;

  const _FormProducto({this.producto, this.index});

  @override
  State<_FormProducto> createState() => _FormProductoState();
}

class _FormProductoState extends State<_FormProducto> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _coccionCtrl;
  late final TextEditingController _tostadoCtrl;
  late final TextEditingController _repasoCtrl;
  int _boquillaRepaso = 1; // 1 = Boquilla 1 (cocción) | 2 = Boquilla 2 (tostado)

  bool get _esEdicion => widget.producto != null;

  @override
  void initState() {
    super.initState();
    _nombreCtrl  = TextEditingController(text: widget.producto?.nombre ?? '');
    _coccionCtrl = TextEditingController(
        text: widget.producto != null ? widget.producto!.tiempoCoccion.toString() : '');
    _tostadoCtrl = TextEditingController(
        text: widget.producto != null ? widget.producto!.tiempoTostado.toString() : '');
    _repasoCtrl  = TextEditingController(
        text: (widget.producto?.tiempoRepaso ?? 0) > 0
            ? widget.producto!.tiempoRepaso.toString()
            : '');
    _boquillaRepaso = widget.producto?.boquillaRepaso ?? 1;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _coccionCtrl.dispose();
    _tostadoCtrl.dispose();
    _repasoCtrl.dispose();
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
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _esEdicion ? 'Editar Producto' : 'Nuevo Producto',
                    style: const TextStyle(
                        color: Color(0xFFC62828),
                        fontWeight: FontWeight.bold,
                        fontSize: 20),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black54),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 1),
              const SizedBox(height: 20),

              // Nombre
              _labelF('NOMBRE DEL PRODUCTO'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nombreCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: _deco('PRODUCTO'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Ingresa el nombre'
                    : null,
              ),
              const SizedBox(height: 16),

              // Tiempos en fila
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _labelF('COCCIÓN — B1 (MIN)'),
                        const SizedBox(height: 8),
                        _campoTiempo(_coccionCtrl, 'Ej. 10'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _labelF('TOSTADO — B2 (MIN)'),
                        const SizedBox(height: 8),
                        _campoTiempo(_tostadoCtrl, 'Ej. 10'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Repaso + selector de boquilla
              _labelF('REPASO (MIN) — OPCIONAL'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _campoTiempoOpcional(_repasoCtrl, 'Ej. 2')),
                  const SizedBox(width: 12),
                  _SelectorBoquilla(
                    valor: _boquillaRepaso,
                    onChanged: (v) => setState(() => _boquillaRepaso = v),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Boquilla donde se hace el repaso: B1 = Cocción · B2 = Tostado',
                style: TextStyle(color: Colors.grey[500], fontSize: 11),
              ),
              const SizedBox(height: 24),

              // Botón
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC62828),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    _esEdicion ? 'GUARDAR CAMBIOS' : 'AÑADIR PRODUCTO',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: 1),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _labelF(String texto) => Text(
        texto,
        style: const TextStyle(
            color: Color(0xFFC62828),
            fontWeight: FontWeight.bold,
            fontSize: 11,
            letterSpacing: 0.8),
      );

  InputDecoration _deco(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF1F1F1),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );

  Widget _campoTiempo(TextEditingController ctrl, String hint) =>
      TextFormField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: _deco(hint),
        validator: (v) =>
            (v == null || v.trim().isEmpty) ? 'Requerido' : null,
      );

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final appState = context.read<AppState>();
    if (_esEdicion) {
      appState.updateProducto(
        widget.index!,
        Producto(
          id: widget.producto!.id,
          nombre: _nombreCtrl.text.trim(),
          tiempoCoccion: int.tryParse(_coccionCtrl.text) ?? 0,
          tiempoTostado: int.tryParse(_tostadoCtrl.text) ?? 0,
          tiempoRepaso: int.tryParse(_repasoCtrl.text) ?? 0,
          boquillaRepaso: _boquillaRepaso,
        ),
      );
    } else {
      appState.agregarProducto(Producto(
        nombre: _nombreCtrl.text.trim(),
        tiempoCoccion: int.tryParse(_coccionCtrl.text) ?? 0,
        tiempoTostado: int.tryParse(_tostadoCtrl.text) ?? 0,
        tiempoRepaso: int.tryParse(_repasoCtrl.text) ?? 0,
        boquillaRepaso: _boquillaRepaso,
      ));
    }
    Navigator.of(context).pop();
  }

  Widget _campoTiempoOpcional(TextEditingController ctrl, String hint) =>
      TextFormField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: _deco(hint),
        // Sin validator — el repaso es opcional (0 = sin repaso)
      );
}

// ── Selector de boquilla para el repaso ──────────────────────────────────────
class _SelectorBoquilla extends StatelessWidget {
  final int valor;
  final ValueChanged<int> onChanged;

  const _SelectorBoquilla({required this.valor, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'BOQUILLA',
          style: TextStyle(
              color: Color(0xFFC62828),
              fontWeight: FontWeight.bold,
              fontSize: 11,
              letterSpacing: 0.8),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ChipBoquilla(
              etiqueta: 'B1',
              subtitulo: 'Cocción',
              activo: valor == 1,
              onTap: () => onChanged(1),
            ),
            const SizedBox(width: 8),
            _ChipBoquilla(
              etiqueta: 'B2',
              subtitulo: 'Tostado',
              activo: valor == 2,
              onTap: () => onChanged(2),
            ),
          ],
        ),
      ],
    );
  }
}

class _ChipBoquilla extends StatelessWidget {
  final String etiqueta;
  final String subtitulo;
  final bool activo;
  final VoidCallback onTap;

  const _ChipBoquilla({
    required this.etiqueta,
    required this.subtitulo,
    required this.activo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: activo ? const Color(0xFFC62828) : const Color(0xFFF1F1F1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              etiqueta,
              style: TextStyle(
                color: activo ? Colors.white : const Color(0xFF424242),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            Text(
              subtitulo,
              style: TextStyle(
                color: activo ? Colors.white70 : Colors.grey[500],
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
