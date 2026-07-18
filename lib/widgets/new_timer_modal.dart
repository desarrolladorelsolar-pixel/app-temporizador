import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../models/freidora.dart';
import '../models/producto.dart';
import '../models/temporizador.dart';
import '../screens/freidoras_screen.dart';
import '../screens/productos_screen.dart';

// ── Función helper: muestra el modal o aviso de prerequisitos ────────────────
void mostrarNuevoTemporizador(BuildContext context) {
  final appState = context.read<AppState>();
  final bool sinFreidoras = appState.freidoras.isEmpty;
  final bool sinProductos = appState.productos.isEmpty;

  // Verificar si faltan datos antes de abrir el formulario
  if (sinFreidoras || sinProductos) {
    _mostrarAvisoPrerequisitos(context, sinFreidoras, sinProductos);
    return;
  }

  final double ancho = MediaQuery.of(context).size.width;
  final bool esTablet = ancho >= 600;

  if (esTablet) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: const _NuevoTemporizadorContenido(),
        ),
      ),
    );
  } else {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, __) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: const _NuevoTemporizadorContenido(),
        ),
      ),
    );
  }
}

// ── AlertDialog cuando faltan freidoras o productos ─────────────────────────
void _mostrarAvisoPrerequisitos(
    BuildContext context, bool sinFreidoras, bool sinProductos) {
  String mensaje = 'Debes registrar al menos ';
  if (sinFreidoras && sinProductos) {
    mensaje += 'una Freidora y un Producto';
  } else if (sinFreidoras) {
    mensaje += 'una Freidora';
  } else {
    mensaje += 'un Producto';
  }
  mensaje += ' antes de crear un temporizador.';

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Datos requeridos',
        style: TextStyle(
          color: Color(0xFFC62828),
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Text(mensaje),
      actions: [
        // Botón Ir a Freidoras (solo si faltan freidoras)
        if (sinFreidoras)
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FreidorasScreen()),
              );
            },
            child: const Text(
              'Ir a Freidoras',
              style: TextStyle(color: Color(0xFFC62828)),
            ),
          ),
        // Botón Ir a Productos (solo si faltan productos)
        if (sinProductos)
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProductosScreen()),
              );
            },
            child: const Text(
              'Ir a Productos',
              style: TextStyle(color: Color(0xFFC62828)),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text('Cancelar', style: TextStyle(color: Colors.grey[600])),
        ),
      ],
    ),
  );
}

// ── Contenido interno del modal ──────────────────────────────────────────────
class _NuevoTemporizadorContenido extends StatefulWidget {
  const _NuevoTemporizadorContenido();

  @override
  State<_NuevoTemporizadorContenido> createState() =>
      _NuevoTemporizadorContenidoState();
}

