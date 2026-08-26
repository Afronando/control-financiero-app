import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Points at the production Control Financiero deployment's /api/mobile/*
// routes (see src/app/api/mobile in the Next.js repo). Swap for
// http://10.0.2.2:3000 (Android emulator's alias for the host's localhost)
// when developing against a local `npm run dev` instead.
const String apiBaseUrl = 'https://control-financiero-lyart-xi.vercel.app';

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);
  @override
  String toString() => message;
}

class DashboardData {
  final int year;
  final int month;
  final String currency;
  final double income;
  final double totalExpenses;
  final double totalDebt;
  final double disponible;
  final double spendingLimit;
  final double safeToSpendPerDay;
  final int daysRemaining;
  final List<GroupTotal> groups;
  final List<TransactionEntry> recentTransactions;

  DashboardData({
    required this.year,
    required this.month,
    required this.currency,
    required this.income,
    required this.totalExpenses,
    required this.totalDebt,
    required this.disponible,
    required this.spendingLimit,
    required this.safeToSpendPerDay,
    required this.daysRemaining,
    required this.groups,
    required this.recentTransactions,
  });

  factory DashboardData.fromJson(Map<String, dynamic> j) => DashboardData(
    year: j['year'],
    month: j['month'],
    currency: j['currency'],
    income: (j['income'] as num).toDouble(),
    totalExpenses: (j['totalExpenses'] as num).toDouble(),
    totalDebt: (j['totalDebt'] as num).toDouble(),
    disponible: (j['disponible'] as num).toDouble(),
    spendingLimit: (j['spendingLimit'] as num).toDouble(),
    safeToSpendPerDay: (j['safeToSpendPerDay'] as num).toDouble(),
    daysRemaining: j['daysRemaining'],
    groups: (j['groups'] as List).map((g) => GroupTotal.fromJson(g)).toList(),
    recentTransactions: (j['recentTransactions'] as List)
        .map((t) => TransactionEntry.fromJson(t))
        .toList(),
  );
}

class GroupTotal {
  final String group;
  final double actual;
  final double targetAmount;
  GroupTotal({required this.group, required this.actual, required this.targetAmount});
  factory GroupTotal.fromJson(Map<String, dynamic> j) => GroupTotal(
    group: j['group'],
    actual: (j['actual'] as num).toDouble(),
    targetAmount: (j['targetAmount'] as num).toDouble(),
  );
}

class CategoryOption {
  final String id;
  final String name;
  final String emoji;
  final String group;
  CategoryOption({required this.id, required this.name, required this.emoji, required this.group});
  factory CategoryOption.fromJson(Map<String, dynamic> j) =>
      CategoryOption(id: j['id'], name: j['name'], emoji: j['emoji'], group: j['group']);
}

class TransactionEntry {
  final String id;
  final double amount;
  final String date;
  final String concept;
  final String paymentMethod;
  final CategoryOption category;
  TransactionEntry({
    required this.id,
    required this.amount,
    required this.date,
    required this.concept,
    required this.paymentMethod,
    required this.category,
  });
  factory TransactionEntry.fromJson(Map<String, dynamic> j) => TransactionEntry(
    id: j['id'],
    amount: (j['amount'] as num).toDouble(),
    date: j['date'],
    concept: j['concept'] ?? '',
    paymentMethod: j['paymentMethod'] ?? 'debito',
    category: CategoryOption.fromJson(j['category']),
  );
}

class BudgetCategoryLine {
  final String categoryId;
  final String name;
  final String emoji;
  final String group;
  final double estimated;
  final double actual;
  final int alertThresholdPct;
  BudgetCategoryLine({
    required this.categoryId,
    required this.name,
    required this.emoji,
    required this.group,
    required this.estimated,
    required this.actual,
    required this.alertThresholdPct,
  });
  factory BudgetCategoryLine.fromJson(Map<String, dynamic> j) => BudgetCategoryLine(
    categoryId: j['categoryId'],
    name: j['name'],
    emoji: j['emoji'],
    group: j['group'],
    estimated: (j['estimated'] as num).toDouble(),
    actual: (j['actual'] as num).toDouble(),
    alertThresholdPct: j['alertThresholdPct'],
  );
}

