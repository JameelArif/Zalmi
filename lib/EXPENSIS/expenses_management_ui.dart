import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'expenses_service.dart';

class ExpensesManagement extends StatefulWidget {
  const ExpensesManagement({super.key});

  @override
  State<ExpensesManagement> createState() => _ExpensesManagementState();
}

class _ExpensesManagementState extends State<ExpensesManagement> {
  final _service = ExpensesService();

  bool _loading = true;

  List<ExpenseCategory> _categories = [];
  List<ExpenseItem> _expenses = [];

  // Filters
  DateTime? _fromDate;
  DateTime? _toDate;
  int? _categoryId;
  double? _minAmount;
  double? _maxAmount;
  final _searchCtrl = TextEditingController();

  // Add expense form
  ExpenseCategory? _selectedCat;
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime _expenseDate = DateTime.now();

  // Add category
  final _newCatCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _init();
    _searchCtrl.addListener(() => _reloadExpenses());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _newCatCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() => _loading = true);
    try {
      await _service.ensureDefaultCategories();
      final cats = await _service.getCategories();
      setState(() {
        _categories = cats;
        _selectedCat = cats.isNotEmpty ? cats.first : null;
      });
      await _reloadExpenses();
    } catch (e) {
      _toast("Init failed: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reloadExpenses() async {
    try {
      final list = await _service.getExpenses(
        from: _fromDate,
        to: _toDate,
        categoryId: _categoryId,
        minAmount: _minAmount,
        maxAmount: _maxAmount,
        search: _searchCtrl.text,
      );
      if (!mounted) return;
      setState(() => _expenses = list);
    } catch (e) {
      if (!mounted) return;
      _toast("Load expenses failed: $e");
    }
  }

  double get _total => _expenses.fold(0.0, (s, x) => s + x.amount);

  Map<String, double> get _byCategory {
    final m = <String, double>{};
    for (final e in _expenses) {
      m[e.categoryName] = (m[e.categoryName] ?? 0) + e.amount;
    }
    return m;
  }

  Map<String, double> get _byMonth {
    final m = <String, double>{};
    for (final e in _expenses) {
      final key = "${e.expenseDate.year}-${e.expenseDate.month.toString().padLeft(2, '0')}";
      m[key] = (m[key] ?? 0) + e.amount;
    }
    // sort keys
    final keys = m.keys.toList()..sort();
    final sorted = <String, double>{};
    for (final k in keys) sorted[k] = m[k]!;
    return sorted;
  }

  Future<void> _pickExpenseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expenseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => _expenseDate = picked);
  }

  Future<void> _addExpense() async {
    final cat = _selectedCat;
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    if (cat == null) return _toast("Select category");
    if (amount <= 0) return _toast("Amount must be > 0");

    try {
      await _service.addExpense(
        categoryId: cat.id,
        amount: amount,
        date: _expenseDate,
        description: _descCtrl.text,
      );

      _amountCtrl.clear();
      _descCtrl.clear();
      _expenseDate = DateTime.now();

      await _reloadExpenses();
      _toast("Expense added ✅");
    } catch (e) {
      _toast("Add expense failed: $e");
    }
  }

  Future<void> _addCategory() async {
    final name = _newCatCtrl.text.trim();
    if (name.isEmpty) return _toast("Enter category name");

    try {
      await _service.addCategory(name);
      _newCatCtrl.clear();
      final cats = await _service.getCategories();
      setState(() {
        _categories = cats;
        _selectedCat = cats.isNotEmpty ? cats.first : null;
      });
      _toast("Category added ✅");
    } catch (e) {
      _toast("Add category failed: $e");
    }
  }

  Future<void> _deleteExpense(int id) async {
    try {
      await _service.deleteExpense(id);
      await _reloadExpenses();
      _toast("Deleted ✅");
    } catch (e) {
      _toast("Delete failed: $e");
    }
  }

  void _toast(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Expenses"),
        actions: [
          IconButton(onPressed: _loading ? null : _init, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _init,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _topCards(),
            const SizedBox(height: 14),
            _filtersCard(),
            const SizedBox(height: 14),
            _addExpenseCard(),
            const SizedBox(height: 14),
            _addCategoryCard(),
            const SizedBox(height: 14),
            _chartsCard(),
            const SizedBox(height: 14),
            _expensesList(),
          ],
        ),
      ),
    );
  }

  Widget _topCards() {
    final count = _expenses.length;
    final byCat = _byCategory.length;
    final today = DateTime.now();
    final todayTotal = _expenses
        .where((e) =>
    e.expenseDate.year == today.year &&
        e.expenseDate.month == today.month &&
        e.expenseDate.day == today.day)
        .fold(0.0, (s, x) => s + x.amount);

    return Row(
      children: [
        Expanded(child: _statBox("Total", _total.toStringAsFixed(2), Icons.payments)),
        const SizedBox(width: 10),
        Expanded(child: _statBox("Expenses", "$count", Icons.receipt_long)),
        const SizedBox(width: 10),
        Expanded(child: _statBox("Categories", "$byCat", Icons.category)),
        const SizedBox(width: 10),
        Expanded(child: _statBox("Today", todayTotal.toStringAsFixed(2), Icons.today)),
      ],
    );
  }

  Widget _statBox(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Column(
        children: [
          Icon(icon),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _filtersCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Filters", style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: "Search description",
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<int?>(
              value: _categoryId,
              items: [
                const DropdownMenuItem(value: null, child: Text("All Categories")),
                ..._categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
              ],
              onChanged: (v) async {
                setState(() => _categoryId = v);
                await _reloadExpenses();
              },
              decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "Category"),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _fromDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked == null) return;
                      setState(() => _fromDate = picked);
                      await _reloadExpenses();
                    },
                    icon: const Icon(Icons.date_range),
                    label: Text(_fromDate == null
                        ? "From"
                        : "${_fromDate!.year}-${_fromDate!.month.toString().padLeft(2, '0')}-${_fromDate!.day.toString().padLeft(2, '0')}"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _toDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked == null) return;
                      setState(() => _toDate = picked);
                      await _reloadExpenses();
                    },
                    icon: const Icon(Icons.date_range),
                    label: Text(_toDate == null
                        ? "To"
                        : "${_toDate!.year}-${_toDate!.month.toString().padLeft(2, '0')}-${_toDate!.day.toString().padLeft(2, '0')}"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "Min Amount"),
                    onChanged: (v) async {
                      setState(() => _minAmount = double.tryParse(v));
                      await _reloadExpenses();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "Max Amount"),
                    onChanged: (v) async {
                      setState(() => _maxAmount = double.tryParse(v));
                      await _reloadExpenses();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            FilledButton.tonal(
              onPressed: () async {
                setState(() {
                  _fromDate = null;
                  _toDate = null;
                  _categoryId = null;
                  _minAmount = null;
                  _maxAmount = null;
                  _searchCtrl.text = "";
                });
                await _reloadExpenses();
              },
              child: const Text("Clear Filters"),
            )
          ],
        ),
      ),
    );
  }

  Widget _addExpenseCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Add Expense", style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            DropdownButtonFormField<ExpenseCategory>(
              value: _selectedCat,
              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
              onChanged: (v) => setState(() => _selectedCat = v),
              decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "Category"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "Amount"),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _pickExpenseDate,
              icon: const Icon(Icons.today),
              label: Text(
                "Date: ${_expenseDate.year}-${_expenseDate.month.toString().padLeft(2, '0')}-${_expenseDate.day.toString().padLeft(2, '0')}",
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "Description (optional)"),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _addExpense,
              icon: const Icon(Icons.add),
              label: const Text("Save Expense"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addCategoryCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Add Category", style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            TextField(
              controller: _newCatCtrl,
              decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "Category name"),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: _addCategory,
              icon: const Icon(Icons.category),
              label: const Text("Add Category"),
            ),
            const SizedBox(height: 8),
            Text(
              "Default 15 categories are auto-created once per admin.",
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            )
          ],
        ),
      ),
    );
  }

  Widget _chartsCard() {
    final byCat = _byCategory;
    final byMonth = _byMonth;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Graphs", style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),

            // PIE: Category share
            if (byCat.isEmpty)
              Text("No data for charts", style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))
            else ...[
              SizedBox(
                height: 220,
                child: PieChart(
                  PieChartData(
                    sections: byCat.entries.map((e) {
                      final pct = _total == 0 ? 0 : (e.value / _total) * 100.0;
                      return PieChartSectionData(
                        value: e.value,
                        title: "${pct.toStringAsFixed(0)}%",
                        radius: 80,
                        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                children: byCat.entries
                    .take(10)
                    .map((e) => Chip(label: Text("${e.key}: ${e.value.toStringAsFixed(0)}")))
                    .toList(),
              ),
              const SizedBox(height: 18),

              // BAR: Monthly totals
              SizedBox(
                height: 240,
                child: BarChart(
                  BarChartData(
                    gridData: const FlGridData(show: true),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 1,
                          getTitlesWidget: (v, meta) {
                            final idx = v.toInt();
                            final keys = byMonth.keys.toList();
                            if (idx < 0 || idx >= keys.length) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(keys[idx], style: const TextStyle(fontSize: 10)),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: [
                      for (int i = 0; i < byMonth.length; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: byMonth.values.elementAt(i),
                              width: 14,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ],
                        )
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _expensesList() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Expenses List", style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            if (_expenses.isEmpty)
              Text("No expenses found", style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))
            else
              ..._expenses.map((e) {
                final d = "${e.expenseDate.year}-${e.expenseDate.month.toString().padLeft(2, '0')}-${e.expenseDate.day.toString().padLeft(2, '0')}";
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text("${e.categoryName} • ${e.amount.toStringAsFixed(2)}",
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text("$d ${e.description == null || e.description!.trim().isEmpty ? "" : "• ${e.description}"}"),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteExpense(e.id),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
