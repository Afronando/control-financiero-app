import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api_client.dart';
import '../constants.dart';
import '../theme_controller.dart';
import '../widgets/add_expense_sheet.dart';
import '../widgets/add_income_sheet.dart';
import '../widgets/animated_money.dart';
import '../widgets/category_badge.dart';
import '../widgets/slide_fade_route.dart';
import 'annual_screen.dart';
import 'budget_screen.dart';
import 'debts_screen.dart';
import 'goals_screen.dart';
import 'login_screen.dart';
import 'settings_screen.dart';
import 'transactions_screen.dart';

const _monthNames = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

// Single main screen, no bottom tab bar - Transacciones/Presupuesto/Metas/
// Deudas/Anual are reached from the icon row up top, matching the reference
// app's structure (one dominant screen + a floating add bar, not a tab set).
class HomeScreen extends StatefulWidget {
  final ApiClient api;
  final ThemeController themeController;
  const HomeScreen({
    super.key,
    required this.api,
    required this.themeController,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DashboardData? _data;
  List<CategoryOption> _categories = [];
  bool _loading = true;
  String? _error;
  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.api.getDashboard(year: _year, month: _month),
        widget.api.getCategories(),
      ]);
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

  void _changeMonth(int delta) {
    setState(() {
      _month += delta;
      if (_month > 12) {
        _month = 1;
        _year++;
      } else if (_month < 1) {
        _month = 12;
        _year--;
      }
    });
    _load();
  }

  Future<void> _goToLogin() async {
    await widget.api.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          api: widget.api,
          themeController: widget.themeController,
        ),
      ),
      (route) => false,
    );
  }

  Future<void> _push(Widget screen) async {
    await Navigator.of(context).push(SlideFadeRoute(page: screen));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _ErrorView(message: _error!, onRetry: _load)
            : RefreshIndicator(onRefresh: _load, child: _buildBody()),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _BottomActionBar(
        api: widget.api,
        categories: _categories,
        onDone: _load,
        year: _year,
        month: _month,
      ),
    );
  }

  Widget _buildBody() {
    final d = _data!;
    final grouped = <String, List<TransactionEntry>>{};
    for (final t in d.recentTransactions) {
      (grouped[t.date] ??= []).add(t);
    }
    final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _TopIconButton(
              icon: Icons.credit_card_outlined,
              onTap: () => _push(DebtsScreen(api: widget.api)),
            ),
            const SizedBox(width: 8),
            _TopIconButton(
              icon: Icons.bar_chart_outlined,
              onTap: () => _push(AnnualScreen(api: widget.api)),
            ),
            const SizedBox(width: 8),
            _TopIconButton(
              icon: Icons.pie_chart_outline,
              onTap: () => _push(
                BudgetScreen(api: widget.api, year: _year, month: _month),
              ),
            ),
            const SizedBox(width: 8),
            _TopIconButton(
              icon: Icons.flag_outlined,
              onTap: () => _push(GoalsScreen(api: widget.api)),
            ),
            const SizedBox(width: 8),
            _TopIconButton(
              icon: Icons.settings_outlined,
              onTap: () => _push(
                SettingsScreen(
                  api: widget.api,
                  themeController: widget.themeController,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _changeMonth(-1),
            ),
            SizedBox(
              width: 150,
              child: Text(
                '${_monthNames[_month - 1]} $_year',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => _changeMonth(1),
            ),
          ],
        ),
        Center(
          child: Text(
            'Disponible este mes',
            style: TextStyle(color: muted, fontSize: 13),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: AnimatedMoney(
            value: d.disponible,
            currency: d.currency,
            style: TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w800,
              color: d.disponible < 0
                  ? Theme.of(context).colorScheme.error
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            children: [
              _MiniStat(
                label: 'Ingresos',
                value: d.income,
                currency: d.currency,
              ),
              _MiniStat(
                label: 'Gastos',
                value: d.totalExpenses,
                currency: d.currency,
              ),
              _MiniStat(
                label: 'Deudas',
                value: d.totalDebt,
                currency: d.currency,
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Presupuesto 50/30/20',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                for (final g in d.groups.where(
                  (g) => g.group != 'deuda' || g.actual > 0,
                ))
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
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Transacciones',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            TextButton(
              onPressed: () => _push(
                TransactionsScreen(api: widget.api, year: _year, month: _month),
              ),
              child: const Text('Ver todas'),
            ),
          ],
        ),
        if (d.recentTransactions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Aún no registras transacciones este mes.',
              textAlign: TextAlign.center,
              style: TextStyle(color: muted),
            ),
          ),
        for (final date in dates) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 6),
            child: Text(
              _formatDateHeader(date),
              style: TextStyle(fontSize: 12, color: muted),
            ),
          ),
          for (final t in grouped[date]!)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CategoryBadge(
                  categoryId: t.category.id,
                  iconValue: t.category.emoji,
                ),
                title: Text(t.category.name),
                subtitle: t.concept.isNotEmpty ? Text(t.concept) : null,
                trailing: Text(
                  '${d.currency}${NumberFormat('#,##0.00', 'es').format(t.amount)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ],
    );
  }

  String _formatDateHeader(String iso) {
    try {
      final date = DateTime.parse(iso);
      const days = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
      const months = [
        'ene',
        'feb',
        'mar',
        'abr',
        'may',
        'jun',
        'jul',
        'ago',
        'sep',
        'oct',
        'nov',
        'dic',
      ];
      return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]}';
    } catch (_) {
      return iso;
    }
  }
}

