import 'dart:math' as math;
import 'dart:ui' show ImageFilter, TileMode;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Sfondo giallo con due macchie sfocate che si muovono molto lentamente.
/// Con animate = false restano ferme dove sono e riprendono da lì.
class AppBackdrop extends StatefulWidget {
  const AppBackdrop({super.key, this.animate = true});

  final bool animate;

  @override
  State<AppBackdrop> createState() => _AppBackdropState();
}

class _AppBackdropState extends State<AppBackdrop>
    with SingleTickerProviderStateMixin {
  // Un giro completo dura 90 secondi.
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 90),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.repeat();
  }

  @override
  void didUpdateWidget(AppBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate == oldWidget.animate) return;
    if (widget.animate) {
      _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  // Macchia sfocata che percorre un'orbita ellittica. La posizione del
  // cerchio è quella di prima; il riquadro è più grande di 3 sigma per lato,
  // così la sfocatura sta tutta dentro il livello e non viene tagliata.
  // direction deve essere 1 o -1 (il giro si chiude senza scatti).
  Widget _blob({
    double? left,
    double? right,
    double? top,
    double? bottom,
    required double size,
    required Color color,
    required double sigma,
    required double orbitX,
    required double orbitY,
    required double phase,
    required double direction,
  }) {
    final pad = sigma * 3;
    final blob = RepaintBoundary(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(
          sigmaX: sigma,
          sigmaY: sigma,
          tileMode: TileMode.decal,
        ),
        child: Padding(
          padding: EdgeInsets.all(pad),
          child: DecoratedBox(
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
      ),
    );
    return Positioned(
      left: left == null ? null : left - pad,
      right: right == null ? null : right - pad,
      top: top == null ? null : top - pad,
      bottom: bottom == null ? null : bottom - pad,
      width: size + 2 * pad,
      height: size + 2 * pad,
      child: AnimatedBuilder(
        animation: _c,
        child: blob,
        builder: (context, child) {
          final a = 2 * math.pi * _c.value * direction + phase;
          return Transform.translate(
            offset: Offset(orbitX * math.cos(a), orbitY * math.sin(a)),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ColoredBox(
        color: Ui.yellow,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            _blob(
              left: -60,
              top: -40,
              size: 260,
              color: const Color(0x1CFF5252),
              sigma: 30,
              orbitX: 70,
              orbitY: 50,
              phase: 0,
              direction: 1,
            ),
            _blob(
              right: -80,
              bottom: 100,
              size: 280,
              color: const Color(0xB3FFB000),
              sigma: 40,
              orbitX: 60,
              orbitY: 70,
              phase: math.pi,
              direction: -1,
            ),
          ],
        ),
      ),
    );
  }
}

/// Pannello di vetro: sfoca quello che c'è dietro, con velo rosso e bordo chiaro.
class Glass extends StatelessWidget {
  const Glass({super.key, required this.child, this.radius = Ui.radius});

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: r,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Ui.glassTint,
            borderRadius: r,
            border: Border.all(color: Ui.glassBorder),
          ),
          child: child,
        ),
      ),
    );
  }
}