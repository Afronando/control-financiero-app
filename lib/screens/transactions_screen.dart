import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api_client.dart';
import '../constants.dart';
import '../widgets/add_expense_sheet.dart';

class TransactionsScreen extends StatefulWidget {
  final ApiClient api;
  const TransactionsScreen({super.key, required this.api});

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
      final results = await Future.wait([widget.api.getTransactions(), widget.api.getCategories()]);
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
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => AddExpenseSheet(api: widget.api, categories: _categories),
    );
    if (result == true) _load();
  }

  String _money(double v) => '\$${NumberFormat('#,##0.00', 'es').format(v)}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transacciones')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddExpense,
        icon: const Icon(Icons.add),
        label: const Text('Agregar gasto'),
      ),
      body: _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, style: const TextStyle(color: Colors.white60)),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: _load, child: const Text('Reintentar')),
                ],
              ),
            )
          : _transactions == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _transactions!.isEmpty
                  ? ListView(
                      children: const [
                        Padding(
                          padding: EdgeInsets.fromLTRB(32, 96, 32, 32),
                          child: Column(
                            children: [
                              Icon(Icons.receipt_long_outlined, size: 40, color: Colors.white24),
                              SizedBox(height: 12),
                              Text(
                                'Aún no registras transacciones este mes.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white60),
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
                        return Dismissible(
                          key: ValueKey(t.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          ),
                          onDismissed: (_) => _delete(t),
                          child: Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.white10,
                                child: categoryIcon(t.category.emoji, size: 18),
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
                        );
                      },
                    ),
            ),
    );
  }
}
