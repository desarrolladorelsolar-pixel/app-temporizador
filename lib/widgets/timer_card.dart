import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/temporizador.dart';
import '../state/app_state.dart';

// ── TimerCard — responsive con LayoutBuilder ──────────────────────────────────
// El tamaño del círculo/botón se calcula en tiempo real según el ancho
// real de la celda del grid, garantizando que se vea bien en:
//   - Móvil portrait  (2 columnas)
//   - Móvil landscape (3 columnas)
//   - Tablet portrait (3 columnas)
//   - Tablet landscape (4 columnas)
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
    final appState = context.read<AppState>();
    switch (t.estado) {
      case 'pausado':       appState.reanudarTemporizador(widget.index);
      case 'listo_repaso':  appState.iniciarRepaso(widget.index);
      default:              appState.toggleTemporizador(widget.index);
    }
  }

  Future<void> _onRepasoTap() async {
    final t = widget.temporizador;
    if (t.producto.tiempoRepaso <= 0 || t.corriendo) return;
    if (t.estado == 'listo_repaso') {
      context.read<AppState>().cancelarRepaso(widget.index); return;
    }
    final boquilla = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿En qué boquilla?',
            style: TextStyle(color: Color(0xFF2E7D32),
                fontWeight: FontWeight.bold, fontSize: 17)),
        content: Text('${t.producto.nombre}\nRepaso: ${t.producto.tiempoRepaso} min'),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          _BotonBoquilla(numero: 1, subtitulo: 'Cocción',
              onTap: () => Navigator.of(ctx).pop(1)),
          _BotonBoquilla(numero: 2, subtitulo: 'Tostado',
              onTap: () => Navigator.of(ctx).pop(2)),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[600])),
          ),
        ],
      ),
    );
    if (boquilla != null && mounted) {
      context.read<AppState>().prepararRepaso(widget.index, boquilla);
    }
  }

  Future<void> _onPausaTap() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Pausar temporizador',
            style: TextStyle(color: Color(0xFFC62828),
                fontWeight: FontWeight.bold, fontSize: 17)),
        content: Text('¿Pausar "${widget.temporizador.producto.nombre}"?\n'
            'El tiempo restante se conserva.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancelar', style: TextStyle(color: Colors.grey[600]))),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Pausar', style: TextStyle(
                  color: Color(0xFFC62828), fontWeight: FontWeight.bold))),
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

    final Color colorFase = (esRepaso || listoRepaso)
        ? const Color(0xFF2E7D32)
        : (enTostado || esperaTostado ||
               (pausado && t.estadoAntesDePausa == 'tostado'))
            ? const Color(0xFFE65100)
            : const Color(0xFFC62828);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (ctx, box) {
          // Círculo proporcional al ancho real de la celda
          final double circ = (box.maxWidth * 0.55).clamp(68.0, 118.0);
          final double icon  = circ * 0.60;
          final double fSize = (circ * 0.185).clamp(15.0, 24.0);

          return Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _Header(
                  temporizador: t, colorFase: colorFase,
                  corriendo: corriendo, listoRepaso: listoRepaso,
                  onPausaTap: _onPausaTap, onRepasoTap: _onRepasoTap,
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Center(
                    child: RepaintBoundary(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: _buildCentro(t, corriendo, esRepaso, listoRepaso,
                            esperaTostado, pausado, colorFase,
                            circ, icon, fSize),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCentro(
    Temporizador t, bool corriendo, bool esRepaso, bool listoRepaso,
    bool esperaTostado, bool pausado,
    Color colorFase, double circ, double icon, double fSize,
  ) {
    if (esRepaso) {
      return _Circulo(key: const ValueKey('c_repaso'),
          restantes: t.tiempoRepasoRestante,
          totales: t.producto.tiempoRepaso * 60,
          color: colorFase, label: 'REPASO B${t.boquillaRepaso}',
          size: circ, fSize: fSize);
    }
    if (corriendo) {
      final bool enCoccion = t.estado == 'coccion';
      return _Circulo(
          key: ValueKey('c_${t.estado}'),
          restantes: enCoccion ? t.tiempoCoccionRestante : t.tiempoTostadoRestante,
          totales: enCoccion
              ? t.producto.tiempoCoccion * 60
              : t.producto.tiempoTostado * 60,
          color: colorFase,
          label: enCoccion ? 'COCCIÓN' : 'TOSTADO',
          size: circ, fSize: fSize);
    }
    if (esperaTostado) {
      return _BtnPulsante(key: const ValueKey('tostado'),
          onDoubleTap: _onDoubleTap, color: const Color(0xFFE65100),
          size: circ, iconSize: icon, label: 'TOSTADO');
    }
    if (listoRepaso) {
      return _BtnPulsante(key: const ValueKey('listo_repaso'),
          onDoubleTap: _onDoubleTap, color: const Color(0xFF2E7D32),
          size: circ, iconSize: icon,
          label: 'REPASO B${t.boquillaRepaso}',
          sublabel: '${t.producto.tiempoRepaso} min');
    }
    if (pausado) {
      return _BtnPlay(key: const ValueKey('pausado'),
          color: Colors.grey[200]!,
          iconColor: colorFase,
          onDoubleTap: _onDoubleTap,
          size: circ, iconSize: icon,
          label: (t.estadoAntesDePausa ?? 'coccion').toUpperCase());
    }
    return _BtnPlay(key: const ValueKey('play'),
        color: colorFase, iconColor: Colors.white,
        onDoubleTap: _onDoubleTap,
        size: circ, iconSize: icon);
  }
}

// ── Header ────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final Temporizador temporizador;
  final Color colorFase;
  final bool corriendo, listoRepaso;
  final VoidCallback onPausaTap, onRepasoTap;

  const _Header({
    required this.temporizador, required this.colorFase,
    required this.corriendo, required this.listoRepaso,
    required this.onPausaTap, required this.onRepasoTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool tieneRepaso = temporizador.producto.tiempoRepaso > 0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ↺ izquierda
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
              shape: BoxShape.circle),
            child: Icon(
              listoRepaso ? Icons.close : Icons.replay_rounded,
              size: 17,
              color: listoRepaso ? const Color(0xFF2E7D32)
                  : tieneRepaso ? const Color(0xFFF9A825)
                  : Colors.grey[350]),
          ),
        ),
        const SizedBox(width: 3),

        // Nombre + freidora
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(temporizador.producto.nombre,
                  textAlign: TextAlign.center, maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900,
                      color: colorFase)),
              const SizedBox(height: 1),
              Text(temporizador.freidora.codigo,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                      color: Colors.grey[500], letterSpacing: 1.1)),
            ],
          ),
        ),

        const SizedBox(width: 3),

        // ⏸ derecha — solo mientras corre (no en repaso)
        if (corriendo && temporizador.estado != 'repaso')
          GestureDetector(
            onTap: onPausaTap,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: Colors.grey[100],
                  shape: BoxShape.circle),
              child: Icon(Icons.pause_rounded, size: 17, color: Colors.grey[500]),
            ),
          )
        else
          const SizedBox(width: 25),
      ],
    );
  }
}

