import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final SupabaseClient _sb = Supabase.instance.client;

  DateTime? _from;
  DateTime? _to;

  bool _loading = false;
  bool _loadedOnce = false;

  // ---- KPIs
  double _salesTotal = 0;
  double _salesCashIn = 0;
  double _salesCreditGiven = 0;

  double _purchaseTotalPkr = 0;
  double _purchaseTotalCoins = 0;

  double _totalCustomerDue = 0;
  double _totalBankBalance = 0;

  // ---- Lists
  List<_AppStock> _appStocks = [];
  List<_BankRow> _banks = [];

  // ---- Graph series
  List<_DayPoint> _salesSeries = [];
  List<_DayPoint> _purchaseSeries = [];

  Future<int> _getAdminId() async {
    final user = _sb.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final row = await _sb
        .from('admin')
        .select('id')
        .eq('auth_id', user.id)
        .maybeSingle();

    if (row == null) throw Exception('Admin not found for this auth user');
    return (row['id'] as num).toInt();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _loading = true;
      _loadedOnce = true;
    });

    try {
      final adminId = await _getAdminId();
      final range = _dateRange();
      final fromIso = range.$1.toIso8601String();
      final toIso = range.$2.toIso8601String();

      // Run all loads in parallel (fast)
      await Future.wait([
        _loadSales(adminId, fromIso, toIso),
        _loadPurchases(adminId, fromIso, toIso),
        _loadCustomerCredit(adminId),
        _loadBanks(adminId),
        _loadAppStocks(adminId),
      ]);
    } catch (e) {
      _toast('Dashboard load error: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  /// If user didn't pick dates, we still prepare a small default window,
  /// BUT we DO NOT auto-load until button is pressed.
  (DateTime, DateTime) _dateRange() {
    final now = DateTime.now();
    final start = _from ?? DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29));
    final endDay = _to ?? DateTime(now.year, now.month, now.day);
    final end = DateTime(endDay.year, endDay.month, endDay.day, 23, 59, 59);
    return (start, end);
  }

  Future<void> _loadSales(int adminId, String fromIso, String toIso) async {
    // NOTE: if your sales table doesn't have admin_id, remove it.
    // Many projects keep admin_id in sales. If not, keep only date filter.
    List rows = [];
    try {
      rows = await _sb
          .from('sales')
          .select('created_at, status, payment_type, over_rate, amount_received, used_credit, admin_id')
          .eq('admin_id', adminId)
          .neq('status', 'pending')
          .gte('created_at', fromIso)
          .lte('created_at', toIso)
          .limit(5000);
    } catch (_) {
      // fallback if sales doesn't have admin_id
      rows = await _sb
          .from('sales')
          .select('created_at, status, payment_type, over_rate, amount_received, used_credit')
          .neq('status', 'pending')
          .gte('created_at', fromIso)
          .lte('created_at', toIso)
          .limit(5000);
    }

    double total = 0;
    double cashIn = 0;
    double creditGiven = 0;

    for (final r in rows) {
      total += _toDouble(r['over_rate']);
      creditGiven += _toDouble(r['used_credit']);

      final pay = (r['payment_type'] ?? '').toString();
      if (pay == 'cash' || pay == 'mix') {
        cashIn += _toDouble(r['amount_received']);
      }
    }

    final series = _buildDailySeries(rows, days: 30, dateKey: 'created_at', valueKey: 'over_rate');

    if (!mounted) return;
    setState(() {
      _salesTotal = total;
      _salesCashIn = cashIn;
      _salesCreditGiven = creditGiven;
      _salesSeries = series;
    });
  }

  Future<void> _loadPurchases(int adminId, String fromIso, String toIso) async {
    final rows = await _sb
        .from('purchases')
        .select('purchase_date, amount_pkr, purchased_coins, payment_type, vendor_name, note, admin_id')
        .eq('admin_id', adminId)
        .gte('purchase_date', fromIso)
        .lte('purchase_date', toIso)
        .limit(5000);

    double totalPkr = 0;
    double totalCoins = 0;

    for (final r in rows as List) {
      totalPkr += _toDouble(r['amount_pkr']);
      totalCoins += _toDouble(r['purchased_coins']);
    }

    final series = _buildDailySeries(rows, days: 30, dateKey: 'purchase_date', valueKey: 'purchased_coins');

    if (!mounted) return;
    setState(() {
      _purchaseTotalPkr = totalPkr;
      _purchaseTotalCoins = totalCoins;
      _purchaseSeries = series;
    });
  }

  Future<void> _loadCustomerCredit(int adminId) async {
    // If your customer_applications has admin_id, filter it.
    // If not, sum all for customers of admin via join is harder, so we fallback to raw sum.
    List rows = [];
    try {
      rows = await _sb
          .from('customer_applications')
          .select('total_credit, admin_id')
          .eq('admin_id', adminId)
          .limit(10000);
    } catch (_) {
      rows = await _sb
          .from('customer_applications')
          .select('total_credit')
          .limit(10000);
    }

    double sum = 0;
    for (final r in rows) {
      sum += _toDouble(r['total_credit']);
    }

    if (!mounted) return;
    setState(() => _totalCustomerDue = sum);
  }

  Future<void> _loadBanks(int adminId) async {
    final rows = await _sb
        .from('bank_accounts')
        .select('id, bank_name, account_number, current_balance, status')
        .eq('admin_id', adminId)
        .order('bank_name');

    double sum = 0;
    final banks = <_BankRow>[];

    for (final r in rows as List) {
      final bal = _toDouble(r['current_balance']);
      sum += bal;
      banks.add(_BankRow(
        bankName: (r['bank_name'] ?? '').toString(),
        accountNumber: (r['account_number'] ?? '').toString(),
        balance: bal,
        status: (r['status'] ?? '').toString(),
      ));
    }

    if (!mounted) return;
    setState(() {
      _totalBankBalance = sum;
      _banks = banks;
    });
  }

  Future<void> _loadAppStocks(int adminId) async {
    // IMPORTANT: Your new RPC updates applications.total_coins (NOT current_coins).
    // We read total_coins first, fallback to current_coins if needed.
    List rows = [];
    try {
      rows = await _sb
          .from('applications')
          .select('id, application_name, total_coins, per_coin_rate, wholesale_rate, admin_id')
          .eq('admin_id', adminId)
          .order('application_name');
    } catch (_) {
      // fallback if admin_id not in applications
      rows = await _sb
          .from('applications')
          .select('id, application_name, total_coins, current_coins, per_coin_rate, wholesale_rate')
          .order('application_name');
    }

    final list = <_AppStock>[];
    for (final r in rows) {
      final name = (r['application_name'] ?? '').toString();

      // prefer total_coins, fallback to current_coins
      final coins = r.containsKey('total_coins')
          ? _toDouble(r['total_coins'])
          : _toDouble(r['current_coins']);

      final stdRate = _toDouble(r['per_coin_rate']);
      final whRate = _toDouble(r['wholesale_rate']);

      list.add(_AppStock(
        name: name,
        coins: coins,
        stdValue: coins * stdRate,
        wholesaleValue: coins * whRate,
      ));
    }

    if (!mounted) return;
    setState(() => _appStocks = list);
  }

  List<_DayPoint> _buildDailySeries(
      dynamic rows, {
        required int days,
        required String dateKey,
        required String valueKey,
      }) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1));
    final map = <DateTime, double>{};

    for (int i = 0; i < days; i++) {
      final d = DateTime(start.year, start.month, start.day).add(Duration(days: i));
      map[d] = 0.0;
    }

    for (final r in (rows as List)) {
      final created = DateTime.tryParse((r[dateKey] ?? '').toString());
      if (created == null) continue;
      final day = DateTime(created.year, created.month, created.day);
      if (day.isBefore(start)) continue;

      map[day] = (map[day] ?? 0.0) + _toDouble(r[valueKey]);
    }

    final list = map.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return list.map((e) => _DayPoint(date: e.key, value: e.value)).toList();
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickDate(String which) async {
    final now = DateTime.now();
    final initial = (which == 'from' ? _from : _to) ?? now;
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(now.year + 2, 12, 31),
      initialDate: initial,
    );
    if (picked == null) return;

    setState(() {
      if (which == 'from') _from = picked;
      if (which == 'to') _to = picked;
    });
  }

  String _fmt(DateTime? d, String label) {
    if (d == null) return '$label: Any';
    return '$label: ${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loading ? null : () => _loadDashboard(),
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload',
          ),
        ],
      ),
      backgroundColor: Colors.grey[100],
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _filtersCard(),

          const SizedBox(height: 12),

          if (!_loadedOnce)
            _hintCard('Select filters and press "Load Dashboard".'),

          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 20),
              child: Center(child: CircularProgressIndicator()),
            ),

          if (_loadedOnce && !_loading) ...[
            _kpiSalesCard(),
            const SizedBox(height: 12),

            _kpiPurchasesCard(),
            const SizedBox(height: 12),

            _inventoryAppsCard(),
            const SizedBox(height: 12),

            _customerCreditCard(),
            const SizedBox(height: 12),

            _banksCard(),
          ],
        ],
      ),
    );
  }

  Widget _filtersCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dashboard Filters', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : () => _pickDate('from'),
                    icon: const Icon(Icons.date_range),
                    label: Text(_fmt(_from, 'From')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : () => _pickDate('to'),
                    icon: const Icon(Icons.date_range),
                    label: Text(_fmt(_to, 'To')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _quickBtn('7D', () {
                  final now = DateTime.now();
                  setState(() {
                    _from = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
                    _to = DateTime(now.year, now.month, now.day);
                  });
                }),
                _quickBtn('30D', () {
                  final now = DateTime.now();
                  setState(() {
                    _from = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29));
                    _to = DateTime(now.year, now.month, now.day);
                  });
                }),
                _quickBtn('This Month', () {
                  final now = DateTime.now();
                  setState(() {
                    _from = DateTime(now.year, now.month, 1);
                    _to = DateTime(now.year, now.month, now.day);
                  });
                }),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _loadDashboard,
                icon: const Icon(Icons.search),
                label: const Text('Load Dashboard'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickBtn(String text, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: _loading ? null : onTap,
      child: Text(text),
    );
  }

  Widget _hintCard(String msg) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue[700]),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
      ),
    );
  }

  Widget _kpiSalesCard() {
    return _sectionCard(
      title: 'Sales (Non-pending)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _pill('Total Sales', _salesTotal.toStringAsFixed(2), Colors.teal),
              _pill('Cash In', _salesCashIn.toStringAsFixed(2), Colors.green),
              _pill('Credit Given', _salesCreditGiven.toStringAsFixed(2), Colors.red),
            ],
          ),
          const SizedBox(height: 10),
          _MiniBarChart(series: _salesSeries, suffix: ''),
        ],
      ),
    );
  }

  Widget _kpiPurchasesCard() {
    return _sectionCard(
      title: 'Purchases',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _pill('Total PKR', _purchaseTotalPkr.toStringAsFixed(2), Colors.blue),
              _pill('Total Coins', _purchaseTotalCoins.toStringAsFixed(2), Colors.purple),
            ],
          ),
          const SizedBox(height: 10),
          _MiniBarChart(series: _purchaseSeries, suffix: ''),
        ],
      ),
    );
  }

  Widget _inventoryAppsCard() {
    final totalCoins = _appStocks.fold<double>(0, (s, a) => s + a.coins);
    final stdValue = _appStocks.fold<double>(0, (s, a) => s + a.stdValue);
    final whValue = _appStocks.fold<double>(0, (s, a) => s + a.wholesaleValue);

    return _sectionCard(
      title: 'Inventory Coins (Per App)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _pill('Total Coins', totalCoins.toStringAsFixed(2), Colors.indigo),
              _pill('Std Value', stdValue.toStringAsFixed(2), Colors.teal),
              _pill('Wholesale', whValue.toStringAsFixed(2), Colors.orange),
            ],
          ),
          const SizedBox(height: 10),
          if (_appStocks.isEmpty)
            Text('No applications found.', style: TextStyle(color: Colors.grey[700])),
          if (_appStocks.isNotEmpty)
            ..._appStocks.map((a) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('Coins: ${a.coins.toStringAsFixed(2)}'),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Std: ${a.stdValue.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12)),
                  Text('Wh: ${a.wholesaleValue.toStringAsFixed(2)}', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                ],
              ),
            )),
        ],
      ),
    );
  }

  Widget _customerCreditCard() {
    return _sectionCard(
      title: 'Customer Credit',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _pill('Total Due', _totalCustomerDue.toStringAsFixed(2), Colors.red),
        ],
      ),
    );
  }

  Widget _banksCard() {
    return _sectionCard(
      title: 'Bank Accounts',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pill('Total Balance', _totalBankBalance.toStringAsFixed(2), Colors.green),
          const SizedBox(height: 10),
          if (_banks.isEmpty)
            Text('No bank accounts found.', style: TextStyle(color: Colors.grey[700])),
          if (_banks.isNotEmpty)
            ..._banks.take(6).map((b) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('${b.bankName} • ${b.accountNumber}', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('Status: ${b.status}'),
              trailing: Text(b.balance.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.w900)),
            )),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _pill(String k, String v, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withOpacity(0.25)),
      ),
      child: Text('$k: $v', style: TextStyle(fontWeight: FontWeight.w900, color: c)),
    );
  }
}

// ------------------ mini chart ------------------

class _MiniBarChart extends StatelessWidget {
  final List<_DayPoint> series;
  final String suffix;

  const _MiniBarChart({required this.series, required this.suffix});

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty) {
      return Text('No data', style: TextStyle(color: Colors.grey[700]));
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

// ------------------ models ------------------

class _DayPoint {
  final DateTime date;
  final double value;
  _DayPoint({required this.date, required this.value});
}

class _AppStock {
  final String name;
  final double coins;
  final double stdValue;
  final double wholesaleValue;

  _AppStock({
    required this.name,
    required this.coins,
    required this.stdValue,
    required this.wholesaleValue,
  });
}

class _BankRow {
  final String bankName;
  final String accountNumber;
  final double balance;
  final String status;

  _BankRow({
    required this.bankName,
    required this.accountNumber,
    required this.balance,
    required this.status,
  });
}