class GoalEntry {
  final String categoryId;
  final String name;
  final String emoji;
  final double targetAmount;
  final String? targetDate;
  final bool completed;
  final double saved;
  final double remaining;
  final double progressPct;
  final int? monthsLeft;
  final double? monthlyNeeded;
  GoalEntry({
    required this.categoryId,
    required this.name,
    required this.emoji,
    required this.targetAmount,
    required this.targetDate,
    required this.completed,
    required this.saved,
    required this.remaining,
    required this.progressPct,
    required this.monthsLeft,
    required this.monthlyNeeded,
  });
  factory GoalEntry.fromJson(Map<String, dynamic> j) => GoalEntry(
    categoryId: j['categoryId'],
    name: j['name'],
    emoji: j['emoji'],
    targetAmount: (j['targetAmount'] as num).toDouble(),
    targetDate: j['targetDate'],
    completed: j['completed'],
    saved: (j['saved'] as num).toDouble(),
    remaining: (j['remaining'] as num).toDouble(),
    progressPct: (j['progressPct'] as num).toDouble(),
    monthsLeft: j['monthsLeft'],
    monthlyNeeded: (j['monthlyNeeded'] as num?)?.toDouble(),
  );
}

class DebtEntry {
  final String categoryId;
  final String name;
  final String emoji;
  final bool active;
  final double monthlyPayment;
  final double? totalOwed;
  final double paid;
  final double? remaining;
  DebtEntry({
    required this.categoryId,
    required this.name,
    required this.emoji,
    required this.active,
    required this.monthlyPayment,
    required this.totalOwed,
    required this.paid,
    required this.remaining,
  });
  factory DebtEntry.fromJson(Map<String, dynamic> j) => DebtEntry(
    categoryId: j['categoryId'],
    name: j['name'],
    emoji: j['emoji'],
    active: j['active'],
    monthlyPayment: (j['monthlyPayment'] as num).toDouble(),
    totalOwed: (j['totalOwed'] as num?)?.toDouble(),
    paid: (j['paid'] as num).toDouble(),
    remaining: (j['remaining'] as num?)?.toDouble(),
  );
}

