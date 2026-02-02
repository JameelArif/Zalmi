import 'package:flutter/material.dart';

import 'Inventoryservice.dart';


class InventoryManagement extends StatefulWidget {
  const InventoryManagement({super.key});

  @override
  State<InventoryManagement> createState() => _InventoryManagementState();
}

class _InventoryManagementState extends State<InventoryManagement> {
  final _inventoryService = InventoryService();
  List<ApplicationModel> _applications = [];
  List<ApplicationModel> _filteredApplications = [];
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
      setState(() {
        _applications = apps;
        _filteredApplications = apps;
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
    } catch (e) {
      print('Error fetching statistics: $e');
    }
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
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'New Credit will be set to 0',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
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
                        valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : const Text(
                      'Add Application',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
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
    final prevCreditController =
    TextEditingController(text: app.previousCredit.toString());
    final newCreditController =
    TextEditingController(text: app.newCredit.toString());
    final totalCoinsController =
    TextEditingController(text: app.totalCoins.toString());
    final perCoinRateController =
    TextEditingController(text: app.perCoinRate.toString());
    final wholesaleRateController =
    TextEditingController(text: app.wholesaleRate.toString());

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
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Credit',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(double.tryParse(prevCreditController.text) ?? 0) + (double.tryParse(newCreditController.text) ?? 0)}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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
          // Header with green gradient - reduced width with rounded borders
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              margin: const EdgeInsets.only(top: 16, left: 16, right: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF2E7D32),
                    Color(0xFF1B5E20),
                  ],
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
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_applications.length} Applications • Total Coins: ${(_statistics['totalCoins'] ?? 0).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Statistics Cards
          if (_statistics.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _statisticsCard(
                      label: 'Total Apps',
                      value: _statistics['totalApplications'].toString(),
                      icon: Icons.inventory_2,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 12),
                    _statisticsCard(
                      label: 'Total Coins',
                      value: (_statistics['totalCoins'] ?? 0)
                          .toStringAsFixed(2),
                      icon: Icons.toll,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 12),
                    _statisticsCard(
                      label: 'Avg Coin Rate',
                      value: (_statistics['avgPerCoinRate'] ?? 0)
                          .toStringAsFixed(4),
                      icon: Icons.trending_up,
                      color: Colors.purple,
                    ),
                    const SizedBox(width: 12),
                    _statisticsCard(
                      label: 'Avg Wholesale',
                      value: (_statistics['avgWholesaleRate'] ?? 0)
                          .toStringAsFixed(4),
                      icon: Icons.baby_changing_station,
                      color: Colors.indigo,
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
                prefixIcon:
                const Icon(Icons.search, color: Colors.blue),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                  const BorderSide(color: Colors.blue, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                  const BorderSide(color: Colors.blue, width: 2),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Applications List - Tabular View
          Expanded(
            child: _filteredApplications.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory_2,
                    size: 64,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _searchQuery.isEmpty
                        ? 'No applications yet'
                        : 'No applications found',
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
                final coinValue = app.totalCoins * app.perCoinRate;
                final wholesaleValue =
                    app.totalCoins * app.wholesaleRate;

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border(
                        left: BorderSide(
                          color: Colors.green[700]!,
                          width: 5,
                        ),
                      ),
                      color: Colors.white,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          // Application Name Header with Action Menu
                          Row(
                            mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
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
                                        Icon(Icons.edit,
                                            color: Colors.blue),
                                        SizedBox(width: 8),
                                        Text('Edit'),
                                      ],
                                    ),
                                    onTap: () {
                                      Future.delayed(
                                        const Duration(
                                            milliseconds: 200),
                                            () =>
                                            _showEditDialog(app),
                                      );
                                    },
                                  ),
                                  PopupMenuItem(
                                    child: const Row(
                                      children: [
                                        Icon(Icons.delete,
                                            color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Delete'),
                                      ],
                                    ),
                                    onTap: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) =>
                                            AlertDialog(
                                              title: const Text(
                                                  'Delete Application'),
                                              content: const Text(
                                                  'Are you sure you want to delete this application?'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          context),
                                                  child: const Text(
                                                      'Cancel'),
                                                ),
                                                TextButton(
                                                  onPressed: () {
                                                    _deleteApplication(
                                                        app.id);
                                                    Navigator.pop(
                                                        context);
                                                  },
                                                  child: const Text(
                                                    'Delete',
                                                    style: TextStyle(
                                                        color: Colors
                                                            .red),
                                                  ),
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

                          // Tabular Data with Headers in Columns
                          Table(
                            border: TableBorder(
                              horizontalInside: BorderSide(
                                color: Colors.grey[300]!,
                                width: 1,
                              ),
                              bottom: BorderSide(
                                color: Colors.grey[300]!,
                                width: 1,
                              ),
                            ),
                            columnWidths: const {
                              0: FlexColumnWidth(1.5),
                              1: FlexColumnWidth(1.5),
                              2: FlexColumnWidth(1.5),
                              3: FlexColumnWidth(1.5),
                            },
                            children: [
                              // Header Row
                              TableRow(
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                ),
                                children: [
                                  _tableCell('Previous\nCredit', true),
                                  _tableCell('New\nCredit', true),
                                  _tableCell('Total\nCredit', true),
                                  _tableCell('Total\nCoins', true),
                                ],
                              ),
                              // Data Row 1
                              TableRow(
                                children: [
                                  _tableCell(
                                    app.previousCredit
                                        .toStringAsFixed(2),
                                    false,
                                    Colors.green,
                                  ),
                                  _tableCell(
                                    app.newCredit.toStringAsFixed(2),
                                    false,
                                    Colors.blue,
                                  ),
                                  _tableCell(
                                    app.totalCredit
                                        .toStringAsFixed(2),
                                    false,
                                    Colors.deepPurple,
                                  ),
                                  _tableCell(
                                    app.totalCoins.toStringAsFixed(2),
                                    false,
                                    Colors.orange,
                                  ),
                                ],
                              ),
                              // Header Row 2
                              TableRow(
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                ),
                                children: [
                                  _tableCell('Per Coin\nRate', true),
                                  _tableCell('Coin\nValue', true),
                                  _tableCell('Wholesale\nRate', true),
                                  _tableCell('Wholesale\nValue', true),
                                ],
                              ),
                              // Data Row 2
                              TableRow(
                                children: [
                                  _tableCell(
                                    app.perCoinRate
                                        .toStringAsFixed(4),
                                    false,
                                    Colors.purple,
                                  ),
                                  _tableCell(
                                    coinValue.toStringAsFixed(2),
                                    false,
                                    Colors.teal,
                                  ),
                                  _tableCell(
                                    app.wholesaleRate
                                        .toStringAsFixed(4),
                                    false,
                                    Colors.indigo,
                                  ),
                                  _tableCell(
                                    wholesaleValue.toStringAsFixed(2),
                                    false,
                                    Colors.red,
                                  ),
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

  Widget _tableCell(
      String text,
      bool isHeader, [
        Color? color,
      ]) {
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
          ? decimal
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.number
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
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}