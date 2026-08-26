import 'dart:math';
import 'package:flutter/material.dart';
import 'animated_money.dart';

// Circular "spent vs. limit" gauge, the mobile equivalent of the web
// dashboard's ring (src/components/spending-gauge.tsx). The progress arc
// animates in from empty on first build, same "fill on load" treatment
// used across the web app's charts.
class SpendingGauge extends StatelessWidget {
  final double spent;
  final double limit;
  final String currency;
  const SpendingGauge({super.key, required this.spent, required this.limit, required this.currency});

  @override
  Widget build(BuildContext context) {
    final pct = limit > 0 ? (spent / limit).clamp(0, 1).toDouble() : 0.0;
    final over = limit > 0 && spent > limit;
    final available = limit - spent;
    final color = over ? Colors.redAccent : Colors.white;

    return SizedBox(
      width: 168,
      height: 168,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: pct),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, animatedPct, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(168, 168),
                painter: _GaugePainter(pct: animatedPct, color: color),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Disponible', style: TextStyle(fontSize: 11, color: Colors.white60)),
                  const SizedBox(height: 2),
                  AnimatedMoney(
                    value: available,
                    currency: currency,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: over ? Colors.redAccent : Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double pct;
  final Color color;
  _GaugePainter({required this.pct, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.width - stroke) / 2;

    final track = Paint()
      ..color = Colors.white12
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);

    final progress = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * pct,
      false,
      progress,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) =>
      oldDelegate.pct != pct || oldDelegate.color != color;
}
