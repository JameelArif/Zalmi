import 'package:flutter/material.dart';
import 'admin_sales_approval_service.dart';

class AdminSalesApprovalScreen extends StatefulWidget {
  const AdminSalesApprovalScreen({super.key});

  @override
  State<AdminSalesApprovalScreen> createState() => _AdminSalesApprovalScreenState();
}

class _AdminSalesApprovalScreenState extends State<AdminSalesApprovalScreen> {
  final _service = AdminSalesApprovalService();

  bool _loading = true;
  AdminUserContext? _ctx;

  List<EmployeeOption> _employees = [];
  List<AppOption> _apps = [];

  String _status = 'pending'; // pending/accepted/rejected/all
  int? _employeeId;
  int? _applicationId;
  DateTime? _from;
  DateTime? _to;

  List<SaleRow> _rows = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _init() async {
    setState(() => _loading = true);
    try {
      final ctx = await _service.getAdminContext();
      final employees = await _service.getEmployeesForAdmin(adminId: ctx.adminId);
      final apps = await _service.getAppsForAdmin(adminId: ctx.adminId);

      if (!mounted) return;
      setState(() {
        _ctx = ctx;
        _employees = employees;
        _apps = apps;
      });

      await _refresh();
    } catch (e) {
      if (!mounted) return;
      _toast("Load failed: $e");
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

  Future<void> _openDecision(SaleRow s) async {
    final ctx = _ctx;
    if (ctx == null) return;

    CustomerCreditsSummary? credits;
    if (!s.isWalkIn && s.customerId != null) {
      try {
        credits = await _service.getCustomerCreditsAllApps(customerId: s.customerId!);
      } catch (_) {}
    }

    final result = await showModalBottomSheet<_DecisionResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DecisionSheet(sale: s, credits: credits),
    );

    if (result == null) return;

    setState(() => _loading = true);
    try {
      await _service.decideSale(
        adminId: ctx.adminId,
        saleId: s.id,
        accept: result.accept,
        comments: result.comments,
      );
      if (!mounted) return;
      _toast(result.accept ? "Sale Accepted" : "Sale Rejected");
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      _toast("Decision failed: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _rows.where((r) => r.status.toLowerCase() == 'pending').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Approvals"),
        actions: [
          IconButton(onPressed: _loading ? null : _refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _topStats(pendingCount),
            const SizedBox(height: 12),
            _filtersCard(),
            const SizedBox(height: 14),
            Text("Sales (${_rows.length})",
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            if (_rows.isEmpty) _emptyCard(),
            ..._rows.map(_saleCard),
          ],
        ),
      ),
    );
  }

  Widget _topStats(int pendingCount) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: const Icon(Icons.verified_user),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Pending approvals: $pendingCount",
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: _refresh,
              icon: const Icon(Icons.sync),
              label: const Text("Refresh"),
            ),
          ],
        ),
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
            const SizedBox(height: 10),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip("pending", "Pending"),
                _chip("accepted", "Accepted"),
                _chip("rejected", "Rejected"),
                _chip("all", "All"),
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
              initialValue: _employeeId,
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

            const SizedBox(height: 10),

            DropdownButtonFormField<int?>(
              initialValue: _applicationId,
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

            const SizedBox(height: 12),

            FilledButton.icon(
              onPressed: () {
                setState(() {
                  _status = 'pending';
                  _from = null;
                  _to = null;
                  _employeeId = null;
                  _applicationId = null;
                });
                _refresh();
              },
              icon: const Icon(Icons.restart_alt),
              label: const Text("Reset Filters"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String value, String text) {
    return ChoiceChip(
      label: Text(text),
      selected: _status == value,
      onSelected: (_) {
        setState(() => _status = value);
        _refresh();
      },
    );
  }

  Widget _saleCard(SaleRow s) {
    final st = s.status.toLowerCase();
    final isPending = st == 'pending';

    final badge = st == 'accepted'
        ? ("Accepted", Icons.check_circle)
        : st == 'rejected'
        ? ("Rejected", Icons.cancel)
        : ("Pending", Icons.hourglass_top);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: isPending ? () => _openDecision(s) : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text("${s.appName}  •  #${s.id}",
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                  ),
                  _statusBadge(badge.$1, badge.$2),
                ],
              ),
              const SizedBox(height: 10),
              _kv("Date", _fmtDateTime(s.createdAt)),
              _kv("Employee", s.employeeName),
              _kv("Customer", s.isWalkIn ? "Walk-in" : "${s.customerName} (${s.customerContact})"),
              _kv("Payment", "${s.paymentType.toUpperCase()} • ${s.rateType.toUpperCase()}"),
              _kv("Coins", "${s.coins} + ${s.extraCoins} = ${s.totalCoins}"),
              _kv("Total Amount", s.overRate.toStringAsFixed(2)),
              _kv("Cash Received", s.amountReceived.toStringAsFixed(2)),
              _kv("Due (Customer owes)", s.dueAmount.toStringAsFixed(2)),
              if (s.bankLabel != null) _kv("Bank", s.bankLabel!),
              if (isPending) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _openDecision(s),
                  icon: const Icon(Icons.fact_check),
                  label: const Text("Review / Decide"),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(child: Text(k, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
          const SizedBox(width: 10),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
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
        child: Text("No results for selected filters."),
      ),
    );
  }

  String _fmtDate(DateTime d) => "${d.year}-${_two(d.month)}-${_two(d.day)}";
  String _fmtDateTime(DateTime d) => "${_fmtDate(d)}  ${_two(d.hour)}:${_two(d.minute)}";
  String _two(int v) => v.toString().padLeft(2, '0');
}

