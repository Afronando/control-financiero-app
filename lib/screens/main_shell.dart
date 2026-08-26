import 'package:flutter/material.dart';
import '../api_client.dart';
import 'dashboard_screen.dart';
import 'transactions_screen.dart';
import 'budget_screen.dart';
import 'goals_screen.dart';

// Each tab keeps its own Scaffold (AppBar, FAB) - simplest way to reuse the
// already-working DashboardScreen etc. without refactoring them to be
// "body only". IndexedStack keeps every tab's state alive across switches.
class MainShell extends StatefulWidget {
  final ApiClient api;
  const MainShell({super.key, required this.api});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      DashboardScreen(api: widget.api),
      TransactionsScreen(api: widget.api),
      BudgetScreen(api: widget.api),
      GoalsScreen(api: widget.api),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Transacciones',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline),
            selectedIcon: Icon(Icons.pie_chart),
            label: 'Presupuesto',
          ),
          NavigationDestination(
            icon: Icon(Icons.flag_outlined),
            selectedIcon: Icon(Icons.flag),
            label: 'Metas',
          ),
        ],
      ),
    );
  }
}
