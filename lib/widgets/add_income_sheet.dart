import 'package:flutter/material.dart';
import '../api_client.dart';
import 'glass.dart';

class AddIncomeSheet extends StatefulWidget {
  final ApiClient api;
  final int? year;
  final int? month;
  const AddIncomeSheet({super.key, required this.api, this.year, this.month});

  @override
  State<AddIncomeSheet> createState() => _AddIncomeSheetState();
}

class _AddIncomeSheetState extends State<AddIncomeSheet> {
  final _amountController = TextEditingController();
  final _conceptController = TextEditingController();
  bool _saving = false;
  String? _error;

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Ingresa un monto válido');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.addIncome(
        amount: amount,
        concept: _conceptController.text.trim(),
        year: widget.year,
        month: widget.month,
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
          const Text('Agregar ingreso', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Monto'),
            autofocus: true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _conceptController,
            decoration: const InputDecoration(labelText: 'Concepto (ej. Sueldo)'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 16),
          GradientButton(
            label: 'Guardar ingreso',
            loading: _saving,
            onPressed: _saving ? null : _submit,
          ),
        ],
      ),
    );
  }
}
