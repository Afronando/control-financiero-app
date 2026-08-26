import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

  String _money(double v) => '\$${NumberFormat('#,##0.00', 'es').format(v)}';

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final error = Theme.of(context).colorScheme.error;
    return Scaffold(
      appBar: const GlassAppBar(title: Text('Transacciones')),
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
                        ElevatedButton(
                          onPressed: _load,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  )
                : _transactions == null
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _transactions!.isEmpty
                        ? ListView(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(32, 96, 32, 32),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.receipt_long_outlined,
                                      size: 40,
                                      color: muted.withValues(alpha: 0.5),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Aún no registras transacciones este mes.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: muted),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                            itemCount: _transactions!.length,
                            itemBuilder: (context, i) {
                              final t = _transactions![i];
                              return FadeSlideIn(
                                index: i,
                                child: Dismissible(
                                  key: ValueKey(t.id),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.symmetric(horizontal: 20),
                                    decoration: BoxDecoration(
                                      color: error.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(Icons.delete_outline, color: error),
                                  ),
                                  onDismissed: (_) => _delete(t),
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
                                      subtitle: Text(
                                        [
                                          t.date,
                                          if (t.concept.isNotEmpty) t.concept,
                                          t.paymentMethod == 'credito' ? 'Crédito' : 'Débito',
                                        ].join(' · '),
                                      ),
                                      trailing: Text(
                                        _money(t.amount),
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ),
      ),
    );
  }
}
