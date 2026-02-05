import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ✅ Use your existing CustomerModel + CustomerService from Customerservice.dart
import 'Customerservice.dart';

/// =============================================================
/// CUSTOMER PROFILE PAGE - FIXED VERSION
/// Removed generic type issues with PostgrestTransformBuilder
/// =============================================================
class CustomerProfilePage extends StatefulWidget {
  final CustomerModel customer;

  const CustomerProfilePage({super.key, required this.customer});

  @override
  State<CustomerProfilePage> createState() => _CustomerProfilePageState();
}

class _CustomerProfilePageState extends State<CustomerProfilePage> {
  final SupabaseClient _sb = Supabase.instance.client;

  // -------- UI State
  bool _loadingSummary = false;

  // Sales filters
  bool _salesLoading = false;
  bool _salesSearchedOnce = false;
  DateTime? _salesFrom;
  DateTime? _salesTo;
  String _salesSearchText = '';
  int? _salesAppId;
  String _salesPaymentType = 'all';
  List<Map<String, dynamic>> _salesRows = [];

  // Recovery filters
  bool _recLoading = false;
  bool _recSearchedOnce = false;
  DateTime? _recFrom;
  DateTime? _recTo;
  int? _recAppId;
  List<Map<String, dynamic>> _recoveryRows = [];

  // Credit summary
  double _totalCreditAllApps = 0.0;
  List<_CreditRow> _creditRows = [];

  // Apps list (for dropdown filters)
  List<_AppLite> _apps = [];

  // Banks list (for recovery action)
  List<_BankLite> _banks = [];

  // Graph range dropdown
  String _graphMode = 'sales7';

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  // =============================================================
  // SUMMARY LOADING
  // =============================================================
  Future<void> _loadSummary() async {
    setState(() => _loadingSummary = true);
    try {
      // 1) Load apps list - NO GENERIC TYPES
      final appsRes = await _sb
          .from('applications')
          .select('id, application_name')
          .order('application_name');

      _apps = (appsRes as List)
          .map((r) => _AppLite(
        id: (r['id'] as num).toInt(),
        name: (r['application_name'] ?? '').toString(),
      ))
          .toList();

      // 2) Load banks - NO GENERIC TYPES
      final banksRes = await _sb
          .from('bank_accounts')
          .select('id, bank_name, account_number, current_balance, status')
          .eq('admin_id', widget.customer.adminId)
          .eq('status', 'active')
          .order('bank_name');

      _banks = (banksRes as List)
          .map((r) => _BankLite(
        id: (r['id'] as num).toInt(),
        bankName: (r['bank_name'] ?? '').toString(),
        accountNumber: (r['account_number'] ?? '').toString(),
        balance: _toDouble(r['current_balance']),
      ))
          .toList();

      // 3) Credit summary
      await _loadCreditSummary();
    } catch (e) {
      print('Error: $e');
      if (mounted) _toast('Summary load error: $e');
    } finally {
      if (mounted) setState(() => _loadingSummary = false);
    }
  }

  Future<void> _loadCreditSummary() async {
    try {
      final rows = await _sb
          .from('customer_applications')
          .select('id, application_id, total_credit, applications(application_name)')
          .eq('customer_id', widget.customer.id)
          .order('application_id');

      double sum = 0.0;
      final list = <_CreditRow>[];

      for (final r in (rows as List)) {
        final appId = (r['application_id'] as num).toInt();
        final credit = _toDouble(r['total_credit']);
        final appName =
        ((r['applications']?['application_name']) ?? 'App #$appId').toString();
        sum += credit;
        list.add(_CreditRow(appId: appId, appName: appName, credit: credit));
      }

      list.sort((a, b) => a.appName.toLowerCase().compareTo(b.appName.toLowerCase()));

      setState(() {
        _totalCreditAllApps = sum;
        _creditRows = list;
      });
    } catch (e) {
      print('Credit summary error: $e');
    }
  }

