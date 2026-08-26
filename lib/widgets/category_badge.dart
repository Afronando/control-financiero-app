import 'package:flutter/material.dart';
import '../constants.dart';

const List<MaterialColor> _palette = [
  Colors.pink,
  Colors.green,
  Colors.blue,
  Colors.purple,
  Colors.orange,
  Colors.teal,
  Colors.indigo,
  Colors.brown,
  Colors.cyan,
  Colors.deepOrange,
  Colors.lightGreen,
  Colors.deepPurple,
];

MaterialColor _colorFor(String categoryId) {
  final hash = categoryId.codeUnits.fold<int>(0, (a, b) => a + b);
  return _palette[hash % _palette.length];
}

// A colored rounded-square icon badge per category, matching the reference
// app's category-picker style - each category gets a consistent pastel
// color (hashed from its id) instead of every row looking the same.
class CategoryBadge extends StatelessWidget {
  final String categoryId;
  final String iconValue;
  final double size;
  const CategoryBadge({
    super.key,
    required this.categoryId,
    required this.iconValue,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final seed = _colorFor(categoryId);
    final bg = seed.withValues(alpha: isDark ? 0.22 : 0.15);
    final fg = isDark ? seed[200]! : seed[700]!;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(size * 0.3)),
      alignment: Alignment.center,
      child: categoryIcon(iconValue, size: size * 0.5, color: fg),
    );
  }
}
