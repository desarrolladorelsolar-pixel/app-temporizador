import 'package:flutter/material.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // Escala: el logo "aparece" creciendo ligeramente
  late Animation<double> _scaleAnim;

  // Opacidad: fade-in del logo
  late Animation<double> _fadeAnim;

  // Opacidad de salida: fade-out de toda la pantalla antes de navegar
  late Animation<double> _exitFadeAnim;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    // ── Fase 1 (0% → 60%): fade-in + scale del logo ──────────────────────
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
      ),
    );

    _scaleAnim = Tween<double>(begin: 0.65, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.55, curve: Curves.elasticOut),
      ),
    );

    // ── Fase 2 (75% → 100%): fade-out de toda la pantalla ────────────────
    _exitFadeAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.75, 1.0, curve: Curves.easeInOut),
      ),
    );

    // Arranca la animación y navega al terminar
    _controller.forward().then((_) => _navigate());
  }

  void _navigate() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionDuration: Duration.zero, // el fade ya lo hizo la splash
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // Usar directamente FadeTransition + ScaleTransition en vez de
      // AnimatedBuilder (que fuerza rebuild del árbol completo cada frame)
      body: FadeTransition(
        opacity: _exitFadeAnim,
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: ScaleTransition(
                    scale: _scaleAnim,
                    child: Image.asset(
                      'assets/images/logocolor.png',
                      width: 240,
                      // Limita decodificación al tamaño real mostrado
                      cacheWidth: 480, // 240 × 2 para pantallas 2x
                    ),
                  ),
                ),
              ),
            ),
            FadeTransition(
              opacity: _fadeAnim,
              child: const SizedBox(
                height: 8,
                width: double.infinity,
                child: ColoredBox(color: Color(0xFFC62828)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
