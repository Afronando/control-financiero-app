import 'package:flutter/material.dart';
import '../api_client.dart';

class AddExpenseSheet extends StatefulWidget {
  final ApiClient api;
  final List<CategoryOption> categories;
  const AddExpenseSheet({super.key, required this.api, required this.categories});

  @override
  State<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<AddExpenseSheet> {
  final _amountController = TextEditingController();
  final _conceptController = TextEditingController();
  CategoryOption? _selected;
  String _paymentMethod = 'debito';
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selected = widget.categories.first;
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0 || _selected == null) {
      setState(() => _error = 'Ingresa un monto y una categoría válidos');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.addTransaction(
        categoryId: _selected!.id,
        amount: amount,
        concept: _conceptController.text.trim(),
        paymentMethod: _paymentMethod,
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
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Agregar gasto', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
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
                .map((c) => DropdownMenuItem(value: c, child: Text('${c.emoji} ${c.name}')))
                .toList(),
            onChanged: (v) => setState(() => _selected = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _conceptController,
            decoration: const InputDecoration(labelText: 'Concepto (opcional)'),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'debito', label: Text('Débito')),
              ButtonSegment(value: 'credito', label: Text('Crédito')),
            ],
            selected: {_paymentMethod},
            onSelectionChanged: (s) => setState(() => _paymentMethod = s.first),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Guardar gasto'),
          ),
        ],
      ),
    );
  }
}
