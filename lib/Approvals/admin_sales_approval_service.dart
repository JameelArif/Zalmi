import 'package:supabase_flutter/supabase_flutter.dart';

const String kCustomerAppsToApplicationsRel = 'customer_applications_application_id_fkey';

class AdminUserContext {
  final int adminId;
  final String authId;
  AdminUserContext({required this.adminId, required this.authId});
}

class EmployeeOption {
  final int id;
  final String name;
  EmployeeOption({required this.id, required this.name});
}

class AppOption {
  final int id;
  final String name;
  AppOption({required this.id, required this.name});
}

class SaleRow {
  final int id;
  final String status;
  final DateTime createdAt;

  final int employeeId;
  final String employeeName;

  final int applicationId;
  final String appName;

  final int? customerId;
  final String customerName;
  final String customerContact;
  final bool isWalkIn;

  final String rateType;
  final String paymentType;

  final double amountReceived; // cash part
  final double dueAmount;      // used_credit

  final int coins;
  final int extraCoins;
  final int totalCoins;

  final double coinRate;
  final double overRate;

  final int? bankAccountId;
  final String? bankLabel;

  SaleRow({
    required this.id,
    required this.status,
    required this.createdAt,
    required this.employeeId,
    required this.employeeName,
    required this.applicationId,
    required this.appName,
    required this.customerId,
    required this.customerName,
    required this.customerContact,
    required this.isWalkIn,
    required this.rateType,
    required this.paymentType,
    required this.amountReceived,
    required this.dueAmount,
    required this.coins,
    required this.extraCoins,
    required this.totalCoins,
    required this.coinRate,
    required this.overRate,
    required this.bankAccountId,
    required this.bankLabel,
  });
}

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

class AdminSalesApprovalService {
  SupabaseClient get _sb => Supabase.instance.client;

  String get _authId {
    final u = _sb.auth.currentUser;
    if (u == null) throw Exception("Not logged in");
    return u.id;
  }

  Future<AdminUserContext> getAdminContext() async {
    final row = await _sb.from('admin').select('id').eq('auth_id', _authId).single();
    return AdminUserContext(adminId: (row['id'] as num).toInt(), authId: _authId);
  }

  Future<List<EmployeeOption>> getEmployeesForAdmin({required int adminId}) async {
    final rows = await _sb
        .from('employees')
        .select('id, name')
        .eq('admin_id', adminId)
        .eq('status', 'active')
        .order('name');

    return (rows as List).map((r) {
      return EmployeeOption(
        id: (r['id'] as num).toInt(),
        name: (r['name'] ?? '').toString(),
      );
    }).toList();
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

  Future<List<SaleRow>> getSales({
    required int adminId,
    String? status, // pending/accepted/rejected/null(all)
    int? employeeId,
    int? applicationId,
    DateTime? dateFrom,
    DateTime? dateTo,
    int limit = 250,
  }) async {
    var q = _sb
        .from('sales')
        .select(
      'id, status, created_at, '
          'employee_id, employees:employee_id(name), '
          'application_id, app_name, '
          'customer_id, customer_name, customer_contact, is_walk_in, '
          'rate_type, payment_type, amount_received, used_credit, '
          'coins, extra_coins, total_coins, coin_rate, over_rate, '
          'bank_account_id, bank_accounts:bank_account_id(bank_name, account_number)',
    )
        .eq('admin_id', adminId);

    if (status != null && status.trim().isNotEmpty) q = q.eq('status', status.trim().toLowerCase());
    if (employeeId != null) q = q.eq('employee_id', employeeId);
    if (applicationId != null) q = q.eq('application_id', applicationId);

    if (dateFrom != null) q = q.gte('created_at', dateFrom.toIso8601String());
    if (dateTo != null) {
      final end = DateTime(dateTo.year, dateTo.month, dateTo.day, 23, 59, 59);
      q = q.lte('created_at', end.toIso8601String());
    }

    final rows = await q.order('created_at', ascending: false).limit(limit);
    return (rows as List).map(_mapSale).toList();
  }

  SaleRow _mapSale(dynamic r) {
    final empName = (r['employees']?['name'] ?? 'Unknown').toString();
    final bank = r['bank_accounts'];

    String? bankLabel;
    if (bank != null) {
      bankLabel = "${(bank['bank_name'] ?? '')} • ${(bank['account_number'] ?? '')}";
    }

    return SaleRow(
      id: (r['id'] as num).toInt(),
      status: (r['status'] ?? '').toString(),
      createdAt: DateTime.tryParse((r['created_at'] ?? '').toString()) ?? DateTime.now(),
      employeeId: (r['employee_id'] as num).toInt(),
      employeeName: empName,
      applicationId: (r['application_id'] as num).toInt(),
      appName: (r['app_name'] ?? '').toString(),
      customerId: (r['customer_id'] as num?)?.toInt(),
      customerName: (r['customer_name'] ?? '').toString(),
      customerContact: (r['customer_contact'] ?? '').toString(),
      isWalkIn: (r['is_walk_in'] ?? false) == true,
      rateType: (r['rate_type'] ?? '').toString(),
      paymentType: (r['payment_type'] ?? '').toString(),
      amountReceived: _toDouble(r['amount_received']),
      dueAmount: _toDouble(r['used_credit']),
      coins: (r['coins'] as num?)?.toInt() ?? 0,
      extraCoins: (r['extra_coins'] as num?)?.toInt() ?? 0,
      totalCoins: (r['total_coins'] as num?)?.toInt() ?? 0,
      coinRate: _toDouble(r['coin_rate']),
      overRate: _toDouble(r['over_rate']),
      bankAccountId: (r['bank_account_id'] as num?)?.toInt(),
      bankLabel: bankLabel,
    );
  }

  Future<CustomerCreditsSummary> getCustomerCreditsAllApps({required int customerId}) async {
    final rows = await _sb
        .from('customer_applications')
        .select(
      'application_id, total_credit, '
          'applications!$kCustomerAppsToApplicationsRel(application_name)',
    )
        .eq('customer_id', customerId);

    double sum = 0;
    final list = <CustomerAppCredit>[];

    for (final r in (rows as List)) {
      final appId = (r['application_id'] as num).toInt();
      final credit = _toDouble(r['total_credit']);
      final appName = ((r['applications']?['application_name']) ?? 'App #$appId').toString();
      sum += credit;
      list.add(CustomerAppCredit(applicationId: appId, appName: appName, credit: credit));
    }

    list.sort((a, b) => a.appName.toLowerCase().compareTo(b.appName.toLowerCase()));
    return CustomerCreditsSummary(totalAllApps: sum, perApp: list);
  }

  Future<void> decideSale({
    required int adminId,
    required int saleId,
    required bool accept,
    required String comments,
  }) async {
    await _sb.rpc('admin_decide_sale', params: {
      'p_admin_id': adminId,
      'p_sale_id': saleId,
      'p_action': accept ? 'accepted' : 'rejected',
      'p_comments': comments.trim(),
    });
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}
