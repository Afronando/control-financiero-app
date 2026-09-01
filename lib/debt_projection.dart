// Dart port of the web app's src/lib/debt-projection.ts. Assumes the
// monthly payment stays constant and 0% interest (this app doesn't track
// interest rates) - a straight-line projection, not an amortization
// schedule.

class SimDebt {
  final String id;
  final String name;
  final double remaining;
  final double monthlyPayment;
  SimDebt({required this.id, required this.name, required this.remaining, required this.monthlyPayment});
}

enum StrategyOrder { snowball, avalanche }

class StrategyResult {
  final List<String> order;
  final Map<String, int> payoffMonth;
  final int? totalMonths;
  final bool solvable;
  StrategyResult({required this.order, required this.payoffMonth, required this.totalMonths, required this.solvable});
}

// Snowball: smallest balance first (fastest early wins). Avalanche: largest
// balance first (since interest isn't tracked, this is a balance-based
// stand-in for "highest interest rate first"). Whichever debt is paid off
// first frees up its monthly payment, which rolls into the next debt in
// line - the classic debt-payoff-strategy mechanic.
StrategyResult simulateDebtStrategy(List<SimDebt> debts, StrategyOrder order) {
  final eligible = debts.where((d) => d.remaining > 0).toList();
  eligible.sort(
    (a, b) => order == StrategyOrder.snowball
        ? a.remaining.compareTo(b.remaining)
        : b.remaining.compareTo(a.remaining),
  );

  final balances = {for (final d in eligible) d.id: d.remaining};
  final payoffMonth = <String, int>{};
  double freed = 0;
  int month = 0;
  final hasAnyPayment = eligible.any((d) => d.monthlyPayment > 0);

  while (hasAnyPayment && balances.values.any((b) => b > 0.005) && month < 600) {
    month++;
    double extra = freed;
    freed = 0;
    for (final d in eligible) {
      final bal = balances[d.id]!;
      if (bal <= 0) continue;
      double pay = d.monthlyPayment;
      if (extra > 0) {
        pay += extra;
        extra = 0;
      }
      final newBal = (bal - pay).clamp(0, double.infinity).toDouble();
      balances[d.id] = newBal;
      if (newBal <= 0 && !payoffMonth.containsKey(d.id)) payoffMonth[d.id] = month;
    }
    freed = eligible.where((d) => (balances[d.id] ?? 0) <= 0).fold(0.0, (s, d) => s + d.monthlyPayment);
  }

  final totalMonths = payoffMonth.isNotEmpty ? payoffMonth.values.reduce((a, b) => a > b ? a : b) : null;

  return StrategyResult(
    order: eligible.map((d) => d.id).toList(),
    payoffMonth: payoffMonth,
    totalMonths: totalMonths,
    solvable: hasAnyPayment,
  );
}
