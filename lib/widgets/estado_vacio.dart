import 'package:flutter/material.dart';

// ── Widget reutilizable: estado vacío ────────────────────────────────────────
// OPTIMIZACIÓN: evita Opacity() widget (crea offscreen layer en GPU débil).
// En su lugar usa color con alpha directamente en el Image (no es posible),
// así que aplicamos el color al ColorFilter que es rasterizado en CPU,
// sin costo de composición extra.
class EstadoVacio extends StatelessWidget {
  const EstadoVacio({super.key});

  @override
  Widget build(BuildContext context) {
    final double ancho = MediaQuery.of(context).size.width;
    final double anchoLogo = ancho >= 600 ? 320.0 : 250.0;

    return Center(
      child: ColorFiltered(
        // Equivalente visual a Opacity(opacity: 0.15) pero sin offscreen layer
        colorFilter: ColorFilter.mode(
          Colors.white.withOpacity(0.85),
          BlendMode.srcOver,
        ),
        child: Image.asset(
          'assets/images/logito.png',
          width: anchoLogo,
          // logito.png es 400×400px — no decodificar más grande que el tamaño visible
          cacheWidth: anchoLogo.toInt(),
          errorBuilder: (_, __, ___) => Icon(
            Icons.storefront,
            size: anchoLogo * 0.6,
            color: const Color(0x26C62828), // rojo con 15% alpha
          ),
        ),
      ),
    );
  }
}
