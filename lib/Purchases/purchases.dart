import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'purchases_service.dart';

class AdminPurchasesPage extends StatefulWidget {
  const AdminPurchasesPage({super.key});

  @override
  State<AdminPurchasesPage> createState() => _AdminPurchasesPageState();
}

class _AdminPurchasesPageState extends State<AdminPurchasesPage> {
  final _svc = PurchasesService();

  int? _adminId;

  // UI State
  bool _headerLoading = false;
  bool _searching = false;
  bool _searchedOnce = false;

  // Data
  List<Map<String, dynamic>> _apps = [];
  List<Map<String, dynamic>> _banks = [];
  List<Map<String, dynamic>> _purchaseRows = [];

  // Filters
  DateTime? _filterFrom;
  DateTime? _filterTo;
  int? _filterAppId;
  String _filterPaymentType = 'all';
  String _filterSearchText = '';

  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadHeader();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD APPS & BANKS
  // ============================================================

  Future<void> _loadHeader() async {
    setState(() => _headerLoading = true);
    try {
      _adminId = await _svc.getAdminId();
      _apps = await _svc.fetchAppsInventory();
      _banks = await _svc.fetchActiveBanks(_adminId!);

      print('✅ Loaded ${_apps.length} apps and ${_banks.length} banks');
    } catch (e) {
      print('❌ Header load error: $e');
      _toast('Load error: $e');
    } finally {
      if (mounted) setState(() => _headerLoading = false);
    }
  }

  // ============================================================
  // SEARCH PURCHASES
  // ============================================================

