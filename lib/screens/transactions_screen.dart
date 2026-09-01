import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../api_client.dart';
import '../widgets/add_expense_sheet.dart';
import '../widgets/category_badge.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/glass.dart';

class TransactionsScreen extends StatefulWidget {
  final ApiClient api;
  final int? year;
  final int? month;
  const TransactionsScreen({
    super.key,
    required this.api,
    this.year,
    this.month,
  });

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  List<TransactionEntry>? _transactions;
  List<CategoryOption> _categories = [];
  String? _error;
  bool _showRecurring = false;
  final _searchController = TextEditingController();
  String? _categoryFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final results = await Future.wait([
        widget.api.getTransactions(year: widget.year, month: widget.month),
        widget.api.getCategories(),
      ]);
      setState(() {
        _transactions = results[0] as List<TransactionEntry>;
        _categories = results[1] as List<CategoryOption>;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'No se pudo conectar. Revisa tu conexión.');
    }
  }

  Future<void> _delete(TransactionEntry t) async {
    setState(() => _transactions?.removeWhere((x) => x.id == t.id));
    try {
      await widget.api.deleteTransaction(t.id);
    } on ApiException {
      _load();
    }
  }

  Future<void> _toggleFlag(TransactionEntry t) async {
    setState(() {
      final idx = _transactions!.indexOf(t);
      _transactions![idx] = TransactionEntry(
        id: t.id,
        amount: t.amount,
        date: t.date,
        concept: t.concept,
        paymentMethod: t.paymentMethod,
        flagged: !t.flagged,
        category: t.category,
      );
    });
    try {
      await widget.api.setTransactionFlagged(t.id, !t.flagged);
    } on ApiException {
      _load();
    }
  }

  Future<void> _openAddExpense() async {
    if (_categories.isEmpty) return;
    final result = await showGlassSheet<bool>(
      context: context,
      builder: (_) => AddExpenseSheet(
        api: widget.api,
        categories: _categories,
        year: widget.year,
        month: widget.month,
      ),
    );
    if (result == true) {
      _load();
      if (mounted) AppToast.success(context, 'Gasto agregado');
    }
  }

  List<TransactionEntry> get _filtered {
    if (_transactions == null) return [];
    final query = _searchController.text.trim().toLowerCase();
    return _transactions!.where((t) {
      if (_categoryFilter != null && t.category.id != _categoryFilter) return false;
      if (query.isEmpty) return true;
      return t.category.name.toLowerCase().contains(query) || t.concept.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _exportCsv() async {
    final rows = _filtered;
    if (rows.isEmpty) {
      AppToast.error(context, 'No hay transacciones para exportar');
      return;
    }
    final buffer = StringBuffer('﻿');
    buffer.writeln('Fecha,Categoría,Concepto,Monto,Método de pago');
    for (final t in rows) {
      String esc(String s) => '"${s.replaceAll('"', '""')}"';
      buffer.writeln(
        '${t.date},${esc(t.category.name)},${esc(t.concept)},${t.amount.toStringAsFixed(2)},${t.paymentMethod}',
      );
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/transacciones.csv');
    await file.writeAsString(buffer.toString());
    await Share.shareXFiles([XFile(file.path)], subject: 'Transacciones');
  }

  Future<void> _openRecurringAdd() async {
    if (_categories.isEmpty) return;
    final result = await showGlassSheet<bool>(context: context, builder: (_) => _AddRecurringSheet(api: widget.api, categories: _categories));
    if (result == true && mounted) AppToast.success(context, 'Gasto recurrente agregado');
  }

  String _money(double v) => '\$${NumberFormat('#,##0.00', 'es').format(v)}';

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final error = Theme.of(context).colorScheme.error;
    return Scaffold(
      appBar: GlassAppBar(
        title: const Text('Transacciones'),
        actions: [
          IconButton(icon: const Icon(Icons.ios_share), tooltip: 'Exportar CSV', onPressed: _exportCsv),
          IconButton(
            icon: Icon(_showRecurring ? Icons.receipt_long : Icons.repeat),
            tooltip: 'Recurrentes',
            onPressed: () => setState(() => _showRecurring = !_showRecurring),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      floatingActionButton: PressableScale(
        onTap: _openAddExpense,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: AppGradients.accent,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(color: AppGradients.purple.withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 10)),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, color: Colors.white),
              SizedBox(width: 6),
              Text('Agregar gasto', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
      body: AppBackground(
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(top: kToolbarHeight + MediaQuery.of(context).padding.top),
            child: _error != null
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
                : _transactions == null
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                      children: [
                        if (_showRecurring) ...[
                          _RecurringSection(api: widget.api, onAdd: _openRecurringAdd),
                          const SizedBox(height: 12),
                        ],
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: 'Buscar por categoría o concepto',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 36,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            children: [
                              _FilterChip(label: 'Todas', selected: _categoryFilter == null, onTap: () => setState(() => _categoryFilter = null)),
                              for (final c in _categories)
                                Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: _FilterChip(
                                    label: c.name,
                                    selected: _categoryFilter == c.id,
                                    onTap: () => setState(() => _categoryFilter = _categoryFilter == c.id ? null : c.id),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_filtered.isEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 64, 20, 32),
                            child: Column(
                              children: [
                                Icon(Icons.receipt_long_outlined, size: 40, color: muted.withValues(alpha: 0.5)),
                                const SizedBox(height: 12),
                                Text(
                                  _transactions!.isEmpty ? 'Aún no registras transacciones este mes.' : 'No hay resultados.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: muted),
                                ),
                              ],
                            ),
                          )
                        else
                          for (int i = 0; i < _filtered.length; i++)
                            FadeSlideIn(
                              index: i,
                              child: Dismissible(
                                key: ValueKey(_filtered[i].id),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  decoration: BoxDecoration(color: error.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                                  child: Icon(Icons.delete_outline, color: error),
                                ),
                                onDismissed: (_) => _delete(_filtered[i]),
                                child: GlassCard(
                                  blur: false,
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: CategoryBadge(categoryId: _filtered[i].category.id, iconValue: _filtered[i].category.emoji),
                                    title: Text(_filtered[i].category.name),
                                    subtitle: Text(
                                      [
                                        _filtered[i].date,
                                        if (_filtered[i].concept.isNotEmpty) _filtered[i].concept,
                                        _filtered[i].paymentMethod == 'credito' ? 'Crédito' : 'Débito',
                                      ].join(' · '),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        InkWell(
                                          onTap: () => _toggleFlag(_filtered[i]),
                                          borderRadius: BorderRadius.circular(20),
                                          child: Padding(
                                            padding: const EdgeInsets.all(4),
                                            child: Icon(
                                              _filtered[i].flagged ? Icons.flag : Icons.flag_outlined,
                                              size: 18,
                                              color: _filtered[i].flagged ? AppGradients.purple : muted,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(_money(_filtered[i].amount), style: const TextStyle(fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected ? AppGradients.accent : null,
          color: selected ? null : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _RecurringSection extends StatefulWidget {
  final ApiClient api;
  final VoidCallback onAdd;
  const _RecurringSection({required this.api, required this.onAdd});

  @override
  State<_RecurringSection> createState() => _RecurringSectionState();
}

class _RecurringSectionState extends State<_RecurringSection> {
  List<RecurringEntry>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await widget.api.getRecurring();
      if (mounted) setState(() => _items = items);
    } on ApiException {
      // keep quiet, this is a secondary section
    }
  }

  Future<void> _toggle(RecurringEntry r) async {
    try {
      await widget.api.setRecurringActive(r.id, !r.active);
      _load();
    } on ApiException catch (e) {
      if (mounted) AppToast.error(context, e.message);
    }
  }

  Future<void> _delete(RecurringEntry r) async {
    try {
      await widget.api.deleteRecurring(r.id);
      _load();
    } on ApiException catch (e) {
      if (mounted) AppToast.error(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final items = _items;
    final activeCount = items?.where((r) => r.active).length ?? 0;
    final pausedCount = (items?.length ?? 0) - activeCount;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Gastos recurrentes', style: TextStyle(fontWeight: FontWeight.w700))),
              TextButton.icon(onPressed: widget.onAdd, icon: const Icon(Icons.add, size: 16), label: const Text('Agregar')),
            ],
          ),
          if (items != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('Activas: $activeCount · Pausadas: $pausedCount', style: TextStyle(color: muted, fontSize: 12)),
            ),
          if (items == null)
            const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()))
          else if (items.isEmpty)
            Text('No tienes gastos recurrentes.', style: TextStyle(color: muted, fontSize: 13))
          else
            for (final r in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CategoryBadge(categoryId: r.category.id, iconValue: r.category.emoji, size: 32),
                  title: Text(r.category.name, style: TextStyle(decoration: r.active ? null : TextDecoration.lineThrough)),
                  subtitle: Text('Día ${r.dayOfMonth} · \$${r.amount.toStringAsFixed(2)}${r.concept.isNotEmpty ? ' · ${r.concept}' : ''}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(r.active ? Icons.pause_circle_outline : Icons.play_circle_outline, size: 20),
                        onPressed: () => _toggle(r),
                      ),
                      IconButton(icon: const Icon(Icons.delete_outline, size: 20), onPressed: () => _delete(r)),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _AddRecurringSheet extends StatefulWidget {
  final ApiClient api;
  final List<CategoryOption> categories;
  const _AddRecurringSheet({required this.api, required this.categories});

  @override
  State<_AddRecurringSheet> createState() => _AddRecurringSheetState();
}

class _AddRecurringSheetState extends State<_AddRecurringSheet> {
  final _amountController = TextEditingController();
  final _conceptController = TextEditingController();
  final _dayController = TextEditingController(text: '1');
  late CategoryOption _selected = widget.categories.first;
  bool _saving = false;
  String? _error;

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.'));
    final day = int.tryParse(_dayController.text) ?? 1;
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Ingresa un monto válido');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.addRecurring(
        categoryId: _selected.id,
        amount: amount,
        concept: _conceptController.text.trim(),
        dayOfMonth: day.clamp(1, 28),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Nuevo gasto recurrente', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Monto'),
            autofocus: true,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<CategoryOption>(
            initialValue: _selected,
            decoration: const InputDecoration(labelText: 'Categoría'),
            items: widget.categories
                .map(
                  (c) => DropdownMenuItem(
                    value: c,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CategoryBadge(categoryId: c.id, iconValue: c.emoji, size: 26),
                        const SizedBox(width: 8),
                        Text(c.name),
                      ],
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _selected = v!),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _dayController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Día del mes (1-28)'),
          ),
          const SizedBox(height: 12),
          TextField(controller: _conceptController, decoration: const InputDecoration(labelText: 'Concepto (opcional)')),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 16),
          GradientButton(label: 'Guardar', loading: _saving, onPressed: _saving ? null : _submit),
        ],
      ),
    );
  }
}
