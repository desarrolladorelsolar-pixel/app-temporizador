import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/temporizador.dart';
import '../state/app_state.dart';

// ── Card de temporizador ─────────────────────────────────────────────────────
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
  void _onDoubleTap() {
    final t = widget.temporizador;
    if (t.corriendo) return;
    if (t.estado == 'pausado') {
      context.read<AppState>().reanudarTemporizador(widget.index);
    } else {
      context.read<AppState>().toggleTemporizador(widget.index);
    }
  }

  Future<void> _onPausaTap() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Pausar temporizador',
          style: TextStyle(
              color: Color(0xFFC62828),
              fontWeight: FontWeight.bold,
              fontSize: 17),
        ),
        content: Text(
          '¿Pausar "${widget.temporizador.producto.nombre}"?\n'
          'El tiempo restante se conserva.',
        ),
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
    final bool enTostado     = t.estado == 'tostado';
    final bool esperaTostado = t.estado == 'esperando_tostado';
    final bool pausado       = t.estado == 'pausado';
    final bool corriendo     = t.corriendo;

    final Color colorFase = (enTostado || esperaTostado ||
            (pausado && t.estadoAntesDePausa == 'tostado'))
        ? const Color(0xFFE65100)
        : const Color(0xFFC62828);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // ── Header + botón pausa ──────────────────────────────────────
            _Header(
              temporizador: t,
              colorFase: colorFase,
              corriendo: corriendo,
              onPausaTap: _onPausaTap,
            ),
            const SizedBox(height: 8),
            // ── Zona central ──────────────────────────────────────────────
            Expanded(
              child: Center(
                // RepaintBoundary aísla el círculo/botón del resto de la card.
                // Cuando el timer hace tick, solo se repinta esta zona,
                // no el header ni la card entera. Crucial en gama baja.
                child: RepaintBoundary(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: corriendo
                        ? _CirculoProgreso(
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
                            : pausado
                                ? _BotonPausado(
                                    key: const ValueKey('pausado'),
                                    colorFase: colorFase,
                                    onDoubleTap: _onDoubleTap,
                                    estadoAntes:
                                        t.estadoAntesDePausa ?? 'coccion',
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

// ── Header con botón pausa ────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final Temporizador temporizador;
  final Color colorFase;
  final bool corriendo;
  final VoidCallback onPausaTap;

  const _Header({
    required this.temporizador,
    required this.colorFase,
    required this.corriendo,
    required this.onPausaTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: colorFase,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                temporizador.freidora.codigo,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[500],
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        // Botón pausa — solo visible mientras corre
        if (corriendo)
          GestureDetector(
            onTap: onPausaTap,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.pause_rounded,
                size: 20,
                color: Colors.grey[500],
              ),
            ),
          ),
      ],
    );
  }
}

// ── Botón Play (cocción) ──────────────────────────────────────────────────────
class _BotonPlay extends StatelessWidget {
  final Color colorFase;
  final VoidCallback onDoubleTap;

  const _BotonPlay({
    super.key,
    required this.colorFase,
    required this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: onDoubleTap,
      child: Container(
        width: 130,
        height: 130,
        decoration: BoxDecoration(
          color: colorFase,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: colorFase.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(
          Icons.play_arrow_rounded,
          color: Colors.white,
          size: 80,
        ),
      ),
    );
  }
}

// ── Botón Pausado (doble tap para reanudar) ───────────────────────────────────
class _BotonPausado extends StatelessWidget {
  final Color colorFase;
  final VoidCallback onDoubleTap;
  final String estadoAntes;

  const _BotonPausado({
    super.key,
    required this.colorFase,
    required this.onDoubleTap,
    required this.estadoAntes,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: onDoubleTap,
      child: Container(
        width: 130,
        height: 130,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_arrow_rounded, color: colorFase, size: 60),
            const SizedBox(height: 2),
            Text(
              estadoAntes.toUpperCase(),
              style: TextStyle(
                color: colorFase,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Botón pulsante "Iniciar tostado" ──────────────────────────────────────────
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
    _pulso = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _escala = Tween(begin: 0.93, end: 1.05).animate(
      CurvedAnimation(parent: _pulso, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color naranja = Color(0xFFE65100);
    return GestureDetector(
      onDoubleTap: widget.onDoubleTap,
      child: ScaleTransition(
        scale: _escala,
        child: Container(
          width: 130,
          height: 130,
          decoration: const BoxDecoration(
            color: naranja,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0x66E65100),
                blurRadius: 24,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.play_arrow_rounded, color: Colors.white, size: 60),
              SizedBox(height: 2),
              Text(
                'TOSTADO',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Círculo de progreso ───────────────────────────────────────────────────────
class _CirculoProgreso extends StatelessWidget {
  final Temporizador temporizador;
  final Color colorFase;
  final bool enCoccion;

  const _CirculoProgreso({
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

    final double progreso = total > 0 ? (total - seg) / total : 1.0;
    final String etiqueta = enCoccion ? 'COCCIÓN' : 'TOSTADO';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 130,
          height: 130,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 130,
                height: 130,
                child: CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 8,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.grey[200]!),
                ),
              ),
              SizedBox(
                width: 130,
                height: 130,
                child: CircularProgressIndicator(
                  value: progreso,
                  strokeWidth: 8,
                  valueColor: AlwaysStoppedAnimation<Color>(colorFase),
                ),
              ),
              Text(
                _fmt(seg),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: colorFase,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: colorFase.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            etiqueta,
            style: TextStyle(
              color: colorFase,
              fontWeight: FontWeight.bold,
              fontSize: 10,
              letterSpacing: 0.8,
            ),
          ),
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