class _DecisionSheet extends StatefulWidget {
  final SaleRow sale;
  final CustomerCreditsSummary? credits;
  const _DecisionSheet({required this.sale, required this.credits});

  @override
  State<_DecisionSheet> createState() => _DecisionSheetState();
}

class _DecisionSheetState extends State<_DecisionSheet> {
  final _commentCtrl = TextEditingController();

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.sale;
    final credits = widget.credits;

    double dueInThisApp = 0;
    double totalDueAllApps = 0;

    if (credits != null) {
      totalDueAllApps = credits.totalAllApps;
      final match = credits.perApp.where((x) => x.applicationId == s.applicationId).toList();
      if (match.isNotEmpty) dueInThisApp = match.first.credit;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Column(
        children: [
          Text("Sale #${s.id}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              children: [
                _tile("Employee", s.employeeName),
                _tile("App", s.appName),
                _tile("Customer", s.isWalkIn ? "Walk-in" : "${s.customerName} (${s.customerContact})"),
                _tile("Total Amount", s.overRate.toStringAsFixed(2)),
                _tile("Cash Received", s.amountReceived.toStringAsFixed(2)),
                _tile("Due (This sale)", s.dueAmount.toStringAsFixed(2)),
                if (s.bankLabel != null) _tile("Bank", s.bankLabel!),

                if (!s.isWalkIn && credits != null) ...[
                  const SizedBox(height: 10),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text("Customer Credit (Customer owes you)", style: TextStyle(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 8),
                          _line("Total Due (All apps)", totalDueAllApps.toStringAsFixed(2)),
                          _line("Due in this App (Before accept)", dueInThisApp.toStringAsFixed(2)),
                          const SizedBox(height: 10),
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: const Text("Due per App", style: TextStyle(fontWeight: FontWeight.w900)),
                            children: [
                              const Divider(height: 1),
                              ...credits.perApp.map((c) => ListTile(
                                dense: true,
                                title: Text(c.appName),
                                trailing: Text(c.credit.toStringAsFixed(2),
                                    style: const TextStyle(fontWeight: FontWeight.w900)),
                              )),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 10),
                TextField(
                  controller: _commentCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: "Admin comments",
                    hintText: "Write reason / notes...",
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context, _DecisionResult(accept: false, comments: _commentCtrl.text)),
                  icon: const Icon(Icons.close),
                  label: const Text("Reject"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context, _DecisionResult(accept: true, comments: _commentCtrl.text)),
                  icon: const Icon(Icons.check),
                  label: const Text("Accept"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tile(String k, String v) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        title: Text(k, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(v),
      ),
    );
  }

  Widget _line(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(child: Text(k)),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _DecisionResult {
  final bool accept;
  final String comments;
  _DecisionResult({required this.accept, required this.comments});
}
