import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'Employeeservice.dart'; // uses EmployeeModel

class EmployeePerformancePage extends StatefulWidget {
  final EmployeeModel employee;

  const EmployeePerformancePage({super.key, required this.employee});

  @override
  State<EmployeePerformancePage> createState() => _EmployeePerformancePageState();
}

class _EmployeePerformancePageState extends State<EmployeePerformancePage> {
  final SupabaseClient _sb = Supabase.instance.client;

  // ---------------- Filters
  DateTime? _from;
  DateTime? _to;
  int? _appId; // null = all
  String _paymentType = 'all'; // all/cash/credit/mix
  String _searchText = '';

  // dropdown data
  List<_AppLite> _apps = [];

  // ---------------- Results state
  bool _loading = false;
  bool _searchedOnce = false;

  List<Map<String, dynamic>> _rows = []; // raw sales rows
  Map<int, _AppAgg> _byApp = {}; // breakdown

  // summary
  int _count = 0;
  double _totalSales = 0.0; // over_rate
  double _cashIn = 0.0; // amount_received
  double _creditGiven = 0.0; // used_credit

  // chart mode
  String _graphMode = '7'; // 7 or 30

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  Future<void> _loadApps() async {
    try {
      final res = await _sb
          .from('applications')
          .select('id, application_name')
          .order('application_name');

      final list = (res as List)
          .map((r) => _AppLite(
        id: (r['id'] as num).toInt(),
        name: (r['application_name'] ?? '').toString(),
      ))
          .toList();

      if (mounted) setState(() => _apps = list);
    } catch (_) {
      // not critical
    }
  }

  // ---------------- SEARCH (NO DATA until called)
  Future<void> _search() async {
    setState(() {
      _loading = true;
      _searchedOnce = true;
      _rows = [];
      _byApp = {};
      _count = 0;
      _totalSales = 0.0;
      _cashIn = 0.0;
      _creditGiven = 0.0;
    });

    try {
      var q = _sb
          .from('sales')
          .select(
        'id, created_at, status, employee_id, application_id, app_name, payment_type, amount_received, used_credit, over_rate',
      )
          .eq('employee_id', widget.employee.id)
          .neq('status', 'pending'); // ONLY not pending

      if (_appId != null) {
        q = q.eq('application_id', _appId!);
      }

      if (_paymentType != 'all') {
        q = q.eq('payment_type', _paymentType);
      }

      if (_from != null) {
        q = q.gte('created_at', _from!.toIso8601String());
      }

      if (_to != null) {
        final end = DateTime(_to!.year, _to!.month, _to!.day, 23, 59, 59);
        q = q.lte('created_at', end.toIso8601String());
      }

      final res = await q.order('created_at', ascending: false).limit(1500);

      final rows = List<Map<String, dynamic>>.from(res as List);

      // manual search (safe, no query builder generic issues)
      final text = _searchText.trim().toLowerCase();
      final filtered = rows.where((r) {
        if (text.isEmpty) return true;
        final appName = (r['app_name'] ?? '').toString().toLowerCase();
        final pay = (r['payment_type'] ?? '').toString().toLowerCase();
        final idStr = (r['id'] ?? '').toString().toLowerCase();
        return appName.contains(text) || pay.contains(text) || idStr.contains(text);
      }).toList();

      // compute summary + app breakdown
      final map = <int, _AppAgg>{};
      double total = 0, cash = 0, credit = 0;

      for (final r in filtered) {
        total += _toDouble(r['over_rate']);
        cash += _toDouble(r['amount_received']);
        credit += _toDouble(r['used_credit']);

        final appId = _toInt(r['application_id']);
        final appName = (r['app_name'] ?? 'App #$appId').toString();
        map.putIfAbsent(appId, () => _AppAgg(appId: appId, appName: appName));

        map[appId]!.count += 1;
        map[appId]!.totalSales += _toDouble(r['over_rate']);
        map[appId]!.cashIn += _toDouble(r['amount_received']);
        map[appId]!.creditGiven += _toDouble(r['used_credit']);
      }

      final sortedKeys = map.keys.toList()
        ..sort((a, b) => map[b]!.totalSales.compareTo(map[a]!.totalSales));
      final sortedMap = <int, _AppAgg>{
        for (final k in sortedKeys) k: map[k]!,
      };

      if (!mounted) return;
      setState(() {
        _rows = filtered;
        _byApp = sortedMap;
        _count = filtered.length;
        _totalSales = total;
        _cashIn = cash;
        _creditGiven = credit;
      });
    } catch (e) {
      _toast('Search error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------------- Graph helpers
  List<_DayPoint> _dailySeries(int days) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1));
    final map = <DateTime, double>{};

    for (int i = 0; i < days; i++) {
      final d = DateTime(start.year, start.month, start.day).add(Duration(days: i));
      map[d] = 0.0;
    }

    for (final r in _rows) {
      final created = DateTime.tryParse((r['created_at'] ?? '').toString());
      if (created == null) continue;
      final day = DateTime(created.year, created.month, created.day);
      if (day.isBefore(start)) continue;

      map[day] = (map[day] ?? 0.0) + _toDouble(r['over_rate']);
    }

    final list = map.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return list.map((e) => _DayPoint(date: e.key, value: e.value)).toList();
  }