class ApiClient {
  String? _token;

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('mobile_token');
  }

  bool get isLoggedIn => _token != null;

  Map<String, String> get _authHeaders => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  Future<void> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('$apiBaseUrl/api/mobile/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password, 'deviceName': 'Flutter app'}),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw ApiException(body['error'] ?? 'Error al iniciar sesión', res.statusCode);
    }
    _token = body['token'];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mobile_token', _token!);
  }

  Future<void> logout() async {
    if (_token != null) {
      await http.post(
        Uri.parse('$apiBaseUrl/api/mobile/auth/logout'),
        headers: _authHeaders,
      );
    }
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('mobile_token');
  }

  Future<DashboardData> getDashboard() async {
    final res = await http.get(Uri.parse('$apiBaseUrl/api/mobile/dashboard'), headers: _authHeaders);
    if (res.statusCode == 401) throw ApiException('Sesión expirada', 401);
    if (res.statusCode != 200) throw ApiException('No se pudo cargar el dashboard', res.statusCode);
    return DashboardData.fromJson(jsonDecode(res.body));
  }

  Future<List<CategoryOption>> getCategories() async {
    final res = await http.get(Uri.parse('$apiBaseUrl/api/mobile/categories'), headers: _authHeaders);
    if (res.statusCode == 401) throw ApiException('Sesión expirada', 401);
    if (res.statusCode != 200) throw ApiException('No se pudieron cargar las categorías', res.statusCode);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['categories'] as List).map((c) => CategoryOption.fromJson(c)).toList();
  }

  Future<void> addTransaction({
    required String categoryId,
    required double amount,
    String? concept,
    String paymentMethod = 'debito',
  }) async {
    final res = await http.post(
      Uri.parse('$apiBaseUrl/api/mobile/transactions'),
      headers: _authHeaders,
      body: jsonEncode({
        'categoryId': categoryId,
        'amount': amount,
        'concept': concept ?? '',
        'paymentMethod': paymentMethod,
      }),
    );
    if (res.statusCode == 401) throw ApiException('Sesión expirada', 401);
    if (res.statusCode != 201) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw ApiException(body['error'] ?? 'No se pudo guardar el gasto', res.statusCode);
    }
  }

  Future<List<TransactionEntry>> getTransactions({int? year, int? month}) async {
    final qs = (year != null && month != null) ? '?year=$year&month=$month' : '';
    final res = await http.get(
      Uri.parse('$apiBaseUrl/api/mobile/transactions$qs'),
      headers: _authHeaders,
    );
    if (res.statusCode == 401) throw ApiException('Sesión expirada', 401);
    if (res.statusCode != 200) throw ApiException('No se pudieron cargar las transacciones', res.statusCode);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['transactions'] as List).map((t) => TransactionEntry.fromJson(t)).toList();
  }

  Future<void> deleteTransaction(String id) async {
    final res = await http.delete(
      Uri.parse('$apiBaseUrl/api/mobile/transactions/$id'),
      headers: _authHeaders,
    );
    if (res.statusCode == 401) throw ApiException('Sesión expirada', 401);
    if (res.statusCode != 200) throw ApiException('No se pudo eliminar', res.statusCode);
  }

  Future<List<BudgetCategoryLine>> getBudget() async {
    final res = await http.get(Uri.parse('$apiBaseUrl/api/mobile/budget'), headers: _authHeaders);
    if (res.statusCode == 401) throw ApiException('Sesión expirada', 401);
    if (res.statusCode != 200) throw ApiException('No se pudo cargar el presupuesto', res.statusCode);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['categories'] as List).map((c) => BudgetCategoryLine.fromJson(c)).toList();
  }

  Future<void> setBudgetEstimated(String categoryId, double estimated) async {
    final res = await http.patch(
      Uri.parse('$apiBaseUrl/api/mobile/budget'),
      headers: _authHeaders,
      body: jsonEncode({'categoryId': categoryId, 'estimated': estimated}),
    );
    if (res.statusCode == 401) throw ApiException('Sesión expirada', 401);
    if (res.statusCode != 200) throw ApiException('No se pudo actualizar el presupuesto', res.statusCode);
  }

  Future<List<GoalEntry>> getGoals() async {
    final res = await http.get(Uri.parse('$apiBaseUrl/api/mobile/goals'), headers: _authHeaders);
    if (res.statusCode == 401) throw ApiException('Sesión expirada', 401);
    if (res.statusCode != 200) throw ApiException('No se pudieron cargar las metas', res.statusCode);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['goals'] as List).map((g) => GoalEntry.fromJson(g)).toList();
  }

  Future<void> addGoalContribution(String categoryId, double amount, {String? concept}) async {
    final res = await http.post(
      Uri.parse('$apiBaseUrl/api/mobile/goals'),
      headers: _authHeaders,
      body: jsonEncode({'categoryId': categoryId, 'amount': amount, 'concept': concept ?? ''}),
    );
    if (res.statusCode == 401) throw ApiException('Sesión expirada', 401);
    if (res.statusCode != 201) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw ApiException(body['error'] ?? 'No se pudo guardar el aporte', res.statusCode);
    }
  }

  Future<List<DebtEntry>> getDebts() async {
    final res = await http.get(Uri.parse('$apiBaseUrl/api/mobile/debts'), headers: _authHeaders);
    if (res.statusCode == 401) throw ApiException('Sesión expirada', 401);
    if (res.statusCode != 200) throw ApiException('No se pudieron cargar las deudas', res.statusCode);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['debts'] as List).map((d) => DebtEntry.fromJson(d)).toList();
  }
}
