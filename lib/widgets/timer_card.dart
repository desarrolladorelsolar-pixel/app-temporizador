import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/temporizador.dart';
import '../state/app_state.dart';

class TimerCard extends StatefulWidget {
  final Temporizador temporizador;
  final int index;

  const TimerCard({
    super.key,
    required this.temporizador,
    required this.index,
  });

  @override
  State<TimerCard> createState() => _TimerCardState();
}

class _TimerCardState extends State<TimerCard> {

  // Doble tap en el botón central — comportamiento según estado
  void _onDoubleTap() {
    final t = widget.temporizador;
    if (t.corriendo) return;
    final appState = context.read<AppState>();

    switch (t.estado) {
      case 'pausado':
        appState.reanudarTemporizador(widget.index);
      case 'listo_repaso':
        appState.iniciarRepaso(widget.index);
      case 'esperando_tostado':
      case 'coccion':
        appState.toggleTemporizador(widget.index);
    }
  }

  // Botón ↺ — pide boquilla y pone en modo 'listo_repaso'
  Future<void> _onRepasoTap() async {
    final t = widget.temporizador;
    if (t.producto.tiempoRepaso <= 0) return;
    if (t.corriendo) return; // no interrumpir ciclo activo

    // Si ya está en listo_repaso, cancelar
    if (t.estado == 'listo_repaso') {
      context.read<AppState>().cancelarRepaso(widget.index);
      return;
    }

    final boquilla = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿En qué boquilla?',
            style: TextStyle(
                color: Color(0xFF2E7D32),
                fontWeight: FontWeight.bold,
                fontSize: 17)),
        content: Text(
          '${t.producto.nombre}\n'
          'Repaso: ${t.producto.tiempoRepaso} min',
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          _BotonBoquilla(numero: 1, subtitulo: 'Cocción',
              onTap: () => Navigator.of(ctx).pop(1)),
          _BotonBoquilla(numero: 2, subtitulo: 'Tostado',
              onTap: () => Navigator.of(ctx).pop(2)),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancelar',
                style: TextStyle(color: Colors.grey[600])),
          ),
        ],
      ),
    );

    if (boquilla != null && mounted) {
      context.read<AppState>().prepararRepaso(widget.index, boquilla);
    }
  }

  // Botón pausa
  Future<void> _onPausaTap() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Pausar temporizador',
            style: TextStyle(
                color: Color(0xFFC62828),
                fontWeight: FontWeight.bold,
                fontSize: 17)),
        content: Text('¿Pausar "${widget.temporizador.producto.nombre}"?\n'
            'El tiempo restante se conserva.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancelar',
                style: TextStyle(color: Colors.grey[600])),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Pausar',
                style: TextStyle(
                    color: Color(0xFFC62828),
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmar == true && mounted) {
      context.read<AppState>().pausarTemporizador(widget.index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.temporizador;
    final bool corriendo     = t.corriendo;
    final bool esRepaso      = t.estado == 'repaso';
    final bool listoRepaso   = t.estado == 'listo_repaso';
    final bool enTostado     = t.estado == 'tostado';
    final bool esperaTostado = t.estado == 'esperando_tostado';
    final bool pausado       = t.estado == 'pausado';

    // Color según fase
    final Color colorFase = esRepaso || listoRepaso
        ? const Color(0xFF2E7D32)   // verde para repaso
        : (enTostado || esperaTostado ||
               (pausado && t.estadoAntesDePausa == 'tostado'))
            ? const Color(0xFFE65100) // naranja tostado
            : const Color(0xFFC62828); // rojo cocción

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // ── Header ───────────────────────────────────────────────────
            _Header(
              temporizador: t,
              colorFase: colorFase,
              corriendo: corriendo,
              listoRepaso: listoRepaso,
              onPausaTap: _onPausaTap,
              onRepasoTap: _onRepasoTap,
            ),

            const SizedBox(height: 6),

            // ── Zona central ──────────────────────────────────────────────
            Expanded(
              child: Center(
                child: RepaintBoundary(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: esRepaso
                        ? _CirculoProgreso(
                            key: const ValueKey('circulo_repaso'),
                            segundosRestantes: t.tiempoRepasoRestante,
                            segundosTotales: t.producto.tiempoRepaso * 60,
                            colorFase: colorFase,
                            etiqueta: 'REPASO B${t.boquillaRepaso}',
                          )
                        : corriendo
                            ? _CirculoProgresoFase(
                                key: ValueKey('circulo_${t.estado}'),
                                temporizador: t,
                                colorFase: colorFase,
                                enCoccion: t.estado == 'coccion',
                              )
                            : esperaTostado
                                ? _BotonEsperaTostado(
                                    key: const ValueKey('espera_tostado'),
                                    onDoubleTap: _onDoubleTap,
                                  )
                                : listoRepaso
                                    ? _BotonListoRepaso(
                                        key: const ValueKey('listo_repaso'),
                                        onDoubleTap: _onDoubleTap,
                                        boquilla: t.boquillaRepaso,
                                        minutos: t.producto.tiempoRepaso,
                                      )
                                    : pausado
                                        ? _BotonPausado(
                                            key: const ValueKey('pausado'),
                                            colorFase: colorFase,
                                            onDoubleTap: _onDoubleTap,
                                            estadoAntes: t.estadoAntesDePausa ?? 'coccion',
                                          )
                                        : _BotonPlay(
                                            key: const ValueKey('play'),
                                            colorFase: colorFase,
                                            onDoubleTap: _onDoubleTap,
                                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final Temporizador temporizador;
  final Color colorFase;
  final bool corriendo;
  final bool listoRepaso;
  final VoidCallback onPausaTap;
  final VoidCallback onRepasoTap;

  const _Header({
    required this.temporizador,
    required this.colorFase,
    required this.corriendo,
    required this.listoRepaso,
    required this.onPausaTap,
    required this.onRepasoTap,
  });

  @override
  Widget build(BuildContext context) {
    final tieneRepaso = temporizador.producto.tiempoRepaso > 0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ↺ botón repaso — izquierda, siempre visible si tiene repaso
        GestureDetector(
          onTap: tieneRepaso && !corriendo ? onRepasoTap : null,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: listoRepaso
                  ? const Color(0xFF2E7D32).withOpacity(0.15)
                  : tieneRepaso
                      ? const Color(0xFFF9A825).withOpacity(0.12)
                      : Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              listoRepaso ? Icons.close : Icons.replay_rounded,
              size: 18,
              color: listoRepaso
                  ? const Color(0xFF2E7D32)
                  : tieneRepaso
                      ? const Color(0xFFF9A825)
                      : Colors.grey[350],
            ),
          ),
        ),
        const SizedBox(width: 4),

        // Nombre y freidora
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                temporizador.producto.nombre,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: colorFase,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                temporizador.freidora.codigo,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[500],
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 4),

        // ⏸ botón pausa — derecha, solo mientras corre (no durante repaso en countdown)
        if (corriendo && temporizador.estado != 'repaso')
          GestureDetector(
            onTap: onPausaTap,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey[100], shape: BoxShape.circle),
              child: Icon(Icons.pause_rounded, size: 18,
                  color: Colors.grey[500]),
            ),
          )
        else
          const SizedBox(width: 26),
      ],
    );
  }
}

