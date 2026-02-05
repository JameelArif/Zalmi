import 'package:flutter/material.dart';
import 'admin_sales_page_service.dart';

class AdminSalesPage extends StatefulWidget {
  const AdminSalesPage({super.key});

  @override
  State<AdminSalesPage> createState() => _AdminSalesPageState();
}

class _AdminSalesPageState extends State<AdminSalesPage> {
  final _service = AdminSalesPageService();

  bool _loading = true;
  AdminUserContext? _ctx;

  // Filters
  String _status = 'accepted'; // accepted | rejected | all
  String _paymentType = 'all'; // cash | credit | mix | all
  int? _applicationId; // null = all
  int? _employeeId; // null = all
  DateTime? _from;
  DateTime? _to;

  // Dropdown options
  List<AppOption> _apps = [];
  List<EmployeeOption> _employees = [];

  // Data
  List<SaleRow> _rows = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _init() async {
    setState(() => _loading = true);
    try {
      final ctx = await _service.getAdminContext();
      final apps = await _service.getAppsForAdmin(adminId: ctx.adminId);
      final emps = await _service.getEmployeesForAdmin(adminId: ctx.adminId);

      if (!mounted) return;
      setState(() {
        _ctx = ctx;
        _apps = apps;
        _employees = emps;
      });

      await _refresh();
    } catch (e) {
      if (!mounted) return;
      _toast("Init failed: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    final ctx = _ctx;
    if (ctx == null) return;

    setState(() => _loading = true);
    try {
      final rows = await _service.getSales(
        adminId: ctx.adminId,
        status: _status == 'all' ? null : _status,
        paymentType: _paymentType == 'all' ? null : _paymentType,
        employeeId: _employeeId,
        applicationId: _applicationId,
        dateFrom: _from,
        dateTo: _to,
      );

      if (!mounted) return;
      setState(() => _rows = rows);
    } catch (e) {
      if (!mounted) return;
      _toast("Fetch failed: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickFrom() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
      initialDate: _from ?? now,
    );
    if (picked == null) return;
    setState(() => _from = picked);
    _refresh();
  }

  Future<void> _pickTo() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
      initialDate: _to ?? now,
    );
    if (picked == null) return;
    setState(() => _to = picked);
    _refresh();
  }

  // ---------------------------
  // Computed totals
  // ---------------------------
  int get _totalSales => _rows.length;

  double get _totalCoins =>
      _rows.fold(0.0, (sum, r) => sum + r.totalCoins.toDouble());

  double get _totalAmount =>
      _rows.fold(0.0, (sum, r) => sum + r.overRate);

  double get _totalCashReceived =>
      _rows.fold(0.0, (sum, r) => sum + r.amountReceived);

  double get _totalDue =>
      _rows.fold(0.0, (sum, r) => sum + r.usedCredit);

  Map<int, _GroupSum> get _byApp {
    final m = <int, _GroupSum>{};
    for (final r in _rows) {
      final key = r.applicationId;
      m[key] ??= _GroupSum(name: r.appName);
      m[key] = m[key]!.add(r);
    }
    return m;
  }

  Map<int, _GroupSum> get _byEmployee {
    final m = <int, _GroupSum>{};
    for (final r in _rows) {
      final key = r.employeeId;
      m[key] ??= _GroupSum(name: r.employeeName);
      m[key] = m[key]!.add(r);
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sales"),
        actions: [
          IconButton(
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _topTotals(),
            const SizedBox(height: 12),
            _filtersCard(),
            const SizedBox(height: 12),
            _groupingCard(),
            const SizedBox(height: 14),
            Text(
              "Sales List ($_totalSales)",
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            if (_rows.isEmpty) _emptyCard(),
            ..._rows.map(_saleCard),
          ],
        ),
      ),
    );
  }

  // ---------------------------
  // UI Widgets
  // ---------------------------
  Widget _topTotals() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Overview", style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _statPill("Total Sales", _totalSales.toString(), Icons.receipt_long),
                _statPill("Total Coins", _totalCoins.toStringAsFixed(2), Icons.toll),
                _statPill("Total Amount", _totalAmount.toStringAsFixed(2), Icons.payments),
                _statPill("Cash Received", _totalCashReceived.toStringAsFixed(2), Icons.account_balance_wallet),
                _statPill("Total Due", _totalDue.toStringAsFixed(2), Icons.credit_score),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statPill(String k, String v, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text("$k: ", style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _filtersCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Filters", style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),

            // Status chips
            Wrap(
              spacing: 8,
              children: [
                _chipStatus("accepted", "Accepted"),
                _chipStatus("rejected", "Rejected"),
                _chipStatus("all", "All"),
              ],
            ),

            const SizedBox(height: 10),

            // Payment type chips
            Wrap(
              spacing: 8,
              children: [
                _chipPayment("all", "All Payment"),
                _chipPayment("cash", "Cash"),
                _chipPayment("credit", "Credit"),
                _chipPayment("mix", "Mix"),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickFrom,
                    icon: const Icon(Icons.date_range),
                    label: Text(_from == null ? "From date" : _fmtDate(_from!)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTo,
                    icon: const Icon(Icons.event),
                    label: Text(_to == null ? "To date" : _fmtDate(_to!)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<int?>(
              value: _applicationId,
              items: [
                const DropdownMenuItem(value: null, child: Text("All Apps")),
                ..._apps.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))),
              ],
              onChanged: (v) {
                setState(() => _applicationId = v);
                _refresh();
              },
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: "Application",
                prefixIcon: Icon(Icons.apps),
              ),
            ),

            const SizedBox(height: 10),

            DropdownButtonFormField<int?>(
              value: _employeeId,
              items: [
                const DropdownMenuItem(value: null, child: Text("All Employees")),
                ..._employees.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))),
              ],
              onChanged: (v) {
                setState(() => _employeeId = v);
                _refresh();
              },
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: "Employee",
                prefixIcon: Icon(Icons.badge),
              ),
            ),

            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _status = 'accepted';
                  _paymentType = 'all';
                  _applicationId = null;
                  _employeeId = null;
                  _from = null;
                  _to = null;
                });
                _refresh();
              },
              icon: const Icon(Icons.clear_all),
              label: const Text("Reset Filters"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chipStatus(String value, String label) {
    final selected = _status == value;
    return ChoiceChip(
      selected: selected,
      label: Text(label),
      onSelected: (_) {
        setState(() => _status = value);
        _refresh();
      },
    );
  }

  Widget _chipPayment(String value, String label) {
    final selected = _paymentType == value;
    return ChoiceChip(
      selected: selected,
      label: Text(label),
      onSelected: (_) {
        setState(() => _paymentType = value);
        _refresh();
      },
    );
  }

  Widget _groupingCard() {
    final byApp = _byApp.values.toList()
      ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

    final byEmp = _byEmployee.values.toList()
      ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Summary", style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),

            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text("By Application", style: TextStyle(fontWeight: FontWeight.w800)),
              children: [
                const Divider(height: 1),
                if (byApp.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text("No data"),
                  ),
                ...byApp.map((g) => ListTile(
                  dense: true,
                  title: Text(g.name),
                  subtitle: Text("Sales: ${g.count} • Coins: ${g.totalCoins.toStringAsFixed(2)}"),
                  trailing: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("Amt: ${g.totalAmount.toStringAsFixed(2)}",
                          style: const TextStyle(fontWeight: FontWeight.w900)),
                      Text("Due: ${g.totalDue.toStringAsFixed(2)}",
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                )),
              ],
            ),

            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text("By Employee", style: TextStyle(fontWeight: FontWeight.w800)),
              children: [
                const Divider(height: 1),
                if (byEmp.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text("No data"),
                  ),
                ...byEmp.map((g) => ListTile(
                  dense: true,
                  title: Text(g.name),
                  subtitle: Text("Sales: ${g.count} • Coins: ${g.totalCoins.toStringAsFixed(2)}"),
                  trailing: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("Amt: ${g.totalAmount.toStringAsFixed(2)}",
                          style: const TextStyle(fontWeight: FontWeight.w900)),
                      Text("Due: ${g.totalDue.toStringAsFixed(2)}",
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _saleCard(SaleRow s) {
    final statusColor = s.status == 'accepted'
        ? Colors.green
        : (s.status == 'rejected' ? Colors.red : Colors.orange);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: statusColor.withOpacity(0.12),
                    border: Border.all(color: statusColor.withOpacity(0.35)),
                  ),
                  child: Text(
                    s.status.toUpperCase(),
                    style: TextStyle(fontWeight: FontWeight.w900, color: statusColor),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "${s.appName} • ${_fmtDateTime(s.createdAt)}",
                    style: const TextStyle(fontWeight: FontWeight.w900),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text("#${s.id}", style: const TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),

            const SizedBox(height: 10),

            _kv("Employee", s.employeeName),
            _kv("Customer", s.isWalkIn ? "Walk-in" : s.customerName),
            _kv("Payment", "${s.paymentType}  (${s.rateType})"),
            _kv("Coins", "${s.totalCoins}  (extra: ${s.extraCoins})"),
            _kv("Coin Rate", s.coinRate.toStringAsFixed(4)),
            _kv("Total Amount", s.overRate.toStringAsFixed(2)),
            _kv("Cash Received", s.amountReceived.toStringAsFixed(2)),
            _kv("Due (Credit)", s.usedCredit.toStringAsFixed(2)),
            _kv("Bank", (s.bankName?.isEmpty ?? true) ? "-" : s.bankName!),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              v,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w900),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: const Padding(
        padding: EdgeInsets.all(14),
        child: Text("No sales found for these filters."),
      ),
    );
  }

  String _fmtDate(DateTime d) => "${d.year}-${_two(d.month)}-${_two(d.day)}";
  String _fmtDateTime(DateTime d) =>
      "${_fmtDate(d)} ${_two(d.hour)}:${_two(d.minute)}";
  String _two(int n) => n.toString().padLeft(2, '0');
}

class _GroupSum {
  final String name;
  final int count;
  final double totalCoins;
  final double totalAmount;
  final double totalDue;

  const _GroupSum({
    required this.name,
    this.count = 0,
    this.totalCoins = 0,
    this.totalAmount = 0,
    this.totalDue = 0,
  });

  _GroupSum add(SaleRow r) {
    return _GroupSum(
      name: name,
      count: count + 1,
      totalCoins: totalCoins + r.totalCoins.toDouble(),
      totalAmount: totalAmount + r.overRate,
      totalDue: totalDue + r.usedCredit,
    );
  }
}
