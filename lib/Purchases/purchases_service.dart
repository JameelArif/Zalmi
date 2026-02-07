import 'package:supabase_flutter/supabase_flutter.dart';

class PurchasesService {
  final _sb = Supabase.instance.client;

  // ============================================================
  // HELPERS
  // ============================================================

  double toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  int toInt(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  // ============================================================
  // GET ADMIN ID
  // ============================================================

  Future<int> getAdminId() async {
    final user = _sb.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final response = await _sb
        .from('admin')
        .select('id')
        .eq('auth_id', user.id.toString())
        .maybeSingle();

    if (response == null) throw Exception('Admin not found');
    return toInt(response['id']);
  }

  // ============================================================
  // FETCH APPS WITH COINS
  // ============================================================

  Future<List<Map<String, dynamic>>> fetchAppsInventory() async {
    final user = _sb.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final adminResponse = await _sb
        .from('admin')
        .select('id')
        .eq('auth_id', user.id.toString())
        .maybeSingle();

    if (adminResponse == null) throw Exception('Admin not found');
    final adminId = toInt(adminResponse['id']);

    final response = await _sb
        .from('applications')
        .select('id, application_name, total_coins')
        .eq('admin_id', adminId)
        .order('application_name');

    return List<Map<String, dynamic>>.from(response as List);
  }

  // ============================================================
  // FETCH ACTIVE BANKS
  // ============================================================

  Future<List<Map<String, dynamic>>> fetchActiveBanks(int adminId) async {
    final response = await _sb
        .from('bank_accounts')
        .select('id, bank_name, account_number, current_balance')
        .eq('admin_id', adminId)
        .eq('status', 'active')
        .order('bank_name');

    return List<Map<String, dynamic>>.from(response as List);
  }

  // ============================================================
  // SEARCH PURCHASES WITH FILTERS
  // ============================================================

  Future<List<Map<String, dynamic>>> searchPurchases({
    required int adminId,
    DateTime? from,
    DateTime? to,
    int? applicationId,
    String paymentType = 'all',
    String searchText = '',
  }) async {
    var query = _sb
        .from('purchases')
        .select(
      'id, purchase_date, payment_type, purchased_coins, amount_pkr, amount_usd, '
          'vendor_name, note, cash_amount, bank_amount, '
          'selling_price_value, wholesale_price_value, '
          'applications(id, application_name, per_coin_rate, wholesale_rate), '
          'bank_accounts(id, bank_name, account_number)',
    )
        .eq('admin_id', adminId);

    if (from != null) {
      query = query.gte('purchase_date', from.toIso8601String());
    }

    if (to != null) {
      final end = DateTime(to.year, to.month, to.day, 23, 59, 59);
      query = query.lte('purchase_date', end.toIso8601String());
    }

    if (applicationId != null) {
      query = query.eq('application_id', applicationId);
    }

    if (paymentType != 'all') {
      query = query.eq('payment_type', paymentType);
    }

    final response = await query
        .order('purchase_date', ascending: false)
        .limit(300);

    var rows = List<Map<String, dynamic>>.from(response as List);

    if (searchText.isNotEmpty) {
      final text = searchText.toLowerCase();
      rows = rows.where((r) {
        final vendor = (r['vendor_name'] ?? '').toString().toLowerCase();
        final note = (r['note'] ?? '').toString().toLowerCase();
        final id = (r['id'] ?? '').toString().toLowerCase();
        final appName = (r['applications']?['application_name'] ?? '').toString().toLowerCase();

        return vendor.contains(text) ||
            note.contains(text) ||
            id.contains(text) ||
            appName.contains(text);
      }).toList();
    }

    return rows;
  }

  // ============================================================
  // TOPUP PURCHASE - CALLS RPC
  // ============================================================

  Future<int> topupPurchase({
    required int adminId,
    required int applicationId,
    required double purchasedCoins,
    required double amountPkr,
    double? amountUsd,
    required String paymentType,
    int? bankAccountId,
    double? cashAmount,
    double? bankAmount,
    String? vendorName,
    String? note,
    required DateTime purchaseDate,
  }) async {
    try {
      final response = await _sb.rpc(
        'apply_purchase',
        params: {
          'p_admin_id': adminId,
          'p_application_id': applicationId,
          'p_purchased_coins': purchasedCoins,
          'p_amount_pkr': amountPkr,
          'p_amount_usd': amountUsd ?? 0,
          'p_payment_type': paymentType,
          'p_bank_account_id': bankAccountId,
          'p_cash_amount': cashAmount,
          'p_bank_amount': bankAmount,
          'p_vendor_name': vendorName,
          'p_note': note,
          'p_purchase_date': purchaseDate.toIso8601String(),
        },
      );

      return toInt(response);
    } catch (e) {
      throw Exception('Top-up failed: $e');
    }
  }

  // ============================================================
  // GET PURCHASE STATS
  // ============================================================

  Future<Map<String, dynamic>> getPurchaseStats(int adminId) async {
    final response = await _sb
        .from('purchases')
        .select('purchased_coins, amount_pkr, amount_usd, selling_price_value, wholesale_price_value')
        .eq('admin_id', adminId);

    double totalCoins = 0;
    double totalPkr = 0;
    double totalUsd = 0;
    double totalSellingValue = 0;
    double totalWholesaleValue = 0;

    for (final r in (response as List)) {
      totalCoins += toDouble(r['purchased_coins']);
      totalPkr += toDouble(r['amount_pkr']);
      totalUsd += toDouble(r['amount_usd']);
      totalSellingValue += toDouble(r['selling_price_value']);
      totalWholesaleValue += toDouble(r['wholesale_price_value']);
    }

    return {
      'total_coins': totalCoins,
      'total_pkr': totalPkr,
      'total_usd': totalUsd,
      'total_selling_value': totalSellingValue,
      'total_wholesale_value': totalWholesaleValue,
      'avg_cost_per_coin_pkr': totalCoins > 0 ? totalPkr / totalCoins : 0,
      'avg_cost_per_coin_usd': totalCoins > 0 ? totalUsd / totalCoins : 0,
      'potential_profit_selling': totalSellingValue - totalPkr,
      'potential_profit_wholesale': totalWholesaleValue - totalPkr,
      'purchase_count': response.length,
    };
  }
}