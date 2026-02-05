import 'package:supabase_flutter/supabase_flutter.dart';

class AdminUserContext {
  final int adminId;
  final String name;
  AdminUserContext({required this.adminId, required this.name});
}

class AppOption {
  final int id;
  final String name;
  AppOption({required this.id, required this.name});
}

class EmployeeOption {
  final int id;
  final String name;
  EmployeeOption({required this.id, required this.name});
}

class SaleRow {
  final int id;
  final int adminId;
  final int employeeId;
  final String employeeName;

  final int applicationId;
  final String appName;

  final int? customerId;
  final String customerName;
  final bool isWalkIn;

  final String status; // accepted/rejected/pending
  final String paymentType; // cash/credit/mix
  final String rateType; // standard/wholesale

  final int coins;
  final int extraCoins;
  int get totalCoins => coins + extraCoins;

  final double coinRate;
  final double overRate;

  final double amountReceived; // cash part
  final double usedCredit; // due amount (customer owes)

  final DateTime createdAt;

  // optional bank info (from view)
  final String? bankName;

  SaleRow({
    required this.id,
    required this.adminId,
    required this.employeeId,
    required this.employeeName,
    required this.applicationId,
    required this.appName,
    required this.customerId,
    required this.customerName,
    required this.isWalkIn,
    required this.status,
    required this.paymentType,
    required this.rateType,
    required this.coins,
    required this.extraCoins,
    required this.coinRate,
    required this.overRate,
    required this.amountReceived,
    required this.usedCredit,
    required this.createdAt,
    this.bankName,
  });

  factory SaleRow.fromJson(Map<String, dynamic> r) {
    return SaleRow(
      id: (r['id'] as num).toInt(),
      adminId: (r['admin_id'] as num).toInt(),
      employeeId: (r['employee_id'] as num).toInt(),
      employeeName: (r['employee_name'] ?? 'Employee').toString(),
      applicationId: (r['application_id'] as num).toInt(),
      appName: (r['application_name'] ?? r['app_name'] ?? 'App').toString(),
      customerId: (r['customer_id'] as num?)?.toInt(),
      customerName: (r['customer_name'] ?? 'Customer').toString(),
      isWalkIn: (r['is_walk_in'] ?? false) == true,
      status: (r['status'] ?? 'pending').toString().toLowerCase(),
      paymentType: (r['payment_type'] ?? 'cash').toString().toLowerCase(),
      rateType: (r['rate_type'] ?? 'standard').toString().toLowerCase(),
      coins: ((r['coins'] ?? 0) as num).toInt(),
      extraCoins: ((r['extra_coins'] ?? 0) as num).toInt(),
      coinRate: _toDouble(r['coin_rate']),
      overRate: _toDouble(r['over_rate']),
      amountReceived: _toDouble(r['amount_received']),
      usedCredit: _toDouble(r['used_credit']),
      createdAt: DateTime.parse((r['created_at'] ?? DateTime.now().toIso8601String()).toString()),
      bankName: r['bank_name']?.toString(),
    );
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}

// ----------------------
// Customer credit summary (optional)
// ----------------------
class CustomerAppCredit {
  final int applicationId;
  final String appName;
  final double credit;
  CustomerAppCredit({required this.applicationId, required this.appName, required this.credit});
}

class CustomerCreditsSummary {
  final double totalAllApps;
  final List<CustomerAppCredit> perApp;
  CustomerCreditsSummary({required this.totalAllApps, required this.perApp});
}

// ----------------------
// Service
// ----------------------
class AdminSalesPageService {
  SupabaseClient get _sb => Supabase.instance.client;

  Future<AdminUserContext> getAdminContext() async {
    final user = _sb.auth.currentUser;
    if (user == null) throw Exception("Not authenticated");

    final row = await _sb
        .from('admin')
        .select('id, name')
        .eq('auth_id', user.id)
        .single();

    return AdminUserContext(
      adminId: (row['id'] as num).toInt(),
      name: (row['name'] ?? 'Admin').toString(),
    );
  }

  Future<List<AppOption>> getAppsForAdmin({required int adminId}) async {
    final rows = await _sb
        .from('applications')
        .select('id, application_name')
        .eq('admin_id', adminId)
        .order('application_name');

    return (rows as List).map((r) {
      return AppOption(
        id: (r['id'] as num).toInt(),
        name: (r['application_name'] ?? '').toString(),
      );
    }).toList();
  }

  Future<List<EmployeeOption>> getEmployeesForAdmin({required int adminId}) async {
    final rows = await _sb
        .from('employees')
        .select('id, name')
        .eq('admin_id', adminId)
        .order('name');

    return (rows as List).map((r) {
      return EmployeeOption(
        id: (r['id'] as num).toInt(),
        name: (r['name'] ?? '').toString(),
      );
    }).toList();
  }

  /// Reads from view: sales_enriched
  /// The view should provide:
  /// - sales fields + employee_name + application_name + bank_name (optional)
  Future<List<SaleRow>> getSales({
    required int adminId,
    String? status,
    String? paymentType,
    int? employeeId,
    int? applicationId,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    var q = _sb
        .from('sales_enriched')
        .select()
        .eq('admin_id', adminId);

    if (status != null) {
      q = q.eq('status', status);
    }

    if (paymentType != null) {
      q = q.eq('payment_type', paymentType);
    }

    if (employeeId != null) {
      q = q.eq('employee_id', employeeId);
    }

    if (applicationId != null) {
      q = q.eq('application_id', applicationId);
    }

    if (dateFrom != null) {
      q = q.gte('created_at', dateFrom.toIso8601String());
    }

    if (dateTo != null) {
      // include the whole day
      final end = DateTime(dateTo.year, dateTo.month, dateTo.day, 23, 59, 59);
      q = q.lte('created_at', end.toIso8601String());
    }

    final rows = await q.order('created_at', ascending: false);

    return (rows as List).map((r) => SaleRow.fromJson(r as Map<String, dynamic>)).toList();
  }

  /// Optional helper if you want to display credit in some sheet
  Future<CustomerCreditsSummary> getCustomerCreditsAllApps({
    required int customerId,
  }) async {
    final rows = await _sb
        .from('customer_applications')
        .select('application_id, total_credit, applications(application_name)')
        .eq('customer_id', customerId);

    double sum = 0;
    final list = <CustomerAppCredit>[];

    for (final r in (rows as List)) {
      final appId = (r['application_id'] as num).toInt();
      final credit = (r['total_credit'] as num).toDouble();
      final appName = (r['applications']?['application_name'] ?? 'App #$appId').toString();

      sum += credit;
      list.add(CustomerAppCredit(applicationId: appId, appName: appName, credit: credit));
    }

    return CustomerCreditsSummary(totalAllApps: sum, perApp: list);
  }
}
