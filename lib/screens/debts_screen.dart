import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api_client.dart';
import '../widgets/category_badge.dart';

class DebtsScreen extends StatefulWidget {
  final ApiClient api;
  const DebtsScreen({super.key, required this.api});

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen> {
  List<DebtEntry>? _debts;
  String? _error;

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

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(title: const Text('Deudas')),
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
                              Text(
                                'No tienes deudas registradas.',
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
                      itemCount: _debts!.length,
                      itemBuilder: (context, i) {
                        final d = _debts![i];
                        final pct = (d.totalOwed != null && d.totalOwed! > 0)
                            ? (d.paid / d.totalOwed!).clamp(0, 1).toDouble()
                            : null;
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
                                  children: [
                                    CategoryBadge(categoryId: d.categoryId, iconValue: d.emoji, size: 32),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        d.name,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                                      ),
                                    ),
                                    if (!d.active)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: trackBg,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text('Pausada', style: TextStyle(fontSize: 11, color: muted)),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                if (d.totalOwed != null) ...[
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Pagado: ${_money(d.paid)}', style: TextStyle(fontSize: 12, color: muted)),
                                      Text('Total: ${_money(d.totalOwed!)}', style: TextStyle(fontSize: 12, color: muted)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: TweenAnimationBuilder<double>(
                                      tween: Tween(begin: 0, end: pct ?? 0),
                                      duration: const Duration(milliseconds: 700),
                                      curve: Curves.easeOutCubic,
                                      builder: (context, animatedPct, _) => LinearProgressIndicator(
                                        value: animatedPct,
                                        minHeight: 8,
                                        backgroundColor: trackBg,
                                        valueColor: AlwaysStoppedAnimation(onSurface),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Falta: ${_money(d.remaining ?? 0)}',
                                    style: TextStyle(fontSize: 12, color: muted),
                                  ),
                                ] else
                                  Text('Pagado hasta ahora: ${_money(d.paid)}', style: TextStyle(color: muted)),
                                const SizedBox(height: 4),
                                Text(
                                  'Pago mensual: ${_money(d.monthlyPayment)}',
                                  style: TextStyle(fontSize: 12, color: muted),
                                ),
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
