import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Visual da barra de volta no tempo: canaleta cinza clara, preenchimento em
/// degradê azul e botão redondo metálico.
class TimeshiftSliderTheme extends StatelessWidget {
  const TimeshiftSliderTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 22,
        trackShape: const _GrooveTrackShape(),
        thumbShape: const _MetalThumbShape(),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
        overlayColor: const Color(0x331E88E5),
      ),
      child: child,
    );
  }
}

class _GrooveTrackShape extends SliderTrackShape with BaseSliderTrackShape {
  const _GrooveTrackShape();

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
  }) {
    final rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final canvas = context.canvas;
    final radius = Radius.circular(rect.height / 2);
    final groove = RRect.fromRectAndRadius(rect, radius);

    // Canaleta: cinza claro, mais escura em cima para parecer rebaixada.
    canvas.drawRRect(
      groove,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFB9BCC2), Color(0xFFD9DBDF), Color(0xFFE6E7EA)],
          stops: [0.0, 0.45, 1.0],
        ).createShader(rect),
    );
    canvas.drawRRect(
      groove,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x55000000),
    );

    // Preenchimento: degradê azul, um pouco menor que a canaleta.
    const inset = 3.5;
    final right = thumbCenter.dx.clamp(rect.left + rect.height / 2, rect.right);
    final fill = Rect.fromLTRB(rect.left + inset, rect.top + inset, right, rect.bottom - inset);
    if (fill.width > 0) {
      final opacity = isEnabled ? 1.0 : 0.35;
      canvas.drawRRect(
        RRect.fromRectAndRadius(fill, Radius.circular(fill.height / 2)),
        Paint()
          ..shader = LinearGradient(
            colors: [
              const Color(0xFF35D0F2).withValues(alpha: opacity),
              const Color(0xFF1E88E5).withValues(alpha: opacity),
            ],
          ).createShader(Rect.fromLTRB(rect.left, rect.top, rect.right, rect.bottom)),
      );
    }
  }
}

class _MetalThumbShape extends SliderComponentShape {
  const _MetalThumbShape();

  static const _radius = 17.0;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size.fromRadius(_radius);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    final circle = Rect.fromCircle(center: center, radius: _radius);

    // Sombra.
    canvas.drawCircle(
      center.translate(0, 2),
      _radius,
      Paint()
        ..color = const Color(0x66000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    // Metal escovado: faixas claras e escuras girando em volta do centro.
    canvas.drawCircle(
      center,
      _radius,
      Paint()
        ..shader = const SweepGradient(
          transform: GradientRotation(-math.pi / 2),
          colors: [
            Color(0xFFF4F5F6),
            Color(0xFF9EA2A8),
            Color(0xFFECEDEF),
            Color(0xFF8D9197),
            Color(0xFFF4F5F6),
            Color(0xFF9EA2A8),
            Color(0xFFECEDEF),
            Color(0xFF8D9197),
            Color(0xFFF4F5F6),
          ],
        ).createShader(circle),
    );
    // Aro.
    canvas.drawCircle(
      center,
      _radius - 0.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFF7C8086),
    );
    canvas.drawCircle(
      center,
      _radius - 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x99FFFFFF),
    );
  }
}
