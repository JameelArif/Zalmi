import 'package:supabase_flutter/supabase_flutter.dart';

class ExpenseCategory {
  final int id;
  final int adminId;
  final String name;
  final bool isDefault;

  ExpenseCategory({
    required this.id,
    required this.adminId,
    required this.name,
    required this.isDefault,
  });

  factory ExpenseCategory.fromJson(Map<String, dynamic> json) {
    return ExpenseCategory(
      id: (json['id'] as num).toInt(),
      adminId: (json['admin_id'] as num).toInt(),
      name: (json['name'] ?? '').toString(),
      isDefault: (json['is_default'] ?? false) as bool,
    );
  }
}

class ExpenseItem {
  final int id;
  final int adminId;
  final int categoryId;
  final String categoryName;
  final double amount;
  final DateTime expenseDate;
  final String? description;

  ExpenseItem({
    required this.id,
    required this.adminId,
    required this.categoryId,
    required this.categoryName,
    required this.amount,
    required this.expenseDate,
    required this.description,
  });

  factory ExpenseItem.fromJson(Map<String, dynamic> json) {
    return ExpenseItem(
      id: (json['id'] as num).toInt(),
      adminId: (json['admin_id'] as num).toInt(),
      categoryId: (json['category_id'] as num).toInt(),
      categoryName: (json['category_name'] ?? '').toString(),
      amount: (json['amount'] as num).toDouble(),
      expenseDate: DateTime.parse(json['expense_date'].toString()),
      description: json['description']?.toString(),
    );
  }
}

class ExpensesService {
  final SupabaseClient _sb = Supabase.instance.client;

  Future<int> _getAdminId() async {
    final user = _sb.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final row = await _sb
        .from('admin')
        .select('id')
        .eq('auth_id', user.id)
        .single();

    return (row['id'] as num).toInt();
  }

  Future<void> ensureDefaultCategories() async {
    final adminId = await _getAdminId();
    await _sb.rpc('ensure_default_expense_categories', params: {
      'p_admin_id': adminId,
    });
  }

  Future<List<ExpenseCategory>> getCategories() async {
    final adminId = await _getAdminId();

    final rows = await _sb
        .from('expense_categories')
        .select()
        .eq('admin_id', adminId)
        .order('name');

    return (rows as List)
        .map((e) => ExpenseCategory.fromJson(e))
        .toList();
  }

  Future<ExpenseCategory> addCategory(String name) async {
    final adminId = await _getAdminId();

    final res = await _sb
        .from('expense_categories')
        .insert({
      'admin_id': adminId,
      'name': name.trim(),
      'is_default': false,
    })
        .select()
        .single();

    return ExpenseCategory.fromJson(res as Map<String, dynamic>);
  }

  Future<void> deleteCategory(int id) async {
    final adminId = await _getAdminId();
    await _sb.from('expense_categories').delete().eq('id', id).eq('admin_id', adminId);
  }

  Future<void> addExpense({
    required int categoryId,
    required double amount,
    required DateTime date,
    String? description,
  }) async {
    final adminId = await _getAdminId();

    await _sb.from('expenses').insert({
      'admin_id': adminId,
      'category_id': categoryId,
      'amount': amount,
      'expense_date': _dateOnly(date),
      'description': description?.trim(),
    });
  }

  Future<void> deleteExpense(int id) async {
    final adminId = await _getAdminId();
    await _sb.from('expenses').delete().eq('id', id).eq('admin_id', adminId);
  }

  Future<List<ExpenseItem>> getExpenses({
    DateTime? from,
    DateTime? to,
    int? categoryId,
    double? minAmount,
    double? maxAmount,
    String? search,
  }) async {
    final adminId = await _getAdminId();

    // Use view for category_name
    var q = _sb
        .from('expenses_with_category')
        .select()
        .eq('admin_id', adminId);

    if (from != null) q = q.gte('expense_date', _dateOnly(from));
    if (to != null) q = q.lte('expense_date', _dateOnly(to));
    if (categoryId != null) q = q.eq('category_id', categoryId);
    if (minAmount != null) q = q.gte('amount', minAmount);
    if (maxAmount != null) q = q.lte('amount', maxAmount);

    final s = (search ?? '').trim();
    if (s.isNotEmpty) {
      q = q.ilike('description', '%$s%');
    }

    final rows = await q.order('expense_date', ascending: false);

    return (rows as List).map((e) => ExpenseItem.fromJson(e)).toList();
  }

  String _dateOnly(DateTime d) {
    final x = DateTime(d.year, d.month, d.day);
    return x.toIso8601String().substring(0, 10); // yyyy-MM-dd
  }
}
