import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/empleados_screen.dart';
import '../screens/freidoras_screen.dart';
import '../screens/gestion_temporizadores_screen.dart';
import '../screens/logs_screen.dart';
import '../screens/productos_screen.dart';

// ── Drawer lateral compartido entre todas las pantallas ──────────────────────
// [pantallaActual] indica cuál ítem resaltar:
//   'temporizadores' | 'empleados' | 'productos' | 'freidoras'
class AppDrawer extends StatelessWidget {
  final String pantallaActual;

  const AppDrawer({
    super.key,
    this.pantallaActual = 'temporizadores',
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Respeta la barra de estado (hora, batería, etc.)
          SizedBox(height: MediaQuery.of(context).padding.top),

          // ── Header ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'MENÚ',
                  style: TextStyle(
                    color: Color(0xFFC62828),
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    letterSpacing: 1.5,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black54),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),
          const SizedBox(height: 8),

          // ── Opciones ─────────────────────────────────────────────────

          // 1. Temporizadores
          _DrawerItem(
            icono: Icons.timer_outlined,
            texto: 'Temporizadores',
            activo: pantallaActual == 'temporizadores',
            onTap: () {
              Navigator.of(context).pop();
              if (pantallaActual != 'temporizadores') {
                Navigator.of(context).pushAndRemoveUntil(
                  _rutaSinAnimacion(const HomeScreen()),
                  (route) => false,
                );
              }
            },
          ),

          // 1b. Gestionar Temporizadores
          _DrawerItem(
            icono: Icons.tune,
            texto: 'Gestionar Temporizadores',
            activo: pantallaActual == 'gestion_temporizadores',
            indent: true, // ítem secundario sangrado
            onTap: () {
              Navigator.of(context).pop();
              if (pantallaActual != 'gestion_temporizadores') {
                Navigator.of(context).pushAndRemoveUntil(
                  _rutaSinAnimacion(const GestionTemporizadoresScreen()),
                  (route) => false,
                );
              }
            },
          ),

          // 2. Empleados
          _DrawerItem(
            icono: Icons.people_outline,
            texto: 'Empleados',
            activo: pantallaActual == 'empleados',
            onTap: () {
              Navigator.of(context).pop();
              if (pantallaActual != 'empleados') {
                Navigator.of(context).pushAndRemoveUntil(
                  _rutaSinAnimacion(const EmpleadosScreen()),
                  (route) => false,
                );
              }
            },
          ),

          // 3. Productos
          _DrawerItem(
            icono: Icons.fastfood,
            texto: 'Productos',
            activo: pantallaActual == 'productos',
            onTap: () {
              Navigator.of(context).pop();
              if (pantallaActual != 'productos') {
                Navigator.of(context).pushAndRemoveUntil(
                  _rutaSinAnimacion(const ProductosScreen()),
                  (route) => false,
                );
              }
            },
          ),

          // 4. Freidoras
          _DrawerItem(
            icono: Icons.donut_large,
            texto: 'Freidoras',
            activo: pantallaActual == 'freidoras',
            onTap: () {
              Navigator.of(context).pop();
              if (pantallaActual != 'freidoras') {
                Navigator.of(context).pushAndRemoveUntil(
                  _rutaSinAnimacion(const FreidorasScreen()),
                  (route) => false,
                );
              }
            },
          ),

          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Divider(height: 1),
          ),
          const SizedBox(height: 8),

          // 5. Historial / Logs
          _DrawerItem(
            icono: Icons.history,
            texto: 'Historial',
            activo: pantallaActual == 'logs',
            badge: 'PDF',
            onTap: () {
              Navigator.of(context).pop();
              if (pantallaActual != 'logs') {
                Navigator.of(context).pushAndRemoveUntil(
                  _rutaSinAnimacion(const LogsScreen()),
                  (route) => false,
                );
              }
            },
          ),

          const Spacer(),

          // ── Footer ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(left: 20, bottom: 20),
            child: Text(
              'SUCURSAL CAÑOTO  V1.0',
              style: const TextStyle(
                color: Color(0xFF9E9E9E),
                fontSize: 11,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Ruta sin animación de transición ────────────────────────────────────────
PageRouteBuilder _rutaSinAnimacion(Widget pantalla) => PageRouteBuilder(
      pageBuilder: (_, __, ___) => pantalla,
      // Duración cero = cambio instantáneo, sin slide ni fade
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      transitionsBuilder: (_, __, ___, child) => child,
    );

// ── Ítem individual del drawer ───────────────────────────────────────────────
class _DrawerItem extends StatelessWidget {
  final IconData icono;
  final String texto;
  final bool activo;
  final VoidCallback onTap;
  final String? badge;
  final bool indent;

  const _DrawerItem({
    required this.icono,
    required this.texto,
    required this.activo,
    required this.onTap,
    this.badge,
    this.indent = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color color =
        activo ? const Color(0xFFC62828) : const Color(0xFF424242);
    final Color? fondo = activo ? const Color(0xFFFCEAEA) : null;

    return Container(
      margin: EdgeInsets.only(
        left: indent ? 26 : 10,
        right: 10,
        top: 1,
        bottom: 1,
      ),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        dense: indent,
        leading: Icon(icono,
            // withOpacity crea objeto nuevo cada build — usar alpha literal
            color: indent ? const Color(0xBFC62828) : color,
            size: indent ? 18 : 22),
        title: Row(
          children: [
            Text(
              texto,
              style: TextStyle(
                // 0xD9 = 85% alpha, 0xFF = 100%
                color: indent ? const Color(0xD9424242) : color,
                fontWeight: activo ? FontWeight.w600 : FontWeight.normal,
                fontSize: indent ? 13 : 15,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFC62828),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ],
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