class _NuevoTemporizadorContenidoState
    extends State<_NuevoTemporizadorContenido> {
  Freidora? _freidoraSeleccionada;
  Producto? _productoSeleccionado;

  final TextEditingController _coccionCtrl = TextEditingController();
  final TextEditingController _tostadoCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Inicializar con los primeros elementos disponibles
    final appState = context.read<AppState>();
    if (appState.freidoras.isNotEmpty) {
      _freidoraSeleccionada = appState.freidoras.first;
    }
    if (appState.productos.isNotEmpty) {
      _productoSeleccionado = appState.productos.first;
      // Autocompletar los tiempos con el primer producto
      _coccionCtrl.text = appState.productos.first.tiempoCoccion.toString();
      _tostadoCtrl.text = appState.productos.first.tiempoTostado.toString();
    }
  }

  @override
  void dispose() {
    _coccionCtrl.dispose();
    _tostadoCtrl.dispose();
    super.dispose();
  }

  // Al cambiar producto, autocompletar los tiempos
  void _onProductoChanged(Producto? p) {
    if (p == null) return;
    setState(() {
      _productoSeleccionado = p;
      _coccionCtrl.text = p.tiempoCoccion.toString();
      _tostadoCtrl.text = p.tiempoTostado.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle visual
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Nuevo Temporizador',
                  style: TextStyle(
                    color: Color(0xFFC62828),
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black54),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 1),
            const SizedBox(height: 20),

            // ── 1. Seleccionar freidora ───────────────────────────────────
            _labelSeccion('1. SELECCIONAR FREIDORA'),
            const SizedBox(height: 8),
            _dropdownFreidora(appState.freidoras),
            const SizedBox(height: 20),

            // ── 2. Seleccionar producto ───────────────────────────────────
            _labelSeccion('2. SELECCIONAR PRODUCTO'),
            const SizedBox(height: 8),
            _dropdownProducto(appState.productos),
            const SizedBox(height: 20),

            // ── 3. Tiempos ────────────────────────────────────────────────
            _labelSeccion('3. EDITAR EL TIEMPO DE COCCIÓN Y TOSTADO'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _cajaTiempo(
                    label: 'Cocción (min)',
                    controller: _coccionCtrl,
                    fondoColor: const Color(0xFFFCEAEA),
                    textoColor: const Color(0xFFC62828),
                    labelColor: const Color(0xFFB71C1C),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _cajaTiempo(
                    label: 'Tostado (min)',
                    controller: _tostadoCtrl,
                    fondoColor: const Color(0xFFF1F1F1),
                    textoColor: const Color(0xFF212121),
                    labelColor: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // ── Botón añadir ──────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _agregarTemporizador,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC62828),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'AÑADIR TEMPORIZADOR',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Crea y agrega el temporizador al AppState ────────────────────────────
  void _agregarTemporizador() {
    if (_freidoraSeleccionada == null || _productoSeleccionado == null) return;

    // Verificar duplicado: misma freidora + mismo producto
    final appState = context.read<AppState>();
    final duplicado = appState.temporizadores.any((t) =>
        t.producto.id == _productoSeleccionado!.id);

    if (duplicado) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Temporizador duplicado',
            style: TextStyle(
              color: Color(0xFFC62828),
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
          content: Text(
            'Ya existe un temporizador para '
            '"${_productoSeleccionado!.nombre}".\n\n'
            'No se pueden tener dos temporizadores con el mismo producto.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'Entendido',
                style: TextStyle(
                    color: Color(0xFFC62828), fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
      return;
    }

    final int coccionMin = int.tryParse(_coccionCtrl.text) ?? 0;
    final int tostadoMin = int.tryParse(_tostadoCtrl.text) ?? 0;

    appState.agregarTemporizador(
      Temporizador(
        freidora: _freidoraSeleccionada!,
        producto: _productoSeleccionado!,
        tiempoCoccionRestante: coccionMin * 60,
        tiempoTostadoRestante: tostadoMin * 60,
        estado: 'coccion',
        corriendo: false,
      ),
    );

    Navigator.of(context).pop();
  }

  // ── Helpers de UI ─────────────────────────────────────────────────────────
  Widget _labelSeccion(String texto) => Text(
        texto,
        style: const TextStyle(
          color: Color(0xFFC62828),
          fontWeight: FontWeight.bold,
          fontSize: 11,
          letterSpacing: 0.8,
        ),
      );

  Widget _dropdownFreidora(List<Freidora> freidoras) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F1F1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Freidora>(
          value: _freidoraSeleccionada,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFFC62828)),
          items: freidoras
              .map((f) => DropdownMenuItem(
                    value: f,
                    child: Text('${f.codigo} - ${f.estado}'),
                  ))
              .toList(),
          onChanged: (f) => setState(() => _freidoraSeleccionada = f),
          style: const TextStyle(color: Color(0xFF212121), fontSize: 15),
        ),
      ),
    );
  }

  Widget _dropdownProducto(List<Producto> productos) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F1F1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Producto>(
          value: _productoSeleccionado,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFFC62828)),
          items: productos
              .map((p) => DropdownMenuItem(
                    value: p,
                    child: Text(p.nombre),
                  ))
              .toList(),
          onChanged: _onProductoChanged,
          style: const TextStyle(color: Color(0xFF212121), fontSize: 15),
        ),
      ),
    );
  }

  Widget _cajaTiempo({
    required String label,
    required TextEditingController controller,
    required Color fondoColor,
    required Color textoColor,
    required Color labelColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: fondoColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              color: labelColor,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TextStyle(
              color: textoColor,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}