  Future<void> _searchPurchases() async {
    if (_adminId == null) {
      _toast('Admin ID not loaded');
      return;
    }

    setState(() {
      _searching = true;
      _searchedOnce = true;
      _purchaseRows = [];
    });

    try {
      _purchaseRows = await _svc.searchPurchases(
        adminId: _adminId!,
        from: _filterFrom,
        to: _filterTo,
        applicationId: _filterAppId,
        paymentType: _filterPaymentType,
        searchText: _filterSearchText,
      );

      print('✅ Found ${_purchaseRows.length} purchases');
    } catch (e) {
      print('❌ Search error: $e');
      _toast('Search error: $e');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  // ============================================================
  // OPEN TOPUP DIALOG
  // ============================================================

  Future<void> _openTopupDialog() async {
    if (_adminId == null) {
      _toast('Admin not loaded');
      return;
    }

    if (_apps.isEmpty) {
      _toast('No apps found');
      return;
    }

    // Selected values
    int selectedAppId = _svc.toInt(_apps.first['id']);
    String selectedPaymentType = 'cash';
    int? selectedBankId =
    _banks.isNotEmpty ? _svc.toInt(_banks.first['id']) : null;

    // Controllers
    final coinsCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final usdCtrl = TextEditingController();
    final cashCtrl = TextEditingController();
    final bankCtrl = TextEditingController();
    final vendorCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    DateTime purchaseDate = DateTime.now();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Purchase'),
        content: StatefulBuilder(
          builder: (context, setLocalState) {
            final isBankNeeded = selectedPaymentType == 'bank' ||
                selectedPaymentType == 'mix';

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1) Application
                  DropdownButtonFormField<int>(
                    value: selectedAppId,
                    items: _apps
                        .map((a) => DropdownMenuItem<int>(
                      value: _svc.toInt(a['id']),
                      child: Text(a['application_name'] ?? 'App'),
                    ))
                        .toList(),
                    onChanged: (v) =>
                        setLocalState(() => selectedAppId = v ?? selectedAppId),
                    decoration: const InputDecoration(
                      labelText: 'Application',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 2) Coins & Amount PKR (2 columns)
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: coinsCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Coins',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: amountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Amount PKR',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 3) Amount USD
                  TextField(
                    controller: usdCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount USD (optional)',
                      border: OutlineInputBorder(),
                      prefixText: '\$ ',
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 4) Payment Type
                  DropdownButtonFormField<String>(
                    value: selectedPaymentType,
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('Cash')),
                      DropdownMenuItem(value: 'bank', child: Text('Bank')),
                      DropdownMenuItem(value: 'mix', child: Text('Mix')),
                    ],
                    onChanged: (v) => setLocalState(
                            () => selectedPaymentType = v ?? 'cash'),
                    decoration: const InputDecoration(
                      labelText: 'Payment Type',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 5) Bank (if needed)
                  if (isBankNeeded) ...[
                    if (_banks.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('No active bank accounts'),
                      )
                    else
                      DropdownButtonFormField<int>(
                        value: selectedBankId,
                        items: _banks
                            .map((b) => DropdownMenuItem<int>(
                          value: _svc.toInt(b['id']),
                          child: Text(
                            '${b['bank_name']} • ${b['account_number']}',
                          ),
                        ))
                            .toList(),
                        onChanged: (v) =>
                            setLocalState(() => selectedBankId = v),
                        decoration: const InputDecoration(
                          labelText: 'Bank Account',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    const SizedBox(height: 12),
                  ],

                  // 6) Mix amounts (if mix payment)
                  if (selectedPaymentType == 'mix') ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: cashCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Cash',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: bankCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Bank',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  // 7) Vendor & Note
                  TextField(
                    controller: vendorCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Vendor Name (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Note (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 8) Purchase Date
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        firstDate: DateTime(2020, 1, 1),
                        lastDate:
                        DateTime(DateTime.now().year + 2, 12, 31),
                        initialDate: purchaseDate,
                      );
                      if (picked != null) {
                        setLocalState(() => purchaseDate = picked);
                      }
                    },
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      'Date: ${DateFormat('yyyy-MM-dd').format(purchaseDate)}',
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              // Validate
              final coins = _svc.toDouble(coinsCtrl.text);
              final amount = _svc.toDouble(amountCtrl.text);

              if (coins <= 0 || amount <= 0) {
                _toast('Enter coins and amount');
                return;
              }

              if ((selectedPaymentType == 'bank' ||
                  selectedPaymentType == 'mix') &&
                  selectedBankId == null) {
                _toast('Select bank account');
                return;
              }

              double? cashAmt;
              double? bankAmt;

              if (selectedPaymentType == 'mix') {
                cashAmt = _svc.toDouble(cashCtrl.text);
                bankAmt = _svc.toDouble(bankCtrl.text);

                if (cashAmt <= 0 || bankAmt <= 0) {
                  _toast('Enter cash + bank split');
                  return;
                }

                final sum = cashAmt + bankAmt;
                if ((sum - amount).abs() > 0.01) {
                  _toast('Cash + Bank must equal Amount');
                  return;
                }
              }

              Navigator.pop(ctx);
              await _submitTopup(
                appId: selectedAppId,
                coins: coins,
                amount: amount,
                usdAmount: _svc.toDouble(usdCtrl.text),
                paymentType: selectedPaymentType,
                bankId: selectedBankId,
                cashAmount: cashAmt,
                bankAmount: bankAmt,
                vendor: vendorCtrl.text.trim(),
                note: noteCtrl.text.trim(),
                purchaseDate: purchaseDate,
              );
            },
            icon: const Icon(Icons.add_circle),
            label: const Text('Add Purchase'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SUBMIT TOPUP
  // ============================================================

  Future<void> _submitTopup({
    required int appId,
    required double coins,
    required double amount,
    double? usdAmount,
    required String paymentType,
    int? bankId,
    double? cashAmount,
    double? bankAmount,
    required String vendor,
    required String note,
    required DateTime purchaseDate,
  }) async {
    if (_adminId == null) return;

    try {
      await _svc.topupPurchase(
        adminId: _adminId!,
        applicationId: appId,
        purchasedCoins: coins,
        amountPkr: amount,
        amountUsd: usdAmount,
        paymentType: paymentType,
        bankAccountId: bankId,
        cashAmount: cashAmount,
        bankAmount: bankAmount,
        vendorName: vendor.isEmpty ? null : vendor,
        note: note.isEmpty ? null : note,
        purchaseDate: purchaseDate,
      );

      _toast('✅ Purchase added & coins topped up!');

      // Reload header (refresh app coins)
      await _loadHeader();

      // Re-search if already searched
      if (_searchedOnce) {
        await _searchPurchases();
      }
    } catch (e) {
      print('❌ Top-up error: $e');
      _toast('Error: $e');
    }
  }

  // ============================================================
  // BUILD UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final totalPkr = _purchaseRows.fold<double>(
        0.0, (s, r) => s + _svc.toDouble(r['amount_pkr']));
    final totalCoins = _purchaseRows.fold<double>(
        0.0, (s, r) => s + _svc.toDouble(r['purchased_coins']));
    final totalUsd = _purchaseRows.fold<double>(
        0.0, (s, r) => s + _svc.toDouble(r['amount_usd']));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchases'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            onPressed: _headerLoading ? null : _loadHeader,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _headerLoading ? null : _openTopupDialog,
        icon: const Icon(Icons.add),
        label: const Text('Purchase'),
      ),
      body: _headerLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCoinsCard(),
          const SizedBox(height: 14),
          _buildFiltersCard(),
          const SizedBox(height: 10),
          _buildResultsCard(
            totalPkr: totalPkr,
            totalCoins: totalCoins,
            totalUsd: totalUsd,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // COINS INVENTORY CARD
  // ============================================================

  Widget _buildCoinsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current Coins Inventory',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_apps.isEmpty)
              Text(
                'No apps found',
                style: TextStyle(color: Colors.grey[700]),
              ),
            if (_apps.isNotEmpty)
              ..._apps.map((app) {
                final name = app['application_name'] ?? 'App';
                final coins = _svc.toDouble(app['total_coins']);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${coins.toStringAsFixed(2)} coins',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // FILTERS CARD
  // ============================================================

  Widget _buildFiltersCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Search Purchases',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Date range
            Row(
              children: [
                Expanded(
                  child: _dateButton(
                    'From',
                    _filterFrom,
                        (d) => setState(() => _filterFrom = d),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _dateButton(
                    'To',
                    _filterTo,
                        (d) => setState(() => _filterTo = d),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Application filter
            DropdownButtonFormField<int?>(
              value: _filterAppId,
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('All Apps'),
                ),
                ..._apps.map((a) => DropdownMenuItem<int?>(
                  value: _svc.toInt(a['id']),
                  child: Text(a['application_name'] ?? 'App'),
                )),
              ],
              onChanged: (v) => setState(() => _filterAppId = v),
              decoration: const InputDecoration(
                labelText: 'Application',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // Payment type filter
            DropdownButtonFormField<String>(
              value: _filterPaymentType,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Payments')),
                DropdownMenuItem(value: 'cash', child: Text('Cash')),
                DropdownMenuItem(value: 'bank', child: Text('Bank')),
                DropdownMenuItem(value: 'mix', child: Text('Mix')),
              ],
              onChanged: (v) =>
                  setState(() => _filterPaymentType = v ?? 'all'),
              decoration: const InputDecoration(
                labelText: 'Payment Type',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // Text search
            TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                labelText: 'Search (vendor / note / app / id)',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => _filterSearchText = v,
            ),
            const SizedBox(height: 12),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _searching ? null : _searchPurchases,
                    icon: const Icon(Icons.search),
                    label: const Text('Search'),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: _searching
                      ? null
                      : () {
                    setState(() {
                      _filterFrom = null;
                      _filterTo = null;
                      _filterAppId = null;
                      _filterPaymentType = 'all';
                      _filterSearchText = '';
                      _searchCtrl.clear();
                      _searchedOnce = false;
                      _purchaseRows = [];
                    });
                  },
                  child: const Text('Reset'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // RESULTS CARD
  // ============================================================

  Widget _buildResultsCard({
    required double totalPkr,
    required double totalCoins,
    required double totalUsd,
  }) {
    final totalSellingValue = _purchaseRows.fold<double>(
        0.0, (s, r) => s + _svc.toDouble(r['selling_price_value']));
    final totalWholesaleValue = _purchaseRows.fold<double>(
        0.0, (s, r) => s + _svc.toDouble(r['wholesale_price_value']));

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Purchase Records',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            if (!_searchedOnce)
              Text(
                'Use filters and press Search',
                style: TextStyle(color: Colors.grey[700]),
              ),

            if (_searching)
              const Center(
                  child: Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(),
                  )),

            if (_searchedOnce && !_searching) ...[
              // Stats
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _pill('Count', _purchaseRows.length.toString(), Colors.blue),
                  _pill('Total PKR', totalPkr.toStringAsFixed(2), Colors.green),
                  _pill('Total USD', '\$${totalUsd.toStringAsFixed(2)}', Colors.teal),
                  _pill('Total Coins', totalCoins.toStringAsFixed(2), Colors.purple),
                  _pill(
                    'Cost/Coin PKR',
                    totalCoins > 0 ? (totalPkr / totalCoins).toStringAsFixed(2) : '0',
                    Colors.orange,
                  ),
                  _pill(
                    'Selling Value',
                    totalSellingValue.toStringAsFixed(2),
                    Colors.indigo,
                  ),
                  _pill(
                    'Wholesale Value',
                    totalWholesaleValue.toStringAsFixed(2),
                    Colors.deepPurple,
                  ),
                  _pill(
                    'Profit (Selling)',
                    (totalSellingValue - totalPkr).toStringAsFixed(2),
                    (totalSellingValue - totalPkr) >= 0 ? Colors.green : Colors.red,
                  ),
                  _pill(
                    'Profit (Wholesale)',
                    (totalWholesaleValue - totalPkr).toStringAsFixed(2),
                    (totalWholesaleValue - totalPkr) >= 0 ? Colors.green : Colors.red,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Results
              if (_purchaseRows.isEmpty)
                Text(
                  'No purchases found',
                  style: TextStyle(color: Colors.grey[700]),
                ),

              if (_purchaseRows.isNotEmpty)
                ..._purchaseRows.take(100).map((r) {
                  final id = _svc.toInt(r['id']);
                  final date = r['purchase_date'] ?? '';
                  final appName = r['applications']?['application_name'] ?? 'App';
                  final payType = r['payment_type'] ?? 'cash';
                  final coins = _svc.toDouble(r['purchased_coins']);
                  final pkr = _svc.toDouble(r['amount_pkr']);
                  final usd = _svc.toDouble(r['amount_usd']);
                  final costPerCoin = coins > 0 ? pkr / coins : 0;
                  final vendor = r['vendor_name'] ?? '';
                  final note = r['note'] ?? '';

                  final sellingValue = _svc.toDouble(r['selling_price_value']);
                  final wholesaleValue = _svc.toDouble(r['wholesale_price_value']);
                  final perCoinRate = _svc.toDouble(r['applications']?['per_coin_rate']);
                  final wholesaleRate = _svc.toDouble(r['applications']?['wholesale_rate']);

                  String subtitle = date.toString().split('.')[0];
                  if (vendor.isNotEmpty) subtitle += '\n👤 Vendor: $vendor';
                  if (usd > 0) subtitle += '\n💵 USD: \$${usd.toStringAsFixed(2)}';

                  if (perCoinRate > 0) {
                    subtitle += '\n💰 Selling: PKR ${sellingValue.toStringAsFixed(2)} (@${perCoinRate.toStringAsFixed(2)} coins/PKR)';
                  }
                  if (wholesaleRate > 0) {
                    subtitle += '\n📦 Wholesale: PKR ${wholesaleValue.toStringAsFixed(2)} (@${wholesaleRate.toStringAsFixed(2)} coins/PKR)';
                  }

                  if (payType == 'mix') {
                    final cash = _svc.toDouble(r['cash_amount']);
                    final bank = _svc.toDouble(r['bank_amount']);
                    subtitle +=
                    '\n💸 Cash: ${cash.toStringAsFixed(2)} • 🏦 Bank: ${bank.toStringAsFixed(2)}';
                  } else if (payType == 'bank' &&
                      (r['bank_accounts']?['bank_name'] ?? '').isNotEmpty) {
                    final bank = r['bank_accounts']?['bank_name'] ?? '';
                    final acc = r['bank_accounts']?['account_number'] ?? '';
                    subtitle += '\n🏦 $bank • $acc';
                  }
                  if (note.isNotEmpty) subtitle += '\n📝 $note';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    elevation: 1,
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: CircleAvatar(
                        backgroundColor: payType == 'cash'
                            ? Colors.green.withOpacity(0.2)
                            : payType == 'bank'
                            ? Colors.blue.withOpacity(0.2)
                            : Colors.purple.withOpacity(0.2),
                        child: Text(
                          payType[0].toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: payType == 'cash'
                                ? Colors.green
                                : payType == 'bank'
                                ? Colors.blue
                                : Colors.purple,
                          ),
                        ),
                      ),
                      title: Text(
                        '$appName • ${payType.toUpperCase()}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        subtitle,
                        style: const TextStyle(fontSize: 12),
                      ),
                      isThreeLine: true,
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'PKR ${pkr.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: Colors.green,
                            ),
                          ),
                          Text(
                            '${coins.toStringAsFixed(2)} coins',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[700]),
                          ),
                          Text(
                            '${costPerCoin.toStringAsFixed(2)}/coin',
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  );
                }),

              if (_purchaseRows.length > 100)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Showing first 100 of ${_purchaseRows.length}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  Widget _pill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontWeight: FontWeight.w900,
          color: color,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _dateButton(
      String label,
      DateTime? value,
      ValueChanged<DateTime?> onPick,
      ) {
    final txt = value == null
        ? '$label: Any'
        : '$label: ${DateFormat('yyyy-MM-dd').format(value)}';

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

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}