// ── Circulo de progreso universal ─────────────────────────────────────────────
class _Circulo extends StatelessWidget {
  final int restantes, totales;
  final Color color;
  final String label;
  final double size, fSize;

  const _Circulo({super.key,
    required this.restantes, required this.totales,
    required this.color, required this.label,
    required this.size, required this.fSize});

  @override
  Widget build(BuildContext context) {
    final double prog = totales > 0 ? (totales - restantes) / totales : 1.0;
    final int m = restantes ~/ 60, s = restantes % 60;
    final String tiempo =
        '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

    return Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(width: size, height: size,
        child: Stack(alignment: Alignment.center, children: [
          SizedBox(width: size, height: size,
              child: CircularProgressIndicator(value: 1.0, strokeWidth: 6,
                  valueColor: AlwaysStoppedAnimation(Colors.grey[200]!))),
          SizedBox(width: size, height: size,
              child: CircularProgressIndicator(value: prog, strokeWidth: 6,
                  valueColor: AlwaysStoppedAnimation(color))),
          Text(tiempo, style: TextStyle(fontSize: fSize,
              fontWeight: FontWeight.bold, color: color)),
        ]),
      ),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(color: color,
            fontWeight: FontWeight.bold, fontSize: 9, letterSpacing: 0.7)),
      ),
    ]);
  }
}

// ── Botón play estático ───────────────────────────────────────────────────────
class _BtnPlay extends StatelessWidget {
  final Color color, iconColor;
  final VoidCallback onDoubleTap;
  final double size, iconSize;
  final String? label;

  const _BtnPlay({super.key,
    required this.color, required this.iconColor,
    required this.onDoubleTap, required this.size, required this.iconSize,
    this.label});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: onDoubleTap,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: color.withOpacity(0.35),
              blurRadius: 16, offset: const Offset(0, 5))]),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.play_arrow_rounded, color: iconColor, size: iconSize),
          if (label != null)
            Text(label!, style: TextStyle(color: iconColor, fontSize: 9,
                fontWeight: FontWeight.bold, letterSpacing: 1)),
        ]),
      ),
    );
  }
}

// ── Botón pulsante (tostado / listo repaso) ───────────────────────────────────
class _BtnPulsante extends StatefulWidget {
  final VoidCallback onDoubleTap;
  final Color color;
  final double size, iconSize;
  final String label;
  final String? sublabel;

  const _BtnPulsante({super.key,
    required this.onDoubleTap, required this.color,
    required this.size, required this.iconSize, required this.label,
    this.sublabel});

  @override
  State<_BtnPulsante> createState() => _BtnPulsanteState();
}

class _BtnPulsanteState extends State<_BtnPulsante>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 750))
        ..repeat(reverse: true);
  late final Animation<double> _s =
      Tween(begin: 0.93, end: 1.05)
          .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: widget.onDoubleTap,
      child: ScaleTransition(
        scale: _s,
        child: Container(
          width: widget.size, height: widget.size,
          decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: widget.color.withOpacity(0.45),
                blurRadius: 22, offset: const Offset(0, 5))]),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.play_arrow_rounded, color: Colors.white,
                size: widget.iconSize),
            Text(widget.label, style: const TextStyle(color: Colors.white,
                fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
            if (widget.sublabel != null)
              Text(widget.sublabel!, style: const TextStyle(
                  color: Colors.white70, fontSize: 9)),
          ]),
        ),
      ),
    );
  }
}

// ── Botón de selección de boquilla (diálogo) ──────────────────────────────────
class _BotonBoquilla extends StatelessWidget {
  final int numero;
  final String subtitulo;
  final VoidCallback onTap;
  const _BotonBoquilla({required this.numero, required this.subtitulo,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2E7D32), width: 1.5)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('B$numero', style: const TextStyle(color: Color(0xFF2E7D32),
              fontWeight: FontWeight.bold, fontSize: 18)),
          Text(subtitulo, style: const TextStyle(
              color: Color(0xFF2E7D32), fontSize: 11)),
        ]),
      ),
    );
  }
}
