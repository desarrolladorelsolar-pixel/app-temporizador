import 'package:flutter/material.dart';

// ── AppBar con logo + franja roja tipo banner ────────────────────────────────
class AppBarPrincipal extends StatelessWidget implements PreferredSizeWidget {
  final String pantallaActual;
  final VoidCallback? onAgregarPressed;
  final String tooltipAgregar;

  static const double _barraAltura = kToolbarHeight;
  static const double _franjaAltura = 4.0;

  // Decoración const reutilizable — no se recrea en cada build
  static const BoxDecoration _decoBtnAgregar = BoxDecoration(
    color: Color(0xFFC62828),
    shape: BoxShape.circle,
  );

  const AppBarPrincipal({
    super.key,
    required this.pantallaActual,
    this.onAgregarPressed,
    this.tooltipAgregar = 'Agregar',
  });

  @override
  Size get preferredSize =>
      const Size.fromHeight(_barraAltura + _franjaAltura);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: _barraAltura,
          child: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            automaticallyImplyLeading: false,
            leading: Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu, color: Color(0xFFC62828)),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
                tooltip: 'Menú',
              ),
            ),
            title: Image.asset(
              'assets/images/logocolor.png',
              height: 38,
              fit: BoxFit.contain,
              // Limita decodificación al tamaño visible × densidad
              cacheHeight: 76, // 38 × 2 para pantallas 2x
            ),
            centerTitle: true,
            actions: onAgregarPressed != null
                ? [
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: _decoBtnAgregar,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.add,
                              color: Colors.white, size: 22),
                          onPressed: onAgregarPressed,
                          tooltip: tooltipAgregar,
                        ),
                      ),
                    ),
                  ]
                : null,
          ),
        ),
        // Franja roja — SizedBox + ColoredBox es más liviano que Container
        const SizedBox(
          height: _franjaAltura,
          width: double.infinity,
          child: ColoredBox(color: Color(0xFFC62828)),
        ),
      ],
    );
  }
}
