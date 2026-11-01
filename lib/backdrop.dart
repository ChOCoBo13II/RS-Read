import 'dart:ui' show ImageFilter, TileMode;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Sfondo giallo con due macchie sfocate. Per ora fermo.
class AppBackdrop extends StatelessWidget {
  const AppBackdrop({super.key});

  Widget _blob({
    double? left,
    double? right,
    double? top,
    double? bottom,
    required double size,
    required Color color,
    required double sigma,
  }) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      width: size,
      height: size,
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(
          sigmaX: sigma,
          sigmaY: sigma,
          tileMode: TileMode.decal,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
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
            ),
            _blob(
              right: -80,
              bottom: 100,
              size: 280,
              color: const Color(0xB3FFB000),
              sigma: 40,
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