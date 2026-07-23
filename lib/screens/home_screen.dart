import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_bar_principal.dart';
import '../widgets/estado_vacio.dart';
import '../widgets/employee_chip.dart';
import '../widgets/new_timer_modal.dart';
import '../widgets/timer_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final double ancho = mq.size.width;
    final bool esLandscape = mq.orientation == Orientation.landscape;
    final bool esTablet = ancho >= 600;

    // Padding lateral adaptativo
    final double pad = esTablet ? 24.0 : 12.0;

    // Columnas según orientación y tamaño
    // Portrait móvil: 2 | Landscape móvil: 3 | Tablet portrait: 3 | Tablet landscape: 4
    final int columnas = esTablet
        ? (esLandscape ? 4 : 3)
        : (esLandscape ? 3 : 2);

    // Aspect ratio según orientación
    // En landscape las cards son más anchas → necesitan menos altura relativa
    final double aspectRatio = esTablet
        ? (esLandscape ? 1.0 : 0.85)
        : (esLandscape ? 1.1 : 0.82);

    return Scaffold(
      appBar: AppBarPrincipal(
        pantallaActual: 'temporizadores',
        onAgregarPressed: () => mostrarNuevoTemporizador(context),
        tooltipAgregar: 'Nuevo Temporizador',
      ),
      drawer: const AppDrawer(pantallaActual: 'temporizadores'),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Personal en turno ─────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(pad, 12, pad, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _TituloSeccion(texto: 'PERSONAL EN TURNO'),
                  const SizedBox(height: 8),
                  _ChipsEmpleados(pad: pad),
                  SizedBox(height: esLandscape ? 8 : 14),
                  const _TituloSeccion(texto: 'TEMPORIZADORES'),
                  const SizedBox(height: 4),
                ],
              ),
            ),

            // ── Grid temporizadores ───────────────────────────────────────
            Expanded(
              child: _GridTemporizadores(
                pad: pad,
                columnas: columnas,
                aspectRatio: aspectRatio,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Chips de empleados ────────────────────────────────────────────────────────
class _ChipsEmpleados extends StatefulWidget {
  final double pad;
  const _ChipsEmpleados({required this.pad});

  @override
  State<_ChipsEmpleados> createState() => _ChipsEmpleadosState();
}

class _ChipsEmpleadosState extends State<_ChipsEmpleados> {
  int _seleccionado = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appState = context.read<AppState>();
    if (appState.empleadoActivo != null && appState.empleados.isNotEmpty) {
      final idx = appState.empleados
          .indexWhere((e) => e.id == appState.empleadoActivo!.id);
      if (idx >= 0) _seleccionado = idx;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final empleados = appState.empleados;

    if (empleados.isEmpty) {
      return Text('Sin empleados registrados',
          style: TextStyle(color: Colors.grey[400], fontSize: 13));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(
          empleados.length,
          (i) => EmployeeChip(
            empleado: empleados[i],
            seleccionado: _seleccionado == i,
            onTap: () {
              setState(() => _seleccionado = i);
              context.read<AppState>().seleccionarEmpleado(empleados[i]);
            },
          ),
        ),
      ),
    );
  }
}

// ── Grid temporizadores ───────────────────────────────────────────────────────
class _GridTemporizadores extends StatelessWidget {
  final double pad;
  final int columnas;
  final double aspectRatio;

  const _GridTemporizadores({
    required this.pad,
    required this.columnas,
    required this.aspectRatio,
  });

  @override
  Widget build(BuildContext context) {
    final temporizadores = context.watch<AppState>().temporizadores;

    if (temporizadores.isEmpty) return const EstadoVacio();

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(pad, 8, pad, 20),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columnas,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: aspectRatio,
      ),
      itemCount: temporizadores.length,
      itemBuilder: (context, i) => TimerCard(
        temporizador: temporizadores[i],
        index: i,
      ),
    );
  }
}

// ── Título de sección ─────────────────────────────────────────────────────────
class _TituloSeccion extends StatelessWidget {
  final String texto;
  const _TituloSeccion({required this.texto});

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: const TextStyle(
        color: Color(0xFFC62828),
        fontWeight: FontWeight.bold,
        fontSize: 13,
        letterSpacing: 1.2,
      ),
    );
  }
}
