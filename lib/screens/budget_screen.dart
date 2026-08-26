import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api_client.dart';
import '../constants.dart';
import '../widgets/animated_money.dart';
import '../widgets/category_badge.dart';

class BudgetScreen extends StatefulWidget {
  final ApiClient api;
  final int? year;
  final int? month;
  const BudgetScreen({super.key, required this.api, this.year, this.month});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  List<BudgetCategoryLine>? _lines;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final lines = await widget.api.getBudget(year: widget.year, month: widget.month);
      setState(() => _lines = lines);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'No se pudo conectar. Revisa tu conexión.');
    }
  }

  String _money(double v) => '\$${NumberFormat('#,##0.00', 'es').format(v)}';

  Future<void> _editEstimated(BudgetCategoryLine line) async {
    final controller = TextEditingController(text: line.estimated.toStringAsFixed(2));
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            categoryIcon(line.emoji, size: 18),
            const SizedBox(width: 8),
            Text(line.name),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Presupuesto mensual'),
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
    if (result == null || result < 0) return;
    setState(() {
      final idx = _lines!.indexOf(line);
      _lines![idx] = BudgetCategoryLine(
        categoryId: line.categoryId,
        name: line.name,
        emoji: line.emoji,
        group: line.group,
        estimated: result,
        actual: line.actual,
        alertThresholdPct: line.alertThresholdPct,
      );
    });
    try {
      await widget.api.setBudgetEstimated(line.categoryId, result, year: widget.year, month: widget.month);
    } on ApiException {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(title: const Text('Presupuesto')),
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
          : _lines == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(onRefresh: _load, child: _buildGrouped()),
    );
  }

  Widget _buildGrouped() {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final error = Theme.of(context).colorScheme.error;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final trackBg = Theme.of(context).colorScheme.surfaceContainerHighest;

    final groups = <String, List<BudgetCategoryLine>>{};
    for (final l in _lines!) {
      (groups[l.group] ??= []).add(l);
    }
    const order = ['necesidad', 'deseo', 'futuro', 'deuda'];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final g in order)
          if (groups[g] != null && groups[g]!.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 8),
              child: Text(
                groupLabels[g] ?? g,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    for (final line in groups[g]!)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: InkWell(
                          onTap: () => _editEstimated(line),
                          borderRadius: BorderRadius.circular(8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CategoryBadge(categoryId: line.categoryId, iconValue: line.emoji, size: 34),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          line.name,
                                          style: const TextStyle(fontWeight: FontWeight.w500),
                                        ),
                                        Row(
                                          children: [
                                            AnimatedMoney(
                                              value: line.actual,
                                              style: TextStyle(
                                                color: line.actual > line.estimated && line.estimated > 0
                                                    ? error
                                                    : muted,
                                                fontSize: 12,
                                              ),
                                            ),
                                            Text(
                                              ' / ${_money(line.estimated)}',
                                              style: TextStyle(
                                                color: line.actual > line.estimated && line.estimated > 0
                                                    ? error
                                                    : muted,
                                                fontSize: 12,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Icon(Icons.edit, size: 14, color: muted.withValues(alpha: 0.6)),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: TweenAnimationBuilder<double>(
                                        tween: Tween(
                                          begin: 0,
                                          end: line.estimated > 0
                                              ? (line.actual / line.estimated).clamp(0, 1).toDouble()
                                              : 0,
                                        ),
                                        duration: const Duration(milliseconds: 700),
                                        curve: Curves.easeOutCubic,
                                        builder: (context, animatedPct, _) => LinearProgressIndicator(
                                          value: animatedPct,
                                          minHeight: 6,
                                          backgroundColor: trackBg,
                                          valueColor: AlwaysStoppedAnimation(
                                            line.actual > line.estimated && line.estimated > 0
                                                ? error
                                                : onSurface,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        const SizedBox(height: 60),
      ],
    );
  }
}
