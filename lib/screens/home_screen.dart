import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api_client.dart';
import '../constants.dart';
import '../theme_controller.dart';
import '../widgets/add_expense_sheet.dart';
import '../widgets/add_income_sheet.dart';
import '../widgets/animated_money.dart';
import '../widgets/category_badge.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/glass.dart';
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
  int _rowIndex = 0;

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
      SlideFadeRoute(
        page: LoginScreen(api: widget.api, themeController: widget.themeController),
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
      body: AppBackground(
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? _ErrorView(message: _error!, onRetry: _load)
              : RefreshIndicator(onRefresh: _load, child: _buildBody()),
        ),
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
    _rowIndex = 0;

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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Disponible este mes', style: TextStyle(color: muted, fontSize: 13)),
              if (d.savingsStreak > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_fire_department, size: 13, color: Colors.orange),
                      const SizedBox(width: 2),
                      Text('${d.savingsStreak}', style: const TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ],
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
        if (d.household != null) ...[
          const SizedBox(height: 20),
          _HouseholdCard(household: d.household!, currency: d.currency),
        ],
        const SizedBox(height: 28),
        GlassCard(
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
        if (d.groups.any((g) => g.actual > 0)) ...[
          const SizedBox(height: 20),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Distribución de gastos', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                _GroupPieChart(groups: d.groups),
              ],
            ),
          ),
        ],
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
            FadeSlideIn(
              index: _rowIndex++,
              child: GlassCard(
                blur: false,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
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
    return GlassIconButton(icon: icon, onTap: onTap, size: 38, iconSize: 18);
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
            builder: (context, animatedPct, _) => Stack(
              children: [
                Container(height: 8, color: trackBg),
                FractionallySizedBox(
                  widthFactor: animatedPct,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: over ? null : AppGradients.accent,
                      color: over ? errorColor : null,
                    ),
                  ),
                ),
              ],
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
    final result = await showGlassSheet<bool>(
      context: context,
      builder: (_) => AddExpenseSheet(
        api: widget.api,
        categories: widget.categories,
        year: widget.year,
        month: widget.month,
      ),
    );
    if (result == true) {
      widget.onDone();
      if (mounted) AppToast.success(context, 'Gasto agregado');
    }
  }

  Future<void> _addIncome() async {
    final result = await showGlassSheet<bool>(
      context: context,
      builder: (_) => AddIncomeSheet(
        api: widget.api,
        year: widget.year,
        month: widget.month,
      ),
    );
    if (result == true) {
      widget.onDone();
      if (mounted) AppToast.success(context, 'Ingreso agregado');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GlassIconButton(icon: Icons.arrow_downward, onTap: _addIncome, size: 56, iconSize: 22),
        const SizedBox(width: 12),
        PressableScale(
          onTap: _addExpense,
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: AppGradients.accent,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(color: AppGradients.purple.withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 10)),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, color: Colors.white),
                SizedBox(width: 6),
                Text('Gasto', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HouseholdCard extends StatelessWidget {
  final HouseholdTotals household;
  final String currency;
  const _HouseholdCard({required this.household, required this.currency});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.favorite, size: 16, color: Colors.pinkAccent),
              const SizedBox(width: 6),
              const Text('En pareja', style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _HouseholdStat(label: 'Ingresos', value: household.income, currency: currency),
              _HouseholdStat(label: 'Gastos', value: household.gastos, currency: currency),
              _HouseholdStat(label: 'Deudas', value: household.deudas, currency: currency),
              _HouseholdStat(label: 'Disponible', value: household.disponible, currency: currency, emphasize: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _HouseholdStat extends StatelessWidget {
  final String label;
  final double value;
  final String currency;
  final bool emphasize;
  const _HouseholdStat({required this.label, required this.value, required this.currency, this.emphasize = false});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: muted, fontSize: 11)),
        const SizedBox(height: 2),
        AnimatedMoney(
          value: value,
          currency: currency,
          style: TextStyle(fontSize: 13, fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600),
        ),
      ],
    );
  }
}

class _GroupPieChart extends StatelessWidget {
  final List<GroupTotal> groups;
  const _GroupPieChart({required this.groups});

  static const _colors = {
    'necesidad': AppGradients.violet,
    'deseo': AppGradients.purple,
    'futuro': AppGradients.cyan,
    'deuda': Color(0xFFEF4444),
  };

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final spendable = groups.where((g) => g.actual > 0).toList();
    final total = spendable.fold<double>(0, (s, g) => s + g.actual);
    if (total <= 0) return const SizedBox.shrink();

    return Row(
      children: [
        SizedBox(
          height: 120,
          width: 120,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 34,
              sections: [
                for (final g in spendable)
                  PieChartSectionData(
                    value: g.actual,
                    color: _colors[g.group] ?? muted,
                    showTitle: false,
                    radius: 26,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final g in spendable)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: _colors[g.group] ?? muted, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(groupLabels[g.group] ?? g.group, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                      Text('${(g.actual / total * 100).round()}%', style: TextStyle(fontSize: 12, color: muted)),
                    ],
                  ),
                ),
            ],
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
