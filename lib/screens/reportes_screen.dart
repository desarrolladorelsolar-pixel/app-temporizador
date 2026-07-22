import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/freidora.dart';
import '../state/app_state.dart';
import '../widgets/app_bar_principal.dart';
import '../widgets/app_drawer.dart';
import 'reporte_freidora_screen.dart';

/// Pantalla de Reportes — acceso protegido con contraseña.
/// Una vez autenticado muestra el dashboard de freidoras.
class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  bool _autenticado = false;
  final _pwdCtrl = TextEditingController();
  bool _errorPwd = false;
  bool _ocultarPwd = true;

  // Contraseña fija — distribución interna, no requiere hash
  static const String _kPassword = 'pollosolarsito';

  @override
  void dispose() {
    _pwdCtrl.dispose();
    super.dispose();
  }

  void _validarPassword() {
    if (_pwdCtrl.text.trim() == _kPassword) {
      context.read<AppState>().recargarLogs();
      setState(() {
        _autenticado = true;
        _errorPwd = false;
      });
    } else {
      setState(() => _errorPwd = true);
      _pwdCtrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarPrincipal(pantallaActual: 'reportes'),
      drawer: const AppDrawer(pantallaActual: 'reportes'),
      body: SafeArea(
        child: _autenticado ? _buildDashboard() : _buildLogin(),
      ),
    );
  }

  // ── Pantalla de login ──────────────────────────────────────────────────────
  Widget _buildLogin() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bar_chart_rounded,
                size: 72, color: Color(0xFFC62828)),
            const SizedBox(height: 16),
            const Text(
              'REPORTES',
              style: TextStyle(
                color: Color(0xFFC62828),
                fontWeight: FontWeight.bold,
                fontSize: 22,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ingresá la contraseña para acceder',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
            const SizedBox(height: 32),

            // Campo de contraseña
            TextField(
              controller: _pwdCtrl,
              obscureText: _ocultarPwd,
              onSubmitted: (_) => _validarPassword(),
              decoration: InputDecoration(
                hintText: 'Contraseña',
                filled: true,
                fillColor: const Color(0xFFF1F1F1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                errorText: _errorPwd ? 'Contraseña incorrecta' : null,
                suffixIcon: IconButton(
                  icon: Icon(
                    _ocultarPwd ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: Colors.grey[500],
                  ),
                  onPressed: () => setState(() => _ocultarPwd = !_ocultarPwd),
                ),
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _validarPassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC62828),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'ACCEDER',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      letterSpacing: 1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Dashboard de freidoras ─────────────────────────────────────────────────
  Widget _buildDashboard() {
    final freidoras = context.watch<AppState>().freidoras;
    final double pad = MediaQuery.of(context).size.width >= 600 ? 32.0 : 16.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header con botón cerrar sesión
        Padding(
          padding: EdgeInsets.fromLTRB(pad, 16, pad, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'REPORTES POR FREIDORA',
                style: TextStyle(
                  color: Color(0xFFC62828),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 1.2,
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(() {
                  _autenticado = false;
                  _pwdCtrl.clear();
                }),
                icon: const Icon(Icons.logout, size: 16, color: Color(0xFF9E9E9E)),
                label: const Text('Salir',
                    style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 12)),
              ),
            ],
          ),
        ),
        const Divider(height: 16),

        // Lista de freidoras
        Expanded(
          child: freidoras.isEmpty
              ? Center(
                  child: Text(
                    'No hay freidoras registradas',
                    style: TextStyle(color: Colors.grey[400], fontSize: 15),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: pad, vertical: 8),
                  itemCount: freidoras.length,
                  itemBuilder: (ctx, i) =>
                      _TarjetaFreidoraReporte(freidora: freidoras[i]),
                ),
        ),
      ],
    );
  }
}

// ── Tarjeta de freidora en el dashboard ──────────────────────────────────────
class _TarjetaFreidoraReporte extends StatelessWidget {
  final Freidora freidora;
  const _TarjetaFreidoraReporte({required this.freidora});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: const SizedBox(
          width: 44,
          height: 44,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xFFFCEAEA),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.donut_large, color: Color(0xFFC62828), size: 24),
          ),
        ),
        title: Text(
          freidora.codigo,
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Color(0xFF212121)),
        ),
        subtitle: Text(
          freidora.descripcion.isEmpty ? 'Sin descripción' : freidora.descripcion,
          style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 13),
        ),
        trailing: const Icon(Icons.chevron_right, color: Color(0xFFC62828)),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ReporteFreidoraScreen(freidora: freidora),
        )),
      ),
    );
  }
}