  // =============================================================
  // SALES SEARCH - BUILD QUERY DYNAMICALLY
  // =============================================================
  Future<void> _searchSales() async {
    setState(() {
      _salesLoading = true;
      _salesSearchedOnce = true;
      _salesRows = [];
    });

    try {
      // ✅ Build query step by step, chain all methods
      var query = _sb
          .from('sales')
          .select(
        'id, created_at, status, application_id, app_name, payment_type, amount_received, over_rate, used_credit, coins, extra_coins, coin_rate',
      )
          .eq('customer_id', widget.customer.id)
          .neq('status', 'pending');

      // Apply date filters
      if (_salesFrom != null) {
        query = query.gte('created_at', _salesFrom!.toIso8601String());
      }

      if (_salesTo != null) {
        final end = DateTime(
          _salesTo!.year,
          _salesTo!.month,
          _salesTo!.day,
          23,
          59,
          59,
        );
        query = query.lte('created_at', end.toIso8601String());
      }

      // Apply app filter
      if (_salesAppId != null) {
        query = query.eq('application_id', _salesAppId!);
      }

      // Apply payment type filter
      if (_salesPaymentType != 'all') {
        query = query.eq('payment_type', _salesPaymentType);
      }

      // Execute query with order and limit
      final res = await query.order('created_at', ascending: false).limit(300);

      final rows = List<Map<String, dynamic>>.from(res as List);

      // Manual text search
      final text = _salesSearchText.trim().toLowerCase();
      final filtered = rows.where((r) {
        if (text.isEmpty) return true;
        final appName = (r['app_name'] ?? '').toString().toLowerCase();
        final pay = (r['payment_type'] ?? '').toString().toLowerCase();
        final idStr = (r['id'] ?? '').toString().toLowerCase();
        return appName.contains(text) || pay.contains(text) || idStr.contains(text);
      }).toList();

      if (mounted) {
        setState(() => _salesRows = filtered);
      }
    } catch (e) {
      print('Sales search error: $e');
      if (mounted) _toast('Sales search error: $e');
    } finally {
      if (mounted) setState(() => _salesLoading = false);
    }
  }

  // =============================================================
  // RECOVERIES SEARCH - BUILD QUERY DYNAMICALLY
  // =============================================================
  Future<void> _searchRecoveries() async {
    setState(() {
      _recLoading = true;
      _recSearchedOnce = true;
      _recoveryRows = [];
    });

    try {
      // ✅ Chain methods properly - don't reassign after .select()
      var query = _sb
          .from('credit_recoveries')
          .select(
          'id, created_at, customer_id, application_id, amount, bank_account_id, note, applications(application_name), bank_accounts(bank_name, account_number)')
          .eq('customer_id', widget.customer.id);

      // Apply filters - reassign query each time
      if (_recAppId != null) {
        query = query.eq('application_id', _recAppId!);
      }

      if (_recFrom != null) {
        query = query.gte('created_at', _recFrom!.toIso8601String());
      }

      if (_recTo != null) {
        final end = DateTime(_recTo!.year, _recTo!.month, _recTo!.day, 23, 59, 59);
        query = query.lte('created_at', end.toIso8601String());
      }

      // Execute with order and limit
      final res = await query.order('created_at', ascending: false).limit(300);
      setState(() => _recoveryRows = List<Map<String, dynamic>>.from(res as List));
    } catch (e) {
      print('Recoveries search error: $e');
      if (mounted) _toast('Recoveries search error: $e');
    } finally {
      if (mounted) setState(() => _recLoading = false);
    }
  }

  // =============================================================
  // RECOVERY ACTION
  // =============================================================
  Future<void> _openRecoveryDialog() async {
    if (_creditRows.isEmpty) {
      _toast('No app credit rows found for this customer.');
      return;
    }
    if (_banks.isEmpty) {
      _toast('No active bank accounts found.');
      return;
    }

    int selectedAppId = _creditRows.first.appId;
    int selectedBankId = _banks.first.id;
    final amountCtrl = TextEditingController(text: '');
    final noteCtrl = TextEditingController(text: '');

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Credit Recovery'),
        content: StatefulBuilder(
          builder: (ctx, setL) {
            final currentCredit = _creditRows
                .firstWhere((x) => x.appId == selectedAppId, orElse: () => _creditRows.first)
                .credit;

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    value: selectedAppId,
                    items: _creditRows
                        .map((r) => DropdownMenuItem<int>(
                      value: r.appId,
                      child: Text('${r.appName}  (Due: ${r.credit.toStringAsFixed(2)})'),
                    ))
                        .toList(),
                    onChanged: (v) => setL(() => selectedAppId = v ?? selectedAppId),
                    decoration: const InputDecoration(
                      labelText: 'Select Application',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: selectedBankId,
                    items: _banks
                        .map((b) => DropdownMenuItem<int>(
                      value: b.id,
                      child: Text('${b.bankName} • ${b.accountNumber}'),
                    ))
                        .toList(),
                    onChanged: (v) => setL(() => selectedBankId = v ?? selectedBankId),
                    decoration: const InputDecoration(
                      labelText: 'Select Bank',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Recovery Amount',
                      border: const OutlineInputBorder(),
                      helperText: 'Current due: ${currentCredit.toStringAsFixed(2)}',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Note (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
              if (amount <= 0) {
                _toast('Enter valid amount');
                return;
              }
              Navigator.pop(context);
              await _performRecovery(
                applicationId: selectedAppId,
                bankAccountId: selectedBankId,
                amount: amount,
                note: noteCtrl.text.trim(),
              );
            },
            icon: const Icon(Icons.check_circle),
            label: const Text('Recover'),
          ),
        ],
      ),
    );
  }

