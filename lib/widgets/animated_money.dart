import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Counts up from 0 to `value` on first build and animates between values
// on updates, matching the "hero number" treatment already applied to the
// web dashboard (src/components/animated-number.tsx).
// Same idea as AnimatedMoney but for a plain "NN%" figure (goal progress).
class AnimatedPercent extends StatelessWidget {
  final double value;
  final TextStyle? style;
  const AnimatedPercent({super.key, required this.value, this.style});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text('${v.toStringAsFixed(0)}%', style: style),
    );
  }
}

class AnimatedMoney extends StatelessWidget {
  final double value;
  final String currency;
  final TextStyle? style;
  const AnimatedMoney({super.key, required this.value, this.currency = '\$', this.style});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        return Text('$currency${NumberFormat('#,##0.00', 'es').format(v)}', style: style);
      },
    );
  }
}
