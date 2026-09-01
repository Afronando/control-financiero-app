import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api_client.dart';
import '../debt_projection.dart';
import '../widgets/category_badge.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/glass.dart';

class DebtsScreen extends StatefulWidget {
  final ApiClient api;
  const DebtsScreen({super.key, required this.api});

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen> {
  List<DebtEntry>? _debts;
  String? _error;
  StrategyOrder _order = StrategyOrder.snowball;
  bool _showSimulator = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final debts = await widget.api.getDebts();
      setState(() => _debts = debts);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'No se pudo conectar. Revisa tu conexión.');
    }
  }

  String _money(double v) => '\$${NumberFormat('#,##0.00', 'es').format(v)}';

  Future<void> _addDebt() async {
    final result = await showGlassSheet<bool>(context: context, builder: (_) => _AddDebtSheet(api: widget.api));
    if (result == true) {
      _load();
      if (mounted) AppToast.success(context, 'Deuda agregada');
    }
  }

  Future<void> _editDebt(DebtEntry d) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _EditDebtDialog(api: widget.api, debt: d),
    );
    if (result == true) {
      _load();
      if (mounted) AppToast.success(context, 'Deuda actualizada');
    }
  }

  Future<void> _toggleActive(DebtEntry d) async {
    try {
      await widget.api.setDebtActive(d.categoryId, !d.active);
      _load();
      if (mounted) AppToast.success(context, d.active ? 'Deuda pausada' : 'Deuda reactivada');
    } on ApiException catch (e) {
      if (mounted) AppToast.error(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: GlassAppBar(
        title: const Text('Deudas'),
        actions: [
          IconButton(
            icon: Icon(_showSimulator ? Icons.list : Icons.trending_down),
            tooltip: 'Simulador de estrategia',
            onPressed: () => setState(() => _showSimulator = !_showSimulator),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      floatingActionButton: PressableScale(
        onTap: _addDebt,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: AppGradients.accent,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [BoxShadow(color: AppGradients.purple.withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 10))],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, color: Colors.white),
              SizedBox(width: 6),
              Text('Deuda', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
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
                : _debts == null
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _debts!.isEmpty
                        ? ListView(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(32, 96, 32, 32),
                                child: Column(
                                  children: [
                                    Icon(Icons.credit_card_off_outlined, size: 40, color: muted.withValues(alpha: 0.5)),
                                    const SizedBox(height: 12),
                                    Text('No tienes deudas registradas.', textAlign: TextAlign.center, style: TextStyle(color: muted)),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              if (_showSimulator) ...[
                                _StrategySimulator(debts: _debts!, order: _order, onOrderChanged: (o) => setState(() => _order = o)),
                                const SizedBox(height: 16),
                              ],
                              for (int i = 0; i < _debts!.length; i++)
                                FadeSlideIn(
                                  index: i,
                                  child: _DebtCard(
                                    debt: _debts![i],
                                    money: _money,
                                    onTap: () => _editDebt(_debts![i]),
                                    onToggleActive: () => _toggleActive(_debts![i]),
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

class _DebtCard extends StatelessWidget {
  final DebtEntry debt;
  final String Function(double) money;
  final VoidCallback onTap;
  final VoidCallback onToggleActive;
  const _DebtCard({required this.debt, required this.money, required this.onTap, required this.onToggleActive});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final d = debt;
    final pct = (d.totalOwed != null && d.totalOwed! > 0) ? (d.paid / d.totalOwed!).clamp(0, 1).toDouble() : null;
    final trackBg = Theme.of(context).colorScheme.surfaceContainerHighest;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CategoryBadge(categoryId: d.categoryId, iconValue: d.emoji, size: 32),
              const SizedBox(width: 10),
              Expanded(child: Text(d.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16))),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 20, color: muted),
                onSelected: (_) => onToggleActive(),
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'toggle', child: Text(d.active ? 'Pausar' : 'Reactivar')),
                ],
              ),
              if (!d.active)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: trackBg, borderRadius: BorderRadius.circular(20)),
                  child: Text('Pausada', style: TextStyle(fontSize: 11, color: muted)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (d.totalOwed != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Pagado: ${money(d.paid)}', style: TextStyle(fontSize: 12, color: muted)),
                Text('Total: ${money(d.totalOwed!)}', style: TextStyle(fontSize: 12, color: muted)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: pct ?? 0),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (context, animatedPct, _) => Stack(
                  children: [
                    Container(height: 8, color: trackBg),
                    FractionallySizedBox(
                      widthFactor: animatedPct,
                      child: Container(height: 8, decoration: const BoxDecoration(gradient: AppGradients.accent)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text('Falta: ${money(d.remaining ?? 0)}', style: TextStyle(fontSize: 12, color: muted)),
          ] else
            Text('Pagado hasta ahora: ${money(d.paid)}', style: TextStyle(color: muted)),
          const SizedBox(height: 4),
          Text('Pago mensual: ${money(d.monthlyPayment)}', style: TextStyle(fontSize: 12, color: muted)),
        ],
      ),
    );
  }
}

class _StrategySimulator extends StatelessWidget {
  final List<DebtEntry> debts;
  final StrategyOrder order;
  final ValueChanged<StrategyOrder> onOrderChanged;
  const _StrategySimulator({required this.debts, required this.order, required this.onOrderChanged});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final simDebts = debts
        .where((d) => d.active && d.remaining != null)
        .map((d) => SimDebt(id: d.categoryId, name: d.name, remaining: d.remaining!, monthlyPayment: d.monthlyPayment))
        .toList();
    final result = simulateDebtStrategy(simDebts, order);
    final byId = {for (final d in simDebts) d.id: d};

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Simulador de estrategia', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          SegmentedButton<StrategyOrder>(
            segments: const [
              ButtonSegment(value: StrategyOrder.snowball, label: Text('Bola de nieve')),
              ButtonSegment(value: StrategyOrder.avalanche, label: Text('Avalancha')),
            ],
            selected: {order},
            onSelectionChanged: (s) => onOrderChanged(s.first),
          ),
          const SizedBox(height: 12),
          if (!result.solvable || simDebts.isEmpty)
            Text('Agrega un pago mensual a tus deudas activas para simular.', style: TextStyle(color: muted, fontSize: 13))
          else ...[
            if (result.totalMonths != null)
              Text(
                'Liquidarías todo en ${result.totalMonths} meses siguiendo este orden:',
                style: TextStyle(color: muted, fontSize: 13),
              ),
            const SizedBox(height: 10),
            for (int i = 0; i < result.order.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(gradient: AppGradients.accent, shape: BoxShape.circle),
                      child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(byId[result.order[i]]?.name ?? '', style: const TextStyle(fontWeight: FontWeight.w500))),
                    Text(
                      result.payoffMonth[result.order[i]] != null ? 'mes ${result.payoffMonth[result.order[i]]}' : '',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _AddDebtSheet extends StatefulWidget {
  final ApiClient api;
  const _AddDebtSheet({required this.api});

  @override
  State<_AddDebtSheet> createState() => _AddDebtSheetState();
}

class _AddDebtSheetState extends State<_AddDebtSheet> {
  final _nameController = TextEditingController();
  final _paymentController = TextEditingController();
  final _totalController = TextEditingController();
  bool _saving = false;
  String? _error;

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final payment = double.tryParse(_paymentController.text.replaceAll(',', '.'));
    if (name.isEmpty || payment == null || payment < 0) {
      setState(() => _error = 'Ingresa un nombre y un pago mensual válidos');
      return;
    }
    final total = _totalController.text.trim().isEmpty ? null : double.tryParse(_totalController.text.replaceAll(',', '.'));
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.addDebt(name: name, monthlyPayment: payment, totalOwed: total);
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
          const Text('Agregar deuda', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nombre'), autofocus: true),
          const SizedBox(height: 12),
          TextField(
            controller: _paymentController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Pago mensual'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _totalController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Total adeudado (opcional)'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 16),
          GradientButton(label: 'Guardar deuda', loading: _saving, onPressed: _saving ? null : _submit),
        ],
      ),
    );
  }
}

class _EditDebtDialog extends StatefulWidget {
  final ApiClient api;
  final DebtEntry debt;
  const _EditDebtDialog({required this.api, required this.debt});

  @override
  State<_EditDebtDialog> createState() => _EditDebtDialogState();
}

class _EditDebtDialogState extends State<_EditDebtDialog> {
  late final _paymentController = TextEditingController(text: widget.debt.monthlyPayment.toStringAsFixed(2));
  late final _totalController = TextEditingController(text: widget.debt.totalOwed?.toStringAsFixed(2) ?? '');
  String? _error;
  bool _saving = false;

  Future<void> _save() async {
    final payment = double.tryParse(_paymentController.text.replaceAll(',', '.'));
    if (payment == null || payment < 0) {
      setState(() => _error = 'Ingresa un pago mensual válido');
      return;
    }
    final totalText = _totalController.text.trim();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.updateDebt(
        widget.debt.categoryId,
        monthlyPayment: payment,
        totalOwed: totalText.isEmpty ? null : double.tryParse(totalText.replaceAll(',', '.')),
        clearTotalOwed: totalText.isEmpty,
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.debt.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _paymentController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Pago mensual'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _totalController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Total adeudado (vacío = no rastrear)'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        TextButton(onPressed: _saving ? null : _save, child: const Text('Guardar')),
      ],
    );
  }
}
