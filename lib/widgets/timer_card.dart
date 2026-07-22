import 'dart:async';
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Pausar temporizador',
            style: TextStyle(color: Color(0xFFC62828), fontWeight: FontWeight.bold, fontSize: 17)),
        content: Text('¿Pausar "${widget.temporizador.producto.nombre}"?\nEl tiempo restante se conserva.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[600])),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Pausar',
                style: TextStyle(color: Color(0xFFC62828), fontWeight: FontWeight.bold)),
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
            // ── Header: botón Repasar | nombre/freidora | botón Pausa ────
            _Header(
              temporizador: t,
              colorFase: colorFase,
              corriendo: corriendo,
              index: widget.index,
              onPausaTap: _onPausaTap,
            ),

            // ── Banda de repaso (solo si hay repaso activo) ───────────────
            Selector<AppState, int>(
              selector: (_, s) => s.segundosRepaso(widget.index),
              builder: (ctx, segs, _) {
                if (segs <= 0) return const SizedBox.shrink();
                return _BandaRepaso(
                  segundos: segs,
                  boquilla: t.producto.boquillaRepaso,
                );
              },
            ),

            const SizedBox(height: 4),

            // ── Zona central ──────────────────────────────────────────────
            Expanded(
              child: Center(
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

// ── Header con botón Repasar (izq) | nombre/freidora | botón Pausa (der) ─────
class _Header extends StatelessWidget {
  final Temporizador temporizador;
  final Color colorFase;
  final bool corriendo;
  final int index;
  final VoidCallback onPausaTap;

  const _Header({
    required this.temporizador,
    required this.colorFase,
    required this.corriendo,
    required this.index,
    required this.onPausaTap,
  });

  @override
  Widget build(BuildContext context) {
    final tieneRepaso = temporizador.producto.tiempoRepaso > 0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Botón Repasar — esquina superior izquierda ────────────────────
        GestureDetector(
          onTap: tieneRepaso
              ? () => context.read<AppState>().iniciarRepaso(index)
              : null,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: tieneRepaso
                  ? const Color(0xFFF9A825).withOpacity(0.15)
                  : Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.replay_rounded,
              size: 18,
              color: tieneRepaso ? const Color(0xFFF9A825) : Colors.grey[350],
            ),
          ),
        ),
        const SizedBox(width: 4),

        // ── Nombre del producto y freidora ────────────────────────────────
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
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: colorFase,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                temporizador.freidora.codigo,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[500],
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 4),

        // ── Botón Pausa — esquina superior derecha ────────────────────────
        if (corriendo)
          GestureDetector(
            onTap: onPausaTap,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.pause_rounded, size: 18, color: Colors.grey[500]),
            ),
          )
        else
          const SizedBox(width: 26), // espacio reservado para alinear
      ],
    );
  }
}

// ── Banda de repaso ───────────────────────────────────────────────────────────
// Aparece debajo del header cuando hay un repaso activo.
// Color ámbar para diferenciarse de cocción (rojo) y tostado (naranja).
class _BandaRepaso extends StatelessWidget {
  final int segundos;
  final int boquilla;

  const _BandaRepaso({required this.segundos, required this.boquilla});

  @override
  Widget build(BuildContext context) {
    final m = segundos ~/ 60;
    final s = segundos % 60;
    final tiempo = '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF9A825).withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF9A825), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.replay_rounded, size: 12, color: Color(0xFFF57F00)),
          const SizedBox(width: 4),
          Text(
            'REPASO B$boquilla  $tiempo',
            style: const TextStyle(
              color: Color(0xFFF57F00),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
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
