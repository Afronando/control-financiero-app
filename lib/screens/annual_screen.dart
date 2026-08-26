import 'package:flutter/material.dart';
import '../api_client.dart';
import '../widgets/animated_money.dart';

const _monthNames = [
  'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
];

class AnnualScreen extends StatefulWidget {
  final ApiClient api;
  const AnnualScreen({super.key, required this.api});

  @override
  State<AnnualScreen> createState() => _AnnualScreenState();
}

class _AnnualScreenState extends State<AnnualScreen> {
  AnnualSummary? _summary;
  String? _error;
  late int _year;

  @override
  void initState() {
    super.initState();
    _year = DateTime.now().year;
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final summary = await widget.api.getAnnualSummary(year: _year);
      setState(() => _summary = summary);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'No se pudo conectar. Revisa tu conexión.');
    }
  }

  void _changeYear(int delta) {
    setState(() {
      _year += delta;
      _summary = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _changeYear(-1)),
            Text('$_year'),
            IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _changeYear(1)),
          ],
        ),
      ),
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
          : _summary == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    final s = _summary!;
    final byMonth = {for (final m in s.months) m.month: m};
    final maxVal = s.months
        .expand((m) => [m.incomeActual, m.gastoActual, m.ahorroActual, m.deudaActual])
        .fold<double>(1, (a, b) => b > a ? b : a);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(child: _TotalCard(label: 'Ingresos', value: s.totalIncome, currency: s.currency)),
            const SizedBox(width: 10),
            Expanded(child: _TotalCard(label: 'Gastos', value: s.totalGasto, currency: s.currency)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _TotalCard(label: 'Ahorro', value: s.totalAhorro, currency: s.currency)),
            const SizedBox(width: 10),
            Expanded(child: _TotalCard(label: 'Deudas', value: s.totalDeuda, currency: s.currency)),
          ],
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ingresos vs. gastos por mes', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                SizedBox(
                  height: 160,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (int m = 1; m <= 12; m++)
                        Expanded(
                          child: _MonthBar(
                            income: byMonth[m]?.incomeActual ?? 0,
                            gasto: byMonth[m]?.gastoActual ?? 0,
                            maxVal: maxVal,
                            label: _monthNames[m - 1],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TotalCard extends StatelessWidget {
  final String label;
  final double value;
  final String currency;
  const _TotalCard({required this.label, required this.value, required this.currency});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
            const SizedBox(height: 4),
            AnimatedMoney(
              value: value,
              currency: currency,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthBar extends StatelessWidget {
  final double income;
  final double gasto;
  final double maxVal;
  final String label;
  const _MonthBar({required this.income, required this.gasto, required this.maxVal, required this.label});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final incomeH = maxVal > 0 ? (income / maxVal) * 120 : 0.0;
    final gastoH = maxVal > 0 ? (gasto / maxVal) * 120 : 0.0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          height: 120,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: incomeH),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (context, h, _) => Container(
                  width: 5,
                  height: h,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: onSurface,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: gastoH),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (context, h, _) => Container(
                  width: 5,
                  height: h,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(fontSize: 10, color: muted)),
      ],
    );
  }
}
