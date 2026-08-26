const groupLabels = {
  'necesidad': 'Necesidades',
  'deseo': 'Deseos',
  'futuro': 'Futuro',
  'deuda': 'Pago de deudas',
};

// Default-seeded categories store a Lucide icon *name* (e.g. "ShoppingCart")
// in the emoji column, rendered as a real icon on the web app - this Flutter
// client doesn't have that icon set, so anything longer than a couple of
// code points is treated as "not an emoji" and gets a generic fallback
// instead of printing the raw icon name.
String iconOrFallback(String emoji, {String fallback = '💰'}) {
  return emoji.runes.length <= 2 ? emoji : fallback;
}
