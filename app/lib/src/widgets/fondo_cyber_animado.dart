import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tema/paleta.dart';

class FondoCyberAnimado extends StatefulWidget {
  const FondoCyberAnimado({super.key});

  @override
  State<FondoCyberAnimado> createState() => _FondoCyberAnimadoState();
}

class _FondoCyberAnimadoState extends State<FondoCyberAnimado>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animacion;

  @override
  void initState() {
    super.initState();
    _animacion = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _animacion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;

    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _animacion,
          builder: (context, _) {
            final t = _animacion.value * math.pi * 2;
            return CustomPaint(
              painter: _CyberGlowPainter(
                fase: t,
                rosa: paleta.acento,
                cielo: paleta.acentoAlt,
                morado: const Color(0xFF9D5CFF),
              ),
              child: const SizedBox.expand(),
            );
          },
        ),
      ),
    );
  }
}

class _CyberGlowPainter extends CustomPainter {
  const _CyberGlowPainter({
    required this.fase,
    required this.rosa,
    required this.cielo,
    required this.morado,
  });

  final double fase;
  final Color rosa;
  final Color cielo;
  final Color morado;

  @override
  void paint(Canvas canvas, Size size) {
    final puntos = <({Offset centro, double radio, Color color})>[
      (
        centro: Offset(
          size.width * (.18 + .08 * math.sin(fase)),
          size.height * (.24 + .10 * math.cos(fase * .8)),
        ),
        radio: size.shortestSide * .48,
        color: morado,
      ),
      (
        centro: Offset(
          size.width * (.78 + .10 * math.cos(fase * .7)),
          size.height * (.30 + .08 * math.sin(fase * 1.1)),
        ),
        radio: size.shortestSide * .42,
        color: rosa,
      ),
      (
        centro: Offset(
          size.width * (.58 + .12 * math.sin(fase * .55)),
          size.height * (.82 + .06 * math.cos(fase)),
        ),
        radio: size.shortestSide * .52,
        color: cielo,
      ),
    ];

    for (final punto in puntos) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            punto.color.withValues(alpha: .16),
            punto.color.withValues(alpha: .055),
            Colors.transparent,
          ],
          stops: const [0, .46, 1],
        ).createShader(
          Rect.fromCircle(center: punto.centro, radius: punto.radio),
        );
      canvas.drawCircle(punto.centro, punto.radio, paint);
    }

    final linePaint = Paint()
      ..color = cielo.withValues(alpha: .035)
      ..strokeWidth = 1;

    const paso = 64.0;
    for (double x = -paso; x < size.width + paso; x += paso) {
      canvas.drawLine(Offset(x, 0), Offset(x + 80, size.height), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CyberGlowPainter oldDelegate) =>
      oldDelegate.fase != fase ||
      oldDelegate.rosa != rosa ||
      oldDelegate.cielo != cielo ||
      oldDelegate.morado != morado;
}