class _TopIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _TopIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, size: 18),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final double value;
  final String currency;
  const _MiniStat({
    required this.label,
    required this.value,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label ', style: TextStyle(color: muted, fontSize: 12)),
        AnimatedMoney(
          value: value,
          currency: currency,
          style: TextStyle(
            color: muted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
    final trackBg = Theme.of(context).colorScheme.surfaceContainerHighest;
    final errorColor = Theme.of(context).colorScheme.error;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

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
                  style: TextStyle(
                    color: over ? errorColor : muted,
                    fontSize: 12,
                  ),
                ),
                Text(
                  ' / $currency${NumberFormat('#,##0.00', 'es').format(target)}',
                  style: TextStyle(
                    color: over ? errorColor : muted,
                    fontSize: 12,
                  ),
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
              backgroundColor: trackBg,
              valueColor: AlwaysStoppedAnimation(over ? errorColor : onSurface),
            ),
          ),
        ),
      ],
    );
  }
}

// Floating pair of circular buttons at the bottom - the reference app's
// "add operation" bar, adapted to our two entry points (income/expense)
// since we don't have scan/voice capture in the Flutter client yet.
class _BottomActionBar extends StatefulWidget {
  final ApiClient api;
  final List<CategoryOption> categories;
  final VoidCallback onDone;
  final int year;
  final int month;
  const _BottomActionBar({
    required this.api,
    required this.categories,
    required this.onDone,
    required this.year,
    required this.month,
  });

  @override
  State<_BottomActionBar> createState() => _BottomActionBarState();
}

class _BottomActionBarState extends State<_BottomActionBar> {
  Future<void> _addExpense() async {
    if (widget.categories.isEmpty) return;
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => AddExpenseSheet(
        api: widget.api,
        categories: widget.categories,
        year: widget.year,
        month: widget.month,
      ),
    );
    if (result == true) widget.onDone();
  }

  Future<void> _addIncome() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => AddIncomeSheet(
        api: widget.api,
        year: widget.year,
        month: widget.month,
      ),
    );
    if (result == true) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: 'addIncome',
          backgroundColor: scheme.surface,
          foregroundColor: scheme.onSurface,
          elevation: 1,
          onPressed: _addIncome,
          child: const Icon(Icons.arrow_downward),
        ),
        const SizedBox(width: 12),
        FloatingActionButton.extended(
          heroTag: 'addExpense',
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          onPressed: _addExpense,
          icon: const Icon(Icons.add),
          label: const Text('Gasto'),
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
          Text(
            message,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}
