import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api_client.dart';
import '../constants.dart';
import '../widgets/add_expense_sheet.dart';
import '../widgets/animated_money.dart';
import '../widgets/spending_gauge.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  final ApiClient api;
  const DashboardScreen({super.key, required this.api});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardData? _data;
  List<CategoryOption> _categories = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([widget.api.getDashboard(), widget.api.getCategories()]);
      setState(() {
        _data = results[0] as DashboardData;
        _categories = results[1] as List<CategoryOption>;
      });
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await _goToLogin();
        return;
      }
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'No se pudo conectar. Revisa tu conexión.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _goToLogin() async {
    await widget.api.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => LoginScreen(api: widget.api)),
    );
  }

  String _money(double v) {
    final currency = _data?.currency ?? '\$';
    return '$currency${NumberFormat('#,##0.00', 'es').format(v)}';
  }

  Future<void> _openAddExpense() async {
    if (_categories.isEmpty) return;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => AddExpenseSheet(api: widget.api, categories: _categories),
    );
    if (result == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _goToLogin),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddExpense,
        icon: const Icon(Icons.add),
        label: const Text('Agregar gasto'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorView(message: _error!, onRetry: _load)
          : RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    final d = _data!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(label: 'Ingresos', value: d.income, currency: d.currency),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(label: 'Gastos', value: d.totalExpenses, currency: d.currency),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _StatCard(label: 'Deudas', value: d.totalDebt, currency: d.currency),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                label: 'Disponible',
                value: d.disponible,
                currency: d.currency,
                accent: d.disponible < 0 ? Colors.redAccent : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: SpendingGauge(spent: d.totalExpenses, limit: d.spendingLimit, currency: d.currency),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Puedes gastar hoy', style: TextStyle(color: Colors.white60, fontSize: 12)),
                const SizedBox(height: 4),
                AnimatedMoney(
                  value: d.safeToSpendPerDay,
                  currency: d.currency,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '${d.daysRemaining} ${d.daysRemaining == 1 ? "día" : "días"} para terminar el mes',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Presupuesto 50/30/20', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                for (final g in d.groups.where((g) => g.group != 'deuda' || g.actual > 0))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _GroupBar(
                      label: groupLabels[g.group] ?? g.group,
                      actual: g.actual,
                      target: g.targetAmount,
                      currency: d.currency,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Últimas transacciones', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                if (d.recentTransactions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Aún no registras transacciones este mes.',
                      style: TextStyle(color: Colors.white60),
                    ),
                  ),
                for (final t in d.recentTransactions)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: Colors.white10,
                      child: categoryIcon(t.category.emoji, size: 18),
                    ),
                    title: Text(t.category.name),
                    subtitle: t.concept.isNotEmpty ? Text(t.concept) : null,
                    trailing: Text(_money(t.amount), style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final double value;
  final String currency;
  final Color? accent;
  const _StatCard({required this.label, required this.value, required this.currency, this.accent});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
            const SizedBox(height: 4),
            AnimatedMoney(
              value: value,
              currency: currency,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: accent),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupBar extends StatelessWidget {
  final String label;
  final double actual;
  final double target;
  final String currency;
  const _GroupBar({
    required this.label,
    required this.actual,
    required this.target,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final over = target > 0 && actual > target;
    final pct = target > 0 ? (actual / target).clamp(0, 1).toDouble() : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            Row(
              children: [
                AnimatedMoney(
                  value: actual,
                  currency: currency,
                  style: TextStyle(color: over ? Colors.redAccent : Colors.white60, fontSize: 12),
                ),
                Text(
                  ' / $currency${NumberFormat('#,##0.00', 'es').format(target)}',
                  style: TextStyle(color: over ? Colors.redAccent : Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: pct),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, animatedPct, _) => LinearProgressIndicator(
              value: animatedPct,
              minHeight: 8,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation(over ? Colors.redAccent : Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, style: const TextStyle(color: Colors.white60)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}