  Future<void> _performRecovery({
    required int applicationId,
    required int bankAccountId,
    required double amount,
    required String note,
  }) async {
    setState(() => _loadingSummary = true);
    try {
      // 1) Get existing credit row
      final row = await _sb
          .from('customer_applications')
          .select('id, total_credit')
          .eq('customer_id', widget.customer.id)
          .eq('application_id', applicationId)
          .maybeSingle();

      if (row == null) {
        _toast('Customer has no credit row for this app.');
        return;
      }

      final customerAppId = (row['id'] as num).toInt();
      final currentCredit = _toDouble(row['total_credit']);

      if (amount > currentCredit) {
        _toast('Recovery amount cannot be greater than due credit.');
        return;
      }

      // 2) Minus credit
      final newCredit = currentCredit - amount;
      await _sb
          .from('customer_applications')
          .update({'total_credit': newCredit})
          .eq('id', customerAppId);

      // 3) Add to bank balance
      final bank = await _sb
          .from('bank_accounts')
          .select('id, current_balance')
          .eq('id', bankAccountId)
          .maybeSingle();

      if (bank == null) {
        _toast('Bank account not found');
        return;
      }

      final bankBal = _toDouble(bank['current_balance']);
      await _sb
          .from('bank_accounts')
          .update({'current_balance': bankBal + amount})
          .eq('id', bankAccountId);

      // 4) Insert recovery history
      await _sb.from('credit_recoveries').insert({
        'admin_id': widget.customer.adminId,
        'customer_id': widget.customer.id,
        'application_id': applicationId,
        'amount': amount,
        'bank_account_id': bankAccountId,
        'note': note,
      });

      _toast('Recovery successful ✅');

      // reload summary + history
      await _loadCreditSummary();
      if (_recSearchedOnce) {
        await _searchRecoveries();
      }
    } catch (e) {
      print('Recovery error: $e');
      _toast('Recovery failed: $e');
    } finally {
      if (mounted) setState(() => _loadingSummary = false);
    }
  }

