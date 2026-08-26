import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api_client.dart';
import '../widgets/animated_money.dart';
import '../widgets/category_badge.dart';

class GoalsScreen extends StatefulWidget {
  final ApiClient api;
  const GoalsScreen({super.key, required this.api});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  List<GoalEntry>? _goals;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final goals = await widget.api.getGoals();
      setState(() => _goals = goals);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'No se pudo conectar. Revisa tu conexión.');
    }
  }

  String _money(double v) => '\$${NumberFormat('#,##0.00', 'es').format(v)}';

  Future<void> _addFunds(GoalEntry goal) async {
    final controller = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Aportar a "${goal.name}"'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Monto'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              final v = double.tryParse(controller.text.replaceAll(',', '.'));
              Navigator.pop(context, v);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (amount == null || amount <= 0) return;
    try {
      await widget.api.addGoalContribution(goal.categoryId, amount);
      _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(title: const Text('Metas')),
      body: _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, style: TextStyle(color: muted)),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: _load, child: const Text('Reintentar')),
                ],
              ),
            )
          : _goals == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _goals!.isEmpty
                  ? ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(32, 96, 32, 32),
                          child: Column(
                            children: [
                              Icon(Icons.flag_outlined, size: 40, color: muted.withValues(alpha: 0.5)),
                              const SizedBox(height: 12),
                              Text(
                                'Aún no tienes metas de ahorro.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _goals!.length,
                      itemBuilder: (context, i) {
                        final g = _goals![i];
                        final pct = (g.progressPct / 100).clamp(0, 1).toDouble();
                        final trackBg = Theme.of(context).colorScheme.surfaceContainerHighest;
                        final onSurface = Theme.of(context).colorScheme.onSurface;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          CategoryBadge(categoryId: g.categoryId, iconValue: g.emoji, size: 32),
                                          const SizedBox(width: 10),
                                          Flexible(
                                            child: Text(
                                              g.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (g.completed)
                                      const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    AnimatedPercent(
                                      value: g.progressPct,
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                    Row(
                                      children: [
                                        AnimatedMoney(
                                          value: g.saved,
                                          style: TextStyle(color: muted, fontSize: 12),
                                        ),
                                        Text(
                                          ' de ${_money(g.targetAmount)}',
                                          style: TextStyle(color: muted, fontSize: 12),
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
                                      valueColor: AlwaysStoppedAnimation(
                                        g.completed ? Colors.greenAccent : onSurface,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Falta: ${_money(g.remaining)}',
                                  style: TextStyle(color: muted, fontSize: 12),
                                ),
                                if (g.monthlyNeeded != null && g.monthsLeft != null && !g.completed)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: trackBg,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Ahorra ${_money(g.monthlyNeeded!)}/mes durante ${g.monthsLeft} '
                                        '${g.monthsLeft == 1 ? "mes" : "meses"}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ),
                                if (!g.completed) ...[
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: () => _addFunds(g),
                                      icon: const Icon(Icons.savings_outlined, size: 18),
                                      label: const Text('Agregar aporte'),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
