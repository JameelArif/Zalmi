import 'package:flutter/material.dart';

import '../Customers/Customerservice.dart';
import 'Inventoryservice.dart';

class InventoryManagement extends StatefulWidget {
  const InventoryManagement({super.key});

  @override
  State<InventoryManagement> createState() => _InventoryManagementState();
}

class _InventoryManagementState extends State<InventoryManagement> {
  final _inventoryService = InventoryService();
  final _customerService = CustomerService();

  List<ApplicationModel> _applications = [];
  List<ApplicationModel> _filteredApplications = [];
  Map<int, double> _appCustomerCredits = {}; // App ID -> Total Customer Credits

  bool _isLoading = true;
  bool _isAdding = false;
  String _searchQuery = '';

  final _appNameController = TextEditingController();
  final _prevCreditController = TextEditingController();
  final _totalCoinsController = TextEditingController();
  final _perCoinRateController = TextEditingController();
  final _wholesaleRateController = TextEditingController();
  final _searchController = TextEditingController();

  Map<String, dynamic> _statistics = {};

  // ✅ New top summary totals
  double _sumStandardValue = 0.0;   // Σ (coins ÷ perCoinRate)
  double _sumWholesaleValue = 0.0;  // Σ (coins ÷ wholesaleRate)
  double _sumCustomerCredit = 0.0;  // Σ customer_applications.total_credit
  double _sumPreviousCredit = 0.0;  // Σ applications.previous_credit