  // =============================================================
  // GRAPH HELPERS
  // =============================================================
  List<_DayPoint> _buildDailySeriesFromSales(List<Map<String, dynamic>> rows, int days) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1));
    final map = <DateTime, double>{};

    for (int i = 0; i < days; i++) {
      final d = DateTime(start.year, start.month, start.day).add(Duration(days: i));
      map[d] = 0.0;
    }

    for (final r in rows) {
      final created = DateTime.tryParse((r['created_at'] ?? '').toString());
      if (created == null) continue;
      final day = DateTime(created.year, created.month, created.day);
      if (day.isBefore(start)) continue;

      final total = _toDouble(r['over_rate']);
      map[day] = (map[day] ?? 0.0) + total;
    }

    final list = map.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return list.map((e) => _DayPoint(date: e.key, value: e.value)).toList();
  }

  List<_DayPoint> _buildDailySeriesFromRecoveries(List<Map<String, dynamic>> rows, int days) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1));
    final map = <DateTime, double>{};

    for (int i = 0; i < days; i++) {
      final d = DateTime(start.year, start.month, start.day).add(Duration(days: i));
      map[d] = 0.0;
    }

    for (final r in rows) {
      final created = DateTime.tryParse((r['created_at'] ?? '').toString());
      if (created == null) continue;
      final day = DateTime(created.year, created.month, created.day);
      if (day.isBefore(start)) continue;

      final amt = _toDouble(r['amount']);
      map[day] = (map[day] ?? 0.0) + amt;
    }

    final list = map.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return list.map((e) => _DayPoint(date: e.key, value: e.value)).toList();
  }

  // =============================================================
  // UI BUILD
  // =============================================================
  @override
  Widget build(BuildContext context) {
    final sales7 = _buildDailySeriesFromSales(_salesRows, 7);
    final sales30 = _buildDailySeriesFromSales(_salesRows, 30);
    final rec7 = _buildDailySeriesFromRecoveries(_recoveryRows, 7);
    final rec30 = _buildDailySeriesFromRecoveries(_recoveryRows, 30);

    List<_DayPoint> graphSeries;
    String graphTitle;

    switch (_graphMode) {
      case 'sales30':
        graphSeries = sales30;
        graphTitle = 'Sales (Last 30 Days)';
        break;
      case 'rec7':
        graphSeries = rec7;
        graphTitle = 'Recoveries (Last 7 Days)';
        break;
      case 'rec30':
        graphSeries = rec30;
        graphTitle = 'Recoveries (Last 30 Days)';
        break;
      case 'sales7':
      default:
        graphSeries = sales7;
        graphTitle = 'Sales (Last 7 Days)';
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.customer.customerName),
        backgroundColor: Colors.blue,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadingSummary ? null : _loadSummary,
            icon: const Icon(Icons.refresh),
          )
        ],
      ),
      backgroundColor: Colors.grey[50],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loadingSummary ? null : _openRecoveryDialog,
        icon: const Icon(Icons.savings),
        label: const Text('Recovery'),
        backgroundColor: Colors.green[700],
      ),
      body: _loadingSummary
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadSummary,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _customerHeaderCard(),
            const SizedBox(height: 14),
            _creditSummaryCard(),
            const SizedBox(height: 14),
            _graphCard(graphTitle, graphSeries),
            const SizedBox(height: 14),
            _salesFiltersCard(),
            const SizedBox(height: 10),
            _salesResultsCard(),
            const SizedBox(height: 14),
            _recoveryFiltersCard(),
            const SizedBox(height: 10),
            _recoveryResultsCard(),
          ],
        ),
      ),
    );
  }

  Widget _customerHeaderCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: Colors.blue[700]!, width: 5)),
          color: Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Customer Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _kv('Name', widget.customer.customerName),
            _kv('Contact', widget.customer.customerContact),
            _kv('Customer ID', widget.customer.id.toString()),
            _kv('Admin ID', widget.customer.adminId.toString()),
          ],
        ),
      ),
    );
  }

  Widget _creditSummaryCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Credit Summary',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Total Due: ${_totalCreditAllApps.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_creditRows.isEmpty)
              Text('No credit rows found.', style: TextStyle(color: Colors.grey[600])),
            if (_creditRows.isNotEmpty)
              ..._creditRows.map((r) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(r.appName, style: const TextStyle(fontWeight: FontWeight.w700)),
                trailing: Text(r.credit.toStringAsFixed(2),
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: r.credit > 0 ? Colors.red[700] : Colors.green[700])),
              )),
          ],
        ),
      ),
    );
  }

  Widget _graphCard(String title, List<_DayPoint> series) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: Colors.white),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                DropdownButton<String>(
                  value: _graphMode,
                  items: const [
                    DropdownMenuItem(value: 'sales7', child: Text('Sales 7D')),
                    DropdownMenuItem(value: 'sales30', child: Text('Sales 30D')),
                    DropdownMenuItem(value: 'rec7', child: Text('Recovery 7D')),
                    DropdownMenuItem(value: 'rec30', child: Text('Recovery 30D')),
                  ],
                  onChanged: (v) => setState(() => _graphMode = v ?? 'sales7'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _MiniBarChart(series: series),
          ],
        ),
      ),
    );
  }

  Widget _salesFiltersCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: Colors.white),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sales (Approved / Not Pending)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _dateBtn('From', _salesFrom, (d) => setState(() => _salesFrom = d))),
                const SizedBox(width: 10),
                Expanded(child: _dateBtn('To', _salesTo, (d) => setState(() => _salesTo = d))),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              value: _salesAppId,
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('All Apps')),
                ..._apps.map((a) => DropdownMenuItem<int?>(
                  value: a.id,
                  child: Text(a.name),
                )),
              ],
              onChanged: (v) => setState(() => _salesAppId = v),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Application Filter',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _salesPaymentType,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Payments')),
                DropdownMenuItem(value: 'cash', child: Text('Cash')),
                DropdownMenuItem(value: 'credit', child: Text('Credit')),
                DropdownMenuItem(value: 'mix', child: Text('Mix')),
              ],
              onChanged: (v) => setState(() => _salesPaymentType = v ?? 'all'),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Payment Type',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Search text (app name / payment / id)',
              ),
              onChanged: (v) => _salesSearchText = v,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _salesLoading ? null : _searchSales,
                    icon: const Icon(Icons.search),
                    label: const Text('Search Sales'),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: _salesLoading
                      ? null
                      : () {
                    setState(() {
                      _salesFrom = null;
                      _salesTo = null;
                      _salesAppId = null;
                      _salesPaymentType = 'all';
                      _salesSearchText = '';
                      _salesRows = [];
                      _salesSearchedOnce = false;
                    });
                  },
                  child: const Text('Reset'),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _salesResultsCard() {
    final totalSales = _salesRows.fold<double>(0.0, (s, r) => s + _toDouble(r['over_rate']));
    final totalCash = _salesRows
        .where((r) => (r['payment_type'] ?? '') == 'cash' || (r['payment_type'] ?? '') == 'mix')
        .fold<double>(0.0, (s, r) => s + _toDouble(r['amount_received']));
    final totalDue = _salesRows.fold<double>(0.0, (s, r) => s + _toDouble(r['used_credit']));

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: Colors.white),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sales Results',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (!_salesSearchedOnce)
              Text('Use filters and press "Search Sales".',
                  style: TextStyle(color: Colors.grey[700])),
            if (_salesLoading)
              const Center(
                  child: Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(),
                  )),
            if (_salesSearchedOnce && !_salesLoading) ...[
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _pill('Count', _salesRows.length.toString(), Colors.blue),
                  _pill('Total', totalSales.toStringAsFixed(2), Colors.teal),
                  _pill('Cash In', totalCash.toStringAsFixed(2), Colors.green),
                  _pill('Due', totalDue.toStringAsFixed(2), Colors.red),
                ],
              ),
              const SizedBox(height: 12),
              if (_salesRows.isEmpty)
                Text('No sales found with current filters.',
                    style: TextStyle(color: Colors.grey[700])),
              if (_salesRows.isNotEmpty)
                ..._salesRows.take(60).map((r) {
                  final created = (r['created_at'] ?? '').toString();
                  final pay = (r['payment_type'] ?? '').toString();
                  final appName = (r['app_name'] ?? '').toString();
                  final total = _toDouble(r['over_rate']);
                  final received = _toDouble(r['amount_received']);
                  final due = _toDouble(r['used_credit']);

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.withOpacity(0.12),
                      child: Text((pay.isNotEmpty ? pay[0].toUpperCase() : 'S')),
                    ),
                    title: Text('$appName • $pay',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(created),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(total.toStringAsFixed(2),
                            style: const TextStyle(fontWeight: FontWeight.w900)),
                        Text('R: ${received.toStringAsFixed(2)} • D: ${due.toStringAsFixed(2)}',
                            style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                      ],
                    ),
                  );
                }),
            ]
          ],
        ),
      ),
    );
  }

  Widget _recoveryFiltersCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: Colors.white),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Recoveries (History)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _dateBtn('From', _recFrom, (d) => setState(() => _recFrom = d))),
                const SizedBox(width: 10),
                Expanded(child: _dateBtn('To', _recTo, (d) => setState(() => _recTo = d))),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              value: _recAppId,
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('All Apps')),
                ..._apps.map((a) => DropdownMenuItem<int?>(
                  value: a.id,
                  child: Text(a.name),
                )),
              ],
              onChanged: (v) => setState(() => _recAppId = v),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Application Filter',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _recLoading ? null : _searchRecoveries,
                    icon: const Icon(Icons.search),
                    label: const Text('Search Recoveries'),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: _recLoading
                      ? null
                      : () {
                    setState(() {
                      _recFrom = null;
                      _recTo = null;
                      _recAppId = null;
                      _recoveryRows = [];
                      _recSearchedOnce = false;
                    });
                  },
                  child: const Text('Reset'),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _recoveryResultsCard() {
    final total = _recoveryRows.fold<double>(0.0, (s, r) => s + _toDouble(r['amount']));

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: Colors.white),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Recovery Results',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (!_recSearchedOnce)
              Text('Use filters and press "Search Recoveries".',
                  style: TextStyle(color: Colors.grey[700])),
            if (_recLoading)
              const Center(
                  child: Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(),
                  )),
            if (_recSearchedOnce && !_recLoading) ...[
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _pill('Count', _recoveryRows.length.toString(), Colors.blue),
                  _pill('Total', total.toStringAsFixed(2), Colors.green),
                ],
              ),
              const SizedBox(height: 12),
              if (_recoveryRows.isEmpty)
                Text('No recoveries found with current filters.',
                    style: TextStyle(color: Colors.grey[700])),
              if (_recoveryRows.isNotEmpty)
                ..._recoveryRows.take(60).map((r) {
                  final created = (r['created_at'] ?? '').toString();
                  final amt = _toDouble(r['amount']);
                  final appName = (r['applications']?['application_name'] ?? 'App').toString();
                  final bankName = (r['bank_accounts']?['bank_name'] ?? 'Bank').toString();
                  final bankAcc = (r['bank_accounts']?['account_number'] ?? '').toString();
                  final note = (r['note'] ?? '').toString();

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: CircleAvatar(
                      backgroundColor: Colors.green.withOpacity(0.12),
                      child: const Icon(Icons.savings, color: Colors.green),
                    ),
                    title: Text('$appName • ${amt.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('$created\n$bankName • $bankAcc${note.isEmpty ? '' : '\n$note'}'),
                    isThreeLine: true,
                  );
                }),
            ]
          ],
        ),
      ),
    );
  }

  // =============================================================
  // UI HELPERS
  // =============================================================
  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: TextStyle(color: Colors.grey[700])),
          Flexible(
            child: Text(v,
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _pill(String k, String v, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withOpacity(0.25)),
      ),
      child: Text('$k: $v', style: TextStyle(fontWeight: FontWeight.w900, color: c)),
    );
  }

  Widget _dateBtn(String label, DateTime? value, ValueChanged<DateTime?> onPick) {
    final txt = value == null
        ? '$label: Any'
        : '$label: ${value.year}-${_two(value.month)}-${_two(value.day)}';

    return OutlinedButton.icon(
      onPressed: () async {
        final now = DateTime.now();
        final initial = value ?? now;
        final picked = await showDatePicker(
          context: context,
          firstDate: DateTime(2020, 1, 1),
          lastDate: DateTime(now.year + 2, 12, 31),
          initialDate: initial,
        );
        onPick(picked);
      },
      icon: const Icon(Icons.date_range),
      label: Text(txt),
    );
  }

  String _two(int v) => v < 10 ? '0$v' : '$v';

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}