// ── Botón de selección de boquilla ────────────────────────────────────────────
class _BotonBoquilla extends StatelessWidget {
  final int numero;
  final String subtitulo;
  final VoidCallback onTap;
  const _BotonBoquilla(
      {required this.numero, required this.subtitulo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2E7D32), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('B$numero',
                style: const TextStyle(
                    color: Color(0xFF2E7D32),
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
            Text(subtitulo,
                style: const TextStyle(
                    color: Color(0xFF2E7D32), fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ── Botón verde "Listo para Repasar" — doble tap para iniciar ─────────────────
class _BotonListoRepaso extends StatefulWidget {
  final VoidCallback onDoubleTap;
  final int boquilla;
  final int minutos;
  const _BotonListoRepaso(
      {super.key,
      required this.onDoubleTap,
      required this.boquilla,
      required this.minutos});

  @override
  State<_BotonListoRepaso> createState() => _BotonListoRepasoState();
}

class _BotonListoRepasoState extends State<_BotonListoRepaso>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulso;
  late Animation<double> _escala;

  @override
  void initState() {
    super.initState();
    _pulso = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _escala = Tween(begin: 0.93, end: 1.05)
        .animate(CurvedAnimation(parent: _pulso, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color verde = Color(0xFF2E7D32);
    return GestureDetector(
      onDoubleTap: widget.onDoubleTap,
      child: ScaleTransition(
        scale: _escala,
        child: Container(
          width: 130, height: 130,
          decoration: const BoxDecoration(
            color: verde,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0x552E7D32),
                blurRadius: 24,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.play_arrow_rounded,
                  color: Colors.white, size: 60),
              Text(
                'REPASO B${widget.boquilla}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                '${widget.minutos} min',
                style: const TextStyle(
                    color: Colors.white70, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Círculo de progreso genérico (para repaso) ────────────────────────────────
class _CirculoProgreso extends StatelessWidget {
  final int segundosRestantes;
  final int segundosTotales;
  final Color colorFase;
  final String etiqueta;

  const _CirculoProgreso({
    super.key,
    required this.segundosRestantes,
    required this.segundosTotales,
    required this.colorFase,
    required this.etiqueta,
  });

  @override
  Widget build(BuildContext context) {
    final double progreso = segundosTotales > 0
        ? (segundosTotales - segundosRestantes) / segundosTotales
        : 1.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 130, height: 130,
          child: Stack(alignment: Alignment.center, children: [
            SizedBox(
              width: 130, height: 130,
              child: CircularProgressIndicator(
                value: 1.0, strokeWidth: 8,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[200]!),
              ),
            ),
            SizedBox(
              width: 130, height: 130,
              child: CircularProgressIndicator(
                value: progreso, strokeWidth: 8,
                valueColor: AlwaysStoppedAnimation<Color>(colorFase),
              ),
            ),
            Text(_fmt(segundosRestantes),
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: colorFase)),
          ]),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: colorFase.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(etiqueta,
              style: TextStyle(
                  color: colorFase,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  letterSpacing: 0.8)),
        ),
      ],
    );
  }

  String _fmt(int s) {
    final m = s ~/ 60;
    final ss = s % 60;
    return '${m.toString().padLeft(2, '0')}:${ss.toString().padLeft(2, '0')}';
  }
}

// ── Círculo para cocción/tostado ──────────────────────────────────────────────
class _CirculoProgresoFase extends StatelessWidget {
  final Temporizador temporizador;
  final Color colorFase;
  final bool enCoccion;

  const _CirculoProgresoFase({
    super.key,
    required this.temporizador,
    required this.colorFase,
    required this.enCoccion,
  });

  @override
  Widget build(BuildContext context) {
    final int seg = enCoccion
        ? temporizador.tiempoCoccionRestante
        : temporizador.tiempoTostadoRestante;
    final int total = enCoccion
        ? temporizador.producto.tiempoCoccion * 60
        : temporizador.producto.tiempoTostado * 60;

    return _CirculoProgreso(
      segundosRestantes: seg,
      segundosTotales: total,
      colorFase: colorFase,
      etiqueta: enCoccion ? 'COCCIÓN' : 'TOSTADO',
    );
  }
}

// ── Botón Play ────────────────────────────────────────────────────────────────
class _BotonPlay extends StatelessWidget {
  final Color colorFase;
  final VoidCallback onDoubleTap;
  const _BotonPlay({super.key, required this.colorFase, required this.onDoubleTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: onDoubleTap,
      child: Container(
        width: 130, height: 130,
        decoration: BoxDecoration(
          color: colorFase,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: colorFase.withOpacity(0.4),
                blurRadius: 20, offset: const Offset(0, 6)),
          ],
        ),
        child: const Icon(Icons.play_arrow_rounded,
            color: Colors.white, size: 80),
      ),
    );
  }
}

// ── Botón Pausado ─────────────────────────────────────────────────────────────
class _BotonPausado extends StatelessWidget {
  final Color colorFase;
  final VoidCallback onDoubleTap;
  final String estadoAntes;
  const _BotonPausado(
      {super.key, required this.colorFase, required this.onDoubleTap,
      required this.estadoAntes});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: onDoubleTap,
      child: Container(
        width: 130, height: 130,
        decoration: BoxDecoration(
          color: Colors.grey[200], shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08),
              blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_arrow_rounded, color: colorFase, size: 60),
            Text(estadoAntes.toUpperCase(),
                style: TextStyle(color: colorFase,
                    fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
          ],
        ),
      ),
    );
  }
}

// ── Botón Espera Tostado ──────────────────────────────────────────────────────
class _BotonEsperaTostado extends StatefulWidget {
  final VoidCallback onDoubleTap;
  const _BotonEsperaTostado({super.key, required this.onDoubleTap});

  @override
  State<_BotonEsperaTostado> createState() => _BotonEsperaTostadoState();
}

class _BotonEsperaTostadoState extends State<_BotonEsperaTostado>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulso;
  late Animation<double> _escala;

  @override
  void initState() {
    super.initState();
    _pulso = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 700))..repeat(reverse: true);
    _escala = Tween(begin: 0.93, end: 1.05).animate(
        CurvedAnimation(parent: _pulso, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _pulso.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    const Color naranja = Color(0xFFE65100);
    return GestureDetector(
      onDoubleTap: widget.onDoubleTap,
      child: ScaleTransition(
        scale: _escala,
        child: Container(
          width: 130, height: 130,
          decoration: const BoxDecoration(color: naranja, shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Color(0x66E65100),
                blurRadius: 24, offset: Offset(0, 6))]),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.play_arrow_rounded, color: Colors.white, size: 60),
              Text('TOSTADO', style: TextStyle(color: Colors.white,
                  fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ],
          ),
        ),
      ),
    );
  }
}