  @override
  void initState() {
    super.initState();
    _fetchApplications();
    _fetchStatistics();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _appNameController.dispose();
    _prevCreditController.dispose();
    _totalCoinsController.dispose();
    _perCoinRateController.dispose();
    _wholesaleRateController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchApplications() async {
    try {
      setState(() => _isLoading = true);
      final apps = await _inventoryService.getApplications();

      // ✅ 1) customer credit totals per app + overall
      Map<int, double> appCredits = {};
      double allCustomerCredit = 0.0;

      try {
        final customers = await _customerService.getCustomers();
        for (var customer in customers) {
          try {
            final customerApps = await _customerService.getCustomerApplications(customer.id);
            for (var customerApp in customerApps) {
              final int appId = (customerApp['application_id'] as num).toInt();
              final double credit = (customerApp['total_credit'] as num).toDouble();
              appCredits[appId] = (appCredits[appId] ?? 0.0) + credit;
              allCustomerCredit += credit;
            }
          } catch (e) {
            // ignore per-customer failures
          }
        }
      } catch (e) {
        // ignore
      }

      // ✅ 2) inventory value totals - CORRECTED TO DIVISION
      double sumStd = 0.0;
      double sumWs = 0.0;
      double sumPrevCredit = 0.0;

      for (final a in apps) {
        // ✅ CORRECTED: Division instead of multiplication
        if (a.perCoinRate > 0) {
          sumStd += (a.totalCoins / a.perCoinRate);
        }
        if (a.wholesaleRate > 0) {
          sumWs += (a.totalCoins / a.wholesaleRate);
        }
        sumPrevCredit += a.previousCredit;
      }

      setState(() {
        _applications = apps;
        _filteredApplications = apps;
        _appCustomerCredits = appCredits;

        _sumStandardValue = sumStd;
        _sumWholesaleValue = sumWs;
        _sumCustomerCredit = allCustomerCredit;
        _sumPreviousCredit = sumPrevCredit;

        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error: ${e.toString()}', Colors.red);
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchStatistics() async {
    try {
      final stats = await _inventoryService.getStatistics();
      setState(() => _statistics = stats);
    } catch (_) {}
  }

  void _onSearchChanged() {
    _searchQuery = _searchController.text.toLowerCase();
    _filterApplications();
  }

  void _filterApplications() {
    if (_searchQuery.isEmpty) {
      _filteredApplications = _applications;
    } else {
      _filteredApplications = _applications
          .where((app) =>
      app.applicationName.toLowerCase().contains(_searchQuery) ||
          app.id.toString().contains(_searchQuery))
          .toList();
    }
    setState(() {});
  }

  Future<void> _addApplication() async {
    if (_appNameController.text.isEmpty ||
        _prevCreditController.text.isEmpty ||
        _totalCoinsController.text.isEmpty ||
        _perCoinRateController.text.isEmpty ||
        _wholesaleRateController.text.isEmpty) {
      _showSnackBar('Please fill all fields', Colors.red);
      return;
    }

    try {
      setState(() => _isAdding = true);

      await _inventoryService.addApplication(
        applicationName: _appNameController.text.trim(),
        previousCredit: double.parse(_prevCreditController.text),
        totalCoins: double.parse(_totalCoinsController.text),
        perCoinRate: double.parse(_perCoinRateController.text),
        wholesaleRate: double.parse(_wholesaleRateController.text),
      );

      _appNameController.clear();
      _prevCreditController.clear();
      _totalCoinsController.clear();
      _perCoinRateController.clear();
      _wholesaleRateController.clear();

      await _fetchApplications();
      await _fetchStatistics();

      if (mounted) {
        _showSnackBar('Application added successfully!', Colors.green);
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', Colors.red);
    } finally {
      setState(() => _isAdding = false);
    }
  }

  Future<void> _updateApplication(
      ApplicationModel app,
      double prevCredit,
      double newCredit,
      double totalCoins,
      double perCoinRate,
      double wholesaleRate,
      ) async {
    try {
      await _inventoryService.updateApplication(
        id: app.id,
        previousCredit: prevCredit,
        newCredit: newCredit,
        totalCoins: totalCoins,
        perCoinRate: perCoinRate,
        wholesaleRate: wholesaleRate,
      );

      await _fetchApplications();
      await _fetchStatistics();

      if (mounted) {
        _showSnackBar('Application updated successfully!', Colors.green);
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', Colors.red);
    }
  }

  Future<void> _deleteApplication(int id) async {
    try {
      await _inventoryService.deleteApplication(id);
      await _fetchApplications();
      await _fetchStatistics();

      if (mounted) {
        _showSnackBar('Application deleted!', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', Colors.red);
    }
  }

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Add New Application',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close, color: Colors.black54),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildTextField(
                  controller: _appNameController,
                  label: 'Application Name',
                  icon: Icons.app_registration,
                  color: Colors.blue,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _prevCreditController,
                  label: 'Previous Credit',
                  icon: Icons.payments,
                  color: Colors.green,
                  isNumber: true,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _totalCoinsController,
                  label: 'Total Coins',
                  icon: Icons.toll,
                  color: Colors.orange,
                  isNumber: true,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _perCoinRateController,
                  label: 'Per Coin Rate',
                  icon: Icons.trending_up,
                  color: Colors.purple,
                  isNumber: true,
                  decimal: true,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _wholesaleRateController,
                  label: 'Wholesale Rate',
                  icon: Icons.baby_changing_station,
                  color: Colors.indigo,
                  isNumber: true,
                  decimal: true,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isAdding ? null : _addApplication,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      disabledBackgroundColor: Colors.grey,
                    ),
                    child: _isAdding
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : const Text(
                      'Add Application',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditDialog(ApplicationModel app) {
    final nameController = TextEditingController(text: app.applicationName);
    final prevCreditController = TextEditingController(text: app.previousCredit.toString());
    final newCreditController = TextEditingController(text: app.newCredit.toString());
    final totalCoinsController = TextEditingController(text: app.totalCoins.toString());
    final perCoinRateController = TextEditingController(text: app.perCoinRate.toString());
    final wholesaleRateController = TextEditingController(text: app.wholesaleRate.toString());

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Edit Application',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close, color: Colors.black54),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildTextFieldDisabled(
                  controller: nameController,
                  label: 'Application Name',
                  icon: Icons.app_registration,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: prevCreditController,
                  label: 'Previous Credit',
                  icon: Icons.payments,
                  color: Colors.green,
                  isNumber: true,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: newCreditController,
                  label: 'New Credit',
                  icon: Icons.add_circle,
                  color: Colors.blue,
                  isNumber: true,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: totalCoinsController,
                  label: 'Total Coins',
                  icon: Icons.toll,
                  color: Colors.orange,
                  isNumber: true,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: perCoinRateController,
                  label: 'Per Coin Rate',
                  icon: Icons.trending_up,
                  color: Colors.purple,
                  isNumber: true,
                  decimal: true,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: wholesaleRateController,
                  label: 'Wholesale Rate',
                  icon: Icons.baby_changing_station,
                  color: Colors.indigo,
                  isNumber: true,
                  decimal: true,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[300],
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          _updateApplication(
                            app,
                            double.parse(prevCreditController.text),
                            double.parse(newCreditController.text),
                            double.parse(totalCoinsController.text),
                            double.parse(perCoinRateController.text),
                            double.parse(wholesaleRateController.text),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
        ),
      )
          : Column(
        children: [
          // Header
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              margin: const EdgeInsets.only(top: 16, left: 16, right: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Inventory Management',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_applications.length} Applications',
                    style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.9)),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ✅ Top 4 summary cards
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _statisticsCard(
                    label: 'Total Std Value',
                    value: _sumStandardValue.toStringAsFixed(2),
                    icon: Icons.trending_up,
                    color: Colors.teal,
                  ),
                  const SizedBox(width: 12),
                  _statisticsCard(
                    label: 'Total Wholesale Value',
                    value: _sumWholesaleValue.toStringAsFixed(2),
                    icon: Icons.local_offer,
                    color: Colors.deepPurple,
                  ),
                  const SizedBox(width: 12),
                  _statisticsCard(
                    label: 'Customers Total Credit',
                    value: _sumCustomerCredit.toStringAsFixed(2),
                    icon: Icons.people,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 12),
                  _statisticsCard(
                    label: 'Previous Credit Total',
                    value: _sumPreviousCredit.toStringAsFixed(2),
                    icon: Icons.payments,
                    color: Colors.green,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search applications...',
                prefixIcon: const Icon(Icons.search, color: Colors.blue),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.blue, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),

          const SizedBox(height: 16),

          Expanded(
            child: _filteredApplications.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    _searchQuery.isEmpty ? 'No applications yet' : 'No applications found',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _filteredApplications.length,
              itemBuilder: (context, index) {
                final app = _filteredApplications[index];

                // ✅ CORRECTED: Division instead of multiplication
                final stockValue = app.perCoinRate > 0
                    ? (app.totalCoins / app.perCoinRate)
                    : 0.0;

                final standardValue = app.perCoinRate > 0
                    ? (app.totalCoins / app.perCoinRate)
                    : 0.0;

                final wholesaleValue = app.wholesaleRate > 0
                    ? (app.totalCoins / app.wholesaleRate)
                    : 0.0;

                final customerTotalCredit = _appCustomerCredits[app.id] ?? 0.0;

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border(
                        left: BorderSide(color: Colors.green[700]!, width: 5),
                      ),
                      color: Colors.white,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  app.applicationName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              PopupMenuButton(
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    child: const Row(
                                      children: [
                                        Icon(Icons.edit, color: Colors.blue),
                                        SizedBox(width: 8),
                                        Text('Edit'),
                                      ],
                                    ),
                                    onTap: () {
                                      Future.delayed(const Duration(milliseconds: 200), () => _showEditDialog(app));
                                    },
                                  ),
                                  PopupMenuItem(
                                    child: const Row(
                                      children: [
                                        Icon(Icons.delete, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Delete'),
                                      ],
                                    ),
                                    onTap: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Delete Application'),
                                          content: const Text('Are you sure you want to delete this application?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                _deleteApplication(app.id);
                                                Navigator.pop(context);
                                              },
                                              child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),
                          const Divider(height: 1, color: Colors.grey),
                          const SizedBox(height: 12),

                          // ✅ Table with corrected calculations
                          Table(
                            border: TableBorder(
                              horizontalInside: BorderSide(color: Colors.grey[300]!, width: 1),
                              bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                            ),
                            columnWidths: const {
                              0: FlexColumnWidth(1.5),
                              1: FlexColumnWidth(1.5),
                              2: FlexColumnWidth(1.5),
                              3: FlexColumnWidth(1.5),
                            },
                            children: [
                              TableRow(
                                decoration: BoxDecoration(color: Colors.grey[200]),
                                children: [
                                  _tableCell('Previous\nCredit', true),
                                  _tableCell('Customer\nTotal Credit', true),
                                  _tableCell('Total\nCoins', true),
                                  _tableCell('Stock\nValue', true),
                                ],
                              ),
                              TableRow(
                                children: [
                                  _tableCell(app.previousCredit.toStringAsFixed(2), false, Colors.green),
                                  _tableCell(customerTotalCredit.toStringAsFixed(2), false, Colors.deepPurple),
                                  _tableCell(app.totalCoins.toStringAsFixed(2), false, Colors.orange),
                                  _tableCell(stockValue.toStringAsFixed(2), false, Colors.teal),
                                ],
                              ),

                              // ✅ CORRECTED: Show division formula
                              TableRow(
                                decoration: BoxDecoration(color: Colors.grey[200]),
                                children: [
                                  _tableCell('Coins ÷\nRate', true),
                                  _tableCell('Std\nValue', true),
                                  _tableCell('Coins ÷\nWholesale', true),
                                  _tableCell('Wholesale\nValue', true),
                                ],
                              ),
                              TableRow(
                                children: [
                                  _tableCell(
                                    '${app.totalCoins.toStringAsFixed(2)} ÷ ${app.perCoinRate.toStringAsFixed(4)}',
                                    false,
                                    Colors.purple,
                                  ),
                                  _tableCell(standardValue.toStringAsFixed(2), false, Colors.teal),
                                  _tableCell(
                                    '${app.totalCoins.toStringAsFixed(2)} ÷ ${app.wholesaleRate.toStringAsFixed(4)}',
                                    false,
                                    Colors.indigo,
                                  ),
                                  _tableCell(wholesaleValue.toStringAsFixed(2), false, Colors.red),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: Colors.green[700],
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _tableCell(String text, bool isHeader, [Color? color]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: isHeader ? 11 : 13,
          fontWeight: isHeader ? FontWeight.bold : FontWeight.w600,
          color: isHeader ? Colors.black87 : (color ?? Colors.black),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color color,
    bool isNumber = false,
    bool decimal = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber
          ? (decimal
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.number)
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: color),
        prefixIcon: Icon(icon, color: color),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: 2),
        ),
      ),
    );
  }

  Widget _buildTextFieldDisabled({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      enabled: false,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: Colors.grey),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        filled: true,
        fillColor: Colors.grey[100],
      ),
    );
  }

  Widget _statisticsCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
        ],
      ),
    );
  }
}