// =============================================================
// MINI BAR CHART
// =============================================================
class _MiniBarChart extends StatelessWidget {
  final List<_DayPoint> series;

  const _MiniBarChart({required this.series});

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty) {
      return Text('No data for graph', style: TextStyle(color: Colors.grey[600]));
    }

    final maxV = series.fold<double>(0.0, (m, p) => p.value > m ? p.value : m);
    final safeMax = maxV <= 0 ? 1.0 : maxV;

    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: series.map((p) {
          final h = (p.value / safeMax) * 110;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    height: h.isNaN ? 0 : h,
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${p.date.month}/${p.date.day}',
                    style: const TextStyle(fontSize: 10),
                  )
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// =============================================================
// INTERNAL MODELS
// =============================================================
class _CreditRow {
  final int appId;
  final String appName;
  final double credit;

  _CreditRow({required this.appId, required this.appName, required this.credit});
}

class _AppLite {
  final int id;
  final String name;

  _AppLite({required this.id, required this.name});
}

class _BankLite {
  final int id;
  final String bankName;
  final String accountNumber;
  final double balance;

  _BankLite({
    required this.id,
    required this.bankName,
    required this.accountNumber,
    required this.balance,
  });
}

class _DayPoint {
  final DateTime date;
  final double value;

  _DayPoint({required this.date, required this.value});
}