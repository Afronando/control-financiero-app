import 'package:flutter/material.dart';

const groupLabels = {
  'necesidad': 'Necesidades',
  'deseo': 'Deseos',
  'futuro': 'Futuro',
  'deuda': 'Pago de deudas',
};

// The web app's default-seeded categories store a Lucide icon *name* (e.g.
// "ShoppingCart") in the `emoji` column and render it via lucide-react.
// This is the Material Icons equivalent for each one, so this Flutter
// client shows a real icon instead of the raw name or a generic fallback.
// Custom categories a user adds themselves store an actual emoji character
// here instead - those fall through to categoryIcon()'s emoji branch below.
const Map<String, IconData> _lucideToMaterial = {
  'ShoppingCart': Icons.shopping_cart,
  'Wifi': Icons.wifi,
  'Phone': Icons.phone,
  'Bus': Icons.directions_bus,
  'Shield': Icons.shield,
  'ShowerHead': Icons.shower,
  'Home': Icons.home,
  'PawPrint': Icons.pets,
  'HeartPulse': Icons.monitor_heart,
  'Zap': Icons.bolt,
  'Droplet': Icons.water_drop,
  'Flame': Icons.local_fire_department,
  'Shirt': Icons.checkroom,
  'UtensilsCrossed': Icons.restaurant,
  'HeartHandshake': Icons.volunteer_activism,
  'Repeat': Icons.repeat,
  'Gift': Icons.card_giftcard,
  'Coffee': Icons.coffee,
  'Dumbbell': Icons.fitness_center,
  'Scissors': Icons.content_cut,
  'PartyPopper': Icons.celebration,
  'Palette': Icons.palette,
  'ShoppingBag': Icons.shopping_bag,
  'BookOpen': Icons.menu_book,
  'Plane': Icons.flight,
  'PiggyBank': Icons.savings,
  'Palmtree': Icons.beach_access,
  'Car': Icons.directions_car,
  'TrendingUp': Icons.trending_up,
  'Landmark': Icons.account_balance,
  'CreditCard': Icons.credit_card,
  'HandCoins': Icons.payments,
  'Smartphone': Icons.smartphone,
  'Tag': Icons.sell,
  'Wrench': Icons.build,
  'Building2': Icons.apartment,
  'Fuel': Icons.local_gas_station,
  'Bike': Icons.pedal_bike,
  'ParkingCircle': Icons.local_parking,
  'Pill': Icons.medication,
  'Music': Icons.music_note,
  'Gem': Icons.diamond,
  'GraduationCap': Icons.school,
  'Briefcase': Icons.work,
  'Baby': Icons.child_care,
  'Tv': Icons.tv,
  'Wallet': Icons.account_balance_wallet,
  'Banknote': Icons.attach_money,
};

// The known icon names, for building an icon picker grid.
List<String> get lucideIconNames => _lucideToMaterial.keys.toList();

// Renders a category's icon/emoji field as: a Material icon when it's one
// of the web app's known Lucide icon names, the literal character(s) when
// it looks like a real emoji, or a generic fallback tag icon otherwise.
Widget categoryIcon(String value, {double size = 20, Color? color}) {
  final icon = _lucideToMaterial[value];
  if (icon != null) return Icon(icon, size: size, color: color);
  if (value.runes.length <= 2 && value.trim().isNotEmpty) {
    return Text(value, style: TextStyle(fontSize: size));
  }
  return Icon(Icons.sell, size: size, color: color);
}
