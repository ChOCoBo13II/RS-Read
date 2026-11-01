import 'package:flutter/material.dart';

import 'theme.dart';

/// Barra sottile in stile Apple Music: niente cursore, si ingrossa al tocco.
class ScrubBar extends StatefulWidget {
  const ScrubBar({
    super.key,
    required this.value,
    required this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
    this.divisions,
  });

  /// Posizione da 0 a 1.
  final double value;
  final int? divisions;
  final ValueChanged<double> onChanged;
  final VoidCallback? onChangeStart;
  final ValueChanged<double>? onChangeEnd;

  @override
  State<ScrubBar> createState() => _ScrubBarState();
}

class _ScrubBarState extends State<ScrubBar> {
  bool _pressed = false;
  bool _dragging = false;
  double _last = 0;

  double _fraction(double dx, double width) {
    var f = width <= 0 ? 0.0 : (dx / width).clamp(0.0, 1.0).toDouble();
    final d = widget.divisions;
    if (d != null && d > 0) f = (f * d).round() / d;
    return f;
  }

  @override
  Widget build(BuildContext context) {
    final active = _pressed || _dragging;
    final fill = widget.value.clamp(0.0, 1.0).toDouble();
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (d) {
            setState(() => _pressed = false);
            widget.onChangeStart?.call();
            final f = _fraction(d.localPosition.dx, w);
            widget.onChanged(f);
            widget.onChangeEnd?.call(f);
          },
          onHorizontalDragStart: (d) {
            setState(() => _dragging = true);
            widget.onChangeStart?.call();
            _last = _fraction(d.localPosition.dx, w);
            widget.onChanged(_last);
          },
          onHorizontalDragUpdate: (d) {
            _last = _fraction(d.localPosition.dx, w);
            widget.onChanged(_last);
          },
          onHorizontalDragEnd: (_) {
            setState(() => _dragging = false);
            widget.onChangeEnd?.call(_last);
          },
          onHorizontalDragCancel: () {
            if (_dragging) {
              setState(() => _dragging = false);
              widget.onChangeEnd?.call(_last);
            }
          },
          child: SizedBox(
            height: 24,
            child: Align(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                height: active ? 14 : 6,
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(
                  color: Color(0x29000000),
                  borderRadius: BorderRadius.all(Radius.circular(7)),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: fill,
                    heightFactor: 1,
                    child: const ColoredBox(color: Ui.ink),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}