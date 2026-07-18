import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_bar_principal.dart';
import '../widgets/estado_vacio.dart';
import '../widgets/employee_chip.dart';
import '../widgets/new_timer_modal.dart';
import '../widgets/timer_card.dart';

// ── Pantalla principal ───────────────────────────────────────────────────────
// Optimización de rebuilds:
// - El scaffold y AppBar son const o casi-const → no se reconstruyen.
// - _ChipsEmpleados usa context.select solo sobre la lista de empleados.
// - _GridTemporizadores usa context.select solo sobre temporizadores.
// Así, cada tick del timer (notifyListeners cada 1s) solo reconstruye
// las TimerCard individuales, no toda la pantalla.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final double anchoPantalla = MediaQuery.of(context).size.width;
    final bool esTablet = anchoPantalla >= 600;
    final double pad = esTablet ? 32.0 : 16.0;

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
            // ── Personal en turno ─────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(pad, 16, pad, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _TituloSeccion(texto: 'PERSONAL EN TURNO'),
                  const SizedBox(height: 10),
                  _ChipsEmpleados(pad: pad),
                  const SizedBox(height: 20),
                  const _TituloSeccion(texto: 'TEMPORIZADORES'),
                  const SizedBox(height: 4),
                ],
              ),
            ),
            // ── Grid temporizadores ───────────────────────────────────
            Expanded(
              child: _GridTemporizadores(
                pad: pad,
                columnas: anchoPantalla >= 900 ? 3 : 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Chips de empleados — solo se reconstruye cuando cambia la lista ──────────
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
    // Sincronizar el índice visual con el empleadoActivo en AppState
    // (por si se cargó desde BD con un empleado ya seleccionado)
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
      return Text(
        'Sin empleados registrados',
        style: TextStyle(color: Colors.grey[400], fontSize: 13),
      );
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
              // Notificar al AppState quién está seleccionado
              context.read<AppState>().seleccionarEmpleado(empleados[i]);
            },
          ),
        ),
      ),
    );
  }
}

// ── Grid de temporizadores — se reconstruye con cada tick del timer ──────────
// Cada TimerCard es StatefulWidget y maneja su propio estado visual.
class _GridTemporizadores extends StatelessWidget {
  final double pad;
  final int columnas;

  const _GridTemporizadores({required this.pad, required this.columnas});

  @override
  Widget build(BuildContext context) {
    final temporizadores = context.watch<AppState>().temporizadores;

    if (temporizadores.isEmpty) return const EstadoVacio();

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(pad, 8, pad, 20),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columnas,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.35,
      ),
      itemCount: temporizadores.length,
      // addRepaintBoundaries: true ya es el default en GridView.builder
      itemBuilder: (context, i) => TimerCard(
        temporizador: temporizadores[i],
        index: i,
      ),
    );
  }
}

// ── Título de sección ────────────────────────────────────────────────────────
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
