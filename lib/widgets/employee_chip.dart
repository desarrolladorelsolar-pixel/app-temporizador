import 'package:flutter/material.dart';
import '../models/empleado.dart';

// ── Chip de empleado optimizado ───────────────────────────────────────────────
// OPTIMIZACIÓN: AnimatedContainer reconstruye todo el árbol hijo en cada frame
// de la animación. Separamos la animación de decoración (AnimatedContainer
// solo para el fondo) del contenido de texto (que no cambia en la animación).
class EmployeeChip extends StatelessWidget {
  final Empleado empleado;
  final bool seleccionado;
  final VoidCallback onTap;

  const EmployeeChip({
    super.key,
    required this.empleado,
    required this.seleccionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color fondoColor =
        seleccionado ? const Color(0xFFC62828) : const Color(0xFFF1F1F1);
    final Color textoColor =
        seleccionado ? Colors.white : const Color(0xFF333333);
    final Color subtextoColor =
        seleccionado ? Colors.white70 : const Color(0xFF9E9E9E);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: fondoColor,
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          boxShadow: seleccionado
              ? const [
                  BoxShadow(
                    color: Color(0x59C62828), // 35% alpha sin withOpacity
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  )
                ]
              : const [],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              empleado.nombre.toUpperCase(),
              style: TextStyle(
                color: textoColor,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              empleado.carnet,
              style: TextStyle(color: subtextoColor, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
