import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../models/temporizador.dart';
import '../widgets/app_bar_principal.dart';
import '../widgets/app_drawer.dart';

// ── Pantalla: Gestionar Temporizadores ───────────────────────────────────────
// Lista todos los temporizadores con opción de eliminar.
// NO permite iniciarlos — eso es desde la pantalla principal.
class GestionTemporizadoresScreen extends StatelessWidget {
  const GestionTemporizadoresScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lista = context.watch<AppState>().temporizadores;
    final double anchoPantalla = MediaQuery.of(context).size.width;
    final double pad = anchoPantalla >= 600 ? 32.0 : 16.0;

    return Scaffold(
      appBar: const AppBarPrincipal(pantallaActual: 'gestion_temporizadores'),
      drawer: const AppDrawer(pantallaActual: 'gestion_temporizadores'),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(pad, 16, pad, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'GESTIONAR TEMPORIZADORES',
                    style: TextStyle(
                      color: Color(0xFFC62828),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${lista.length} temporizador${lista.length == 1 ? '' : 'es'} '
                    'registrado${lista.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                        color: Color(0xFF9E9E9E), fontSize: 12),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: lista.isEmpty
                  ? const _EstadoVacioGestion()
                  : ListView.builder(
                      padding: EdgeInsets.symmetric(
                          horizontal: pad, vertical: 12),
                      itemCount: lista.length,
                      itemBuilder: (context, i) => _TemporizadorTile(
                        temporizador: lista[i],
                        index: i,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Estado vacío (widget const reutilizable) ─────────────────────────────────
class _EstadoVacioGestion extends StatelessWidget {
  const _EstadoVacioGestion();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_off_outlined, size: 72, color: Color(0xFFBDBDBD)),
          SizedBox(height: 12),
          Text(
            'No hay temporizadores',
            style: TextStyle(
                color: Color(0xFFBDBDBD),
                fontSize: 16,
                fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 6),
          Text(
            'Creá uno desde la pantalla principal\nusando el botón +.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFFBDBDBD), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ── Tile individual ──────────────────────────────────────────────────────────
class _TemporizadorTile extends StatelessWidget {
  final Temporizador temporizador;
  final int index;

  const _TemporizadorTile({
    required this.temporizador,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final bool corriendo = temporizador.corriendo;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: Color(0xFFFCEAEA),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.timer_outlined,
              color: Color(0xFFC62828), size: 22),
        ),
        title: Text(
          temporizador.producto.nombre,
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Color(0xFF212121)),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              'Freidora: ${temporizador.freidora.codigo}',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            Text(
              'Cocción: ${temporizador.producto.tiempoCoccion} min  ·  '
              'Tostado: ${temporizador.producto.tiempoTostado} min',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
        // Badge si está corriendo
        trailing: corriendo
            ? _badgeCorriendo()
            : IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Color(0xFFC62828), size: 22),
                tooltip: 'Eliminar',
                onPressed: () => _confirmarEliminar(context),
              ),
      ),
    );
  }

  Widget _badgeCorriendo() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'En uso',
          style: TextStyle(
            color: Color(0xFFF57F17),
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      );

  Future<void> _confirmarEliminar(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Eliminar temporizador',
          style: TextStyle(
            color: Color(0xFFC62828),
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        content: Text(
          '¿Eliminar "${temporizador.producto.nombre}" '
          '(${temporizador.freidora.codigo})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancelar',
                style: TextStyle(color: Colors.grey[600])),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Eliminar',
              style: TextStyle(
                  color: Color(0xFFC62828), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmar == true && context.mounted) {
      context.read<AppState>().eliminarTemporizador(index);
    }
  }
}