  // ---------------- UI
  @override
  Widget build(BuildContext context) {
    final series = _dailySeries(_graphMode == '30' ? 30 : 7);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('${widget.employee.name} • Performance'),
        backgroundColor: Colors.blue,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _employeeHeader(),
          const SizedBox(height: 12),
          _filtersCard(),
          const SizedBox(height: 12),
          _summaryCard(),
          const SizedBox(height: 12),
          _graphCard(series),
          const SizedBox(height: 12),
          _appBreakdownCard(),
          const SizedBox(height: 12),
          _resultsCard(),
        ],
      ),
    );
  }

  Widget _employeeHeader() {
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
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.blue.withOpacity(0.12),
              child: const Icon(Icons.person, color: Colors.blue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.employee.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(widget.employee.email, style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                  Text(widget.employee.contact, style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (widget.employee.status == 'active' ? Colors.green : Colors.red).withOpacity(0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                widget.employee.status.toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: widget.employee.status == 'active' ? Colors.green[700] : Colors.red[700],
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filtersCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: Colors.white),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filters (No Data Until Search)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _dateBtn('From', _from, (d) => setState(() => _from = d))),
                const SizedBox(width: 10),
                Expanded(child: _dateBtn('To', _to, (d) => setState(() => _to = d))),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              initialValue: _appId,
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('All Apps')),
                ..._apps.map((a) => DropdownMenuItem<int?>(value: a.id, child: Text(a.name))),
              ],
              onChanged: (v) => setState(() => _appId = v),
              decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Application'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _paymentType,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Payments')),
                DropdownMenuItem(value: 'cash', child: Text('Cash')),
                DropdownMenuItem(value: 'credit', child: Text('Credit')),
                DropdownMenuItem(value: 'mix', child: Text('Mix')),
              ],
              onChanged: (v) => setState(() => _paymentType = v ?? 'all'),
              decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Payment Type'),
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Search (app / payment / id)',
              ),
              onChanged: (v) => _searchText = v,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _search,
                    icon: _loading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.search),
                    label: const Text('Search'),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: _loading
                      ? null
                      : () {
                    setState(() {
                      _from = null;
                      _to = null;
                      _appId = null;
                      _paymentType = 'all';
                      _searchText = '';
                      _searchedOnce = false;
                      _rows = [];
                      _byApp = {};
                      _count = 0;
                      _totalSales = 0;
                      _cashIn = 0;
                      _creditGiven = 0;
                    });
                  },
                  child: const Text('Reset'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _summaryCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: Colors.white),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Summary (Not Pending Sales)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (!_searchedOnce)
              Text('Set filters and press Search.', style: TextStyle(color: Colors.grey[700])),
            if (_searchedOnce) ...[
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _pill('Tx', _count.toString(), Colors.blue),
                  _pill('Total Sales', _totalSales.toStringAsFixed(2), Colors.teal),
                  _pill('Cash', _cashIn.toStringAsFixed(2), Colors.green),
                  _pill('Credit', _creditGiven.toStringAsFixed(2), Colors.red),
                ],
              )
            ]
          ],
        ),
      ),
    );
  }

  Widget _graphCard(List<_DayPoint> series) {
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
                const Expanded(
                  child: Text('Performance Graph',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                DropdownButton<String>(
                  value: _graphMode,
                  items: const [
                    DropdownMenuItem(value: '7', child: Text('Last 7 Days')),
                    DropdownMenuItem(value: '30', child: Text('Last 30 Days')),
                  ],
                  onChanged: (v) => setState(() => _graphMode = v ?? '7'),
                )
              ],
            ),
            const SizedBox(height: 10),
            if (!_searchedOnce)
              Text('Graph shows after Search.', style: TextStyle(color: Colors.grey[700])),
            if (_searchedOnce) _MiniBarChart(series: series),
          ],
        ),
      ),
    );
  }

  Widget _appBreakdownCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: Colors.white),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('App Breakdown',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (!_searchedOnce)
              Text('Breakdown shows after Search.', style: TextStyle(color: Colors.grey[700])),
            if (_searchedOnce && _byApp.isEmpty)
              Text('No data found.', style: TextStyle(color: Colors.grey[700])),
            if (_searchedOnce && _byApp.isNotEmpty)
              ..._byApp.values.take(12).map((a) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(a.appName, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('Tx: ${a.count} • Cash: ${a.cashIn.toStringAsFixed(2)} • Credit: ${a.creditGiven.toStringAsFixed(2)}'),
                  trailing: Text(a.totalSales.toStringAsFixed(2),
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                );
              })
          ],
        ),
      ),
    );
  }

  Widget _resultsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: Colors.white),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Transactions',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (!_searchedOnce)
              Text('No data loaded. Use Search.', style: TextStyle(color: Colors.grey[700])),
            if (_searchedOnce && _loading)
              const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator())),
            if (_searchedOnce && !_loading && _rows.isEmpty)
              Text('No transactions found.', style: TextStyle(color: Colors.grey[700])),
            if (_searchedOnce && !_loading && _rows.isNotEmpty)
              ..._rows.take(60).map((r) {
                final created = (r['created_at'] ?? '').toString();
                final pay = (r['payment_type'] ?? '').toString();
                final appName = (r['app_name'] ?? '').toString();
                final total = _toDouble(r['over_rate']);
                final cash = _toDouble(r['amount_received']);
                final credit = _toDouble(r['used_credit']);

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.withOpacity(0.12),
                    child: Text(pay.isNotEmpty ? pay[0].toUpperCase() : 'S'),
                  ),
                  title: Text('$appName • $pay', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(created),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(total.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.w900)),
                      Text('C: ${cash.toStringAsFixed(2)} • Cr: ${credit.toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  // ---------------- UI helpers
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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}

// =============================================================
// MINI BAR CHART (NO PACKAGES)
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
                  Text('${p.date.month}/${p.date.day}', style: const TextStyle(fontSize: 10)),
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
class _AppLite {
  final int id;
  final String name;

  _AppLite({required this.id, required this.name});
}

class _AppAgg {
  final int appId;
  final String appName;
  int count = 0;
  double totalSales = 0.0;
  double cashIn = 0.0;
  double creditGiven = 0.0;

  _AppAgg({required this.appId, required this.appName});
}

class _DayPoint {
  final DateTime date;
  final double value;

  _DayPoint({required this.date, required this.value});
}
