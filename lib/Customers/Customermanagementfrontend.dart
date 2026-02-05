import 'package:flutter/material.dart';

import '../Inventory/Inventoryservice.dart';
import 'CustomersProfile.dart';
import 'Customerservice.dart';


class CustomerManagement extends StatefulWidget {
  const CustomerManagement({super.key});

  @override
  State<CustomerManagement> createState() => _CustomerManagementState();
}

class _CustomerManagementState extends State<CustomerManagement> {
  final _customerService = CustomerService();
  final _inventoryService = InventoryService();

  List<CustomerModel> _customers = [];
  List<CustomerModel> _filteredCustomers = [];
  List<ApplicationModel> _applications = [];

  bool _isLoading = false;
  bool _isAdding = false;
  String _searchQuery = '';
  String _filterType = 'All';
  int? _selectedAppFilter;

  final _customerNameController = TextEditingController();
  final _customerContactController = TextEditingController();
  final _searchController = TextEditingController();

  int _totalCustomers = 0;
  double _totalCredit = 0.0;

  @override
  void initState() {
    super.initState();
    _loadApplications();
    _loadCustomers();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerContactController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadApplications() async {
    try {
      final apps = await _inventoryService.getApplications();
      setState(() {
        _applications = apps;
      });
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error loading apps: ${e.toString()}', Colors.red);
      }
    }
  }

  Future<void> _loadCustomers() async {
    try {
      setState(() => _isLoading = true);

      final customers = await _customerService.getCustomers();

      setState(() {
        _customers = customers;                 // ✅ keep ALL
        _filteredCustomers = customers;         // ✅ show ALL initially
        _totalCustomers = customers.length;
        _totalCredit = 0.0;                    // will be computed in _applyFilters
        _isLoading = false;
      });

      // optionally compute credit totals
      await _applyFilters();
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error: ${e.toString()}', Colors.red);
      }
      setState(() => _isLoading = false);
    }
  }


  void _onSearchChanged() {
    _searchQuery = _searchController.text.toLowerCase();
    _applyFilters();
  }

  Future<void> _applyFilters() async {
    if (_customers.isEmpty) {
      setState(() {
        _filteredCustomers = [];
        _totalCredit = 0.0;
        _totalCustomers = 0;
      });
      return;
    }

    // If filtering by specific app
    if (_filterType != 'All' && _selectedAppFilter != null) {
      List<CustomerModel> filtered = [];
      double tempCredit = 0.0;

      for (var customer in _customers) {
        // Check search query first
        bool matchesSearch = _searchQuery.isEmpty ||
            customer.customerName.toLowerCase().contains(_searchQuery) ||
            customer.customerContact.contains(_searchQuery);

        if (!matchesSearch) continue;

        try {
          // Get this customer's apps
          final apps = await _customerService
              .getCustomerApplications(customer.id);

          // Check if customer has the selected app
          bool hasSelectedApp = apps.any((app) =>
          app['application_id'] == _selectedAppFilter);

          if (hasSelectedApp) {
            filtered.add(customer);
            // Sum credit only for this specific app
            for (var app in apps) {
              if (app['application_id'] == _selectedAppFilter) {
                tempCredit += (app['total_credit'] as num).toDouble();
              }
            }
          }
        } catch (e) {
          print('Error checking apps for customer: $e');
        }
      }

      setState(() {
        _filteredCustomers = filtered;
        _totalCustomers = filtered.length;
        _totalCredit = tempCredit;
      });
    } else {
      // Show all customers with search filter
      _filteredCustomers = _customers
          .where((customer) {
        bool matchesSearch = _searchQuery.isEmpty ||
            customer.customerName.toLowerCase().contains(_searchQuery) ||
            customer.customerContact.contains(_searchQuery);
        return matchesSearch;
      })
          .toList();

      // Calculate total credit for ALL apps
      double tempCredit = 0.0;
      for (var customer in _filteredCustomers) {
        try {
          final apps = await _customerService
              .getCustomerApplications(customer.id);
          for (var app in apps) {
            tempCredit += (app['total_credit'] as num).toDouble();
          }
        } catch (e) {
          print('Error loading apps: $e');
        }
      }

      setState(() {
        _totalCustomers = _filteredCustomers.length;
        _totalCredit = tempCredit;
      });
    }
  }

  Future<void> _addCustomer() async {
    if (_customerNameController.text.isEmpty ||
        _customerContactController.text.isEmpty) {
      _showSnackBar('Please fill all fields', Colors.red);
      return;
    }

    try {
      setState(() => _isAdding = true);

      await _customerService.addCustomer(
        customerName: _customerNameController.text.trim(),
        customerContact: _customerContactController.text.trim(),
      );

      _customerNameController.clear();
      _customerContactController.clear();

      await _loadCustomers();

      if (mounted) {
        _showSnackBar('Customer added successfully!', Colors.green);
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', Colors.red);
    } finally {
      setState(() => _isAdding = false);
    }
  }

  Future<void> _updateCustomer(
      int id,
      String customerName,
      String customerContact,
      ) async {
    try {
      await _customerService.updateCustomer(
        id: id,
        customerName: customerName,
        customerContact: customerContact,
      );

      await _loadCustomers();

      if (mounted) {
        _showSnackBar('Customer updated successfully!', Colors.green);
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', Colors.red);
    }
  }

  Future<void> _deleteCustomer(int id) async {
    try {
      await _customerService.deleteCustomer(id);
      await _loadCustomers();

      if (mounted) {
        _showSnackBar('Customer deleted!', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', Colors.red);
    }
  }

  Future<void> _addApplicationToCustomer(
      int customerId,
      int applicationId,
      double totalCredit,
      ) async {
    try {
      await _customerService.addApplicationToCustomer(
        customerId: customerId,
        applicationId: applicationId,
        totalCredit: totalCredit,
      );

      await _loadCustomers();

      if (mounted) {
        _showSnackBar('Application added to customer!', Colors.green);
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', Colors.red);
    }
  }

  Future<void> _updateCustomerApplicationCredit(
      int customerAppId,
      double totalCredit,
      ) async {
    try {
      await _customerService.updateCustomerApplicationCredit(
        customerAppId: customerAppId,
        totalCredit: totalCredit,
      );

      await _loadCustomers();

      if (mounted) {
        _showSnackBar('Credit updated successfully!', Colors.green);
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', Colors.red);
    }
  }

  Future<void> _deleteCustomerApplication(int customerAppId) async {
    try {
      await _customerService.deleteCustomerApplication(customerAppId);
      await _loadCustomers();

      if (mounted) {
        _showSnackBar('Application removed!', Colors.red);
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
                      'Add New Customer',
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
                  controller: _customerNameController,
                  label: 'Customer Name',
                  icon: Icons.person,
                  color: Colors.blue,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _customerContactController,
                  label: 'Customer Contact',
                  icon: Icons.phone,
                  color: Colors.green,
                  isNumber: true,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isAdding ? null : _addCustomer,
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
                      'Add Customer',
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

  void _showEditDialog(CustomerModel customer) {
    final nameController = TextEditingController(text: customer.customerName);
    final contactController =
    TextEditingController(text: customer.customerContact);

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
                      'Edit Customer',
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
                  controller: nameController,
                  label: 'Customer Name',
                  icon: Icons.person,
                  color: Colors.blue,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: contactController,
                  label: 'Customer Contact',
                  icon: Icons.phone,
                  color: Colors.green,
                  isNumber: true,
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
                          _updateCustomer(
                            customer.id,
                            nameController.text,
                            contactController.text,
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

  void _showAddAppDialog(CustomerModel customer) {
    showDialog(
      context: context,
      builder: (context) => _AddAppDialogWithNotifier(
        customer: customer,
        applications: _applications,
        onAddApp: (appId, credit) {
          _addApplicationToCustomer(customer.id, appId, credit);
        },
      ),
    );
  }

  void _navigateToCustomerProfile(CustomerModel customer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerProfilePage(customer: customer),
      ),
    );
  }

  void _showEditCreditDialog(
      Map<String, dynamic> customerApp,
      int customerAppId,
      ) {
    final creditController =
    TextEditingController(text: customerApp['total_credit'].toString());

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Edit Credit',
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
              TextField(
                controller: creditController,
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Total Credit',
                  labelStyle: const TextStyle(color: Colors.green),
                  prefixIcon: const Icon(Icons.payments, color: Colors.green),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.green),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.green, width: 2),
                  ),
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
                        _updateCustomerApplicationCredit(
                          customerAppId,
                          double.parse(creditController.text),
                        );
                        Navigator.pop(context);
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
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
                    'Customer Management',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Customers',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                          Text(
                            _totalCustomers.toString(),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Total Credit',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                          Text(
                            _totalCredit.toStringAsFixed(2),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      if (_customers.isEmpty) _loadCustomers();
                      setState(() {
                        _filterType = 'All';
                        _selectedAppFilter = null;
                      });
                      _applyFilters();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _filterType == 'All'
                          ? Colors.green
                          : Colors.grey[300],
                      foregroundColor: _filterType == 'All'
                          ? Colors.white
                          : Colors.black,
                    ),
                    child: const Text('All'),
                  ),
                  const SizedBox(width: 8),
                  ..._applications.map((app) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ElevatedButton(
                        onPressed: () {
                          if (_customers.isEmpty) _loadCustomers();
                          setState(() {
                            _filterType = app.applicationName;
                            _selectedAppFilter = app.id;
                          });
                          _applyFilters();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _filterType == app.applicationName
                              ? Colors.blue
                              : Colors.grey[300],
                          foregroundColor: _filterType == app.applicationName
                              ? Colors.white
                              : Colors.black,
                        ),
                        child: Text(app.applicationName),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search customers...',
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
            child: _customers.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text(
                    'Select a filter to load customers',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
                : _isLoading
                ? const Center(
              child: CircularProgressIndicator(
                valueColor:
                AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            )
                : _filteredCustomers.isEmpty
                ? Center(
              child: Text(
                'No customers found',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              itemCount: _filteredCustomers.length,
              itemBuilder: (context, index) {
                final customer = _filteredCustomers[index];

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
                      child: ExpansionTile(
                        title: Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    customer.customerName,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.phone,
                                        size: 14,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        customer.customerContact,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton(
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  child: const Row(
                                    children: [
                                      Icon(Icons.person,
                                          color: Colors.teal),
                                      SizedBox(width: 8),
                                      Text('Profile'),
                                    ],
                                  ),
                                  onTap: () {
                                    Future.delayed(
                                      const Duration(
                                          milliseconds: 200),
                                          () =>
                                          _navigateToCustomerProfile(
                                              customer),
                                    );
                                  },
                                ),
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
                                          _showEditDialog(customer),
                                    );
                                  },
                                ),
                                PopupMenuItem(
                                  child: const Row(
                                    children: [
                                      Icon(Icons.app_registration,
                                          color: Colors.purple),
                                      SizedBox(width: 8),
                                      Text('Add App'),
                                    ],
                                  ),
                                  onTap: () {
                                    Future.delayed(
                                      const Duration(
                                          milliseconds: 200),
                                          () =>
                                          _showAddAppDialog(
                                              customer),
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
                                                'Delete Customer'),
                                            content: const Text(
                                                'Are you sure?'),
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
                                                  _deleteCustomer(
                                                      customer.id);
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
                        children: [
                          FutureBuilder<
                              List<Map<String, dynamic>>>(
                            future: _customerService
                                .getCustomerApplications(
                                customer.id),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Padding(
                                  padding: EdgeInsets.all(16),
                                  child:
                                  CircularProgressIndicator(),
                                );
                              }

                              if (!snapshot.hasData ||
                                  snapshot.data!.isEmpty) {
                                return Padding(
                                  padding:
                                  const EdgeInsets.all(16),
                                  child: Text(
                                    'No apps linked',
                                    style: TextStyle(
                                        color: Colors.grey[600]),
                                  ),
                                );
                              }

                              final apps = snapshot.data!;
                              double customerTotal = 0;
                              for (var app in apps) {
                                customerTotal +=
                                    (app['total_credit'] as num)
                                        .toDouble();
                              }

                              return Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding:
                                      const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.green[50],
                                        borderRadius:
                                        BorderRadius.circular(
                                            12),
                                        border: Border.all(
                                          color:
                                          Colors.green[200]!,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                        MainAxisAlignment
                                            .spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment:
                                            CrossAxisAlignment
                                                .start,
                                            children: [
                                              Text(
                                                customer
                                                    .customerName,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight:
                                                  FontWeight
                                                      .bold,
                                                ),
                                              ),
                                              const SizedBox(
                                                  height: 4),
                                              Text(
                                                'Contact: ${customer.customerContact}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors
                                                      .grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                          Column(
                                            crossAxisAlignment:
                                            CrossAxisAlignment
                                                .end,
                                            children: [
                                              const Text(
                                                'Total Credit',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors
                                                      .grey,
                                                ),
                                              ),
                                              Text(
                                                customerTotal
                                                    .toStringAsFixed(
                                                    2),
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight:
                                                  FontWeight
                                                      .bold,
                                                  color: Colors
                                                      .green[700],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.blue[50],
                                        borderRadius:
                                        BorderRadius.circular(
                                            12),
                                        border: Border.all(
                                          color:
                                          Colors.blue[200]!,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Container(
                                            padding:
                                            const EdgeInsets
                                                .all(12),
                                            decoration:
                                            BoxDecoration(
                                              color:
                                              Colors.grey[200],
                                              borderRadius:
                                              BorderRadius
                                                  .circular(8),
                                            ),
                                            child: Row(
                                              children: [
                                                const Expanded(
                                                  flex: 2,
                                                  child: Text(
                                                    'Application',
                                                    style:
                                                    TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                      FontWeight
                                                          .bold,
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Text(
                                                    'Credit',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                      FontWeight
                                                          .bold,
                                                    ),
                                                    textAlign:
                                                    TextAlign
                                                        .center,
                                                  ),
                                                ),
                                                const Expanded(
                                                  child: Text(
                                                    'Actions',
                                                    style:
                                                    TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                      FontWeight
                                                          .bold,
                                                    ),
                                                    textAlign:
                                                    TextAlign
                                                        .center,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          ...apps
                                              .asMap()
                                              .entries
                                              .map((entry) {
                                            int idx = entry.key;
                                            var app = entry.value;
                                            final appName = app[
                                            'applications']
                                            ['application_name'];
                                            final appCredit = app[
                                            'total_credit'];

                                            return Container(
                                              decoration:
                                              BoxDecoration(
                                                border: Border(
                                                  bottom: idx <
                                                      apps.length -
                                                          1
                                                      ? BorderSide(
                                                    color: Colors
                                                        .grey[300]!,
                                                  )
                                                      : BorderSide
                                                      .none,
                                                ),
                                              ),
                                              padding:
                                              const EdgeInsets
                                                  .all(10),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      appName,
                                                      style: const TextStyle(
                                                        fontSize:
                                                        12,
                                                        fontWeight:
                                                        FontWeight
                                                            .w600,
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Text(
                                                      appCredit
                                                          .toStringAsFixed(
                                                          2),
                                                      style: TextStyle(
                                                        fontSize:
                                                        12,
                                                        fontWeight:
                                                        FontWeight
                                                            .w600,
                                                        color: Colors
                                                            .green[700],
                                                      ),
                                                      textAlign:
                                                      TextAlign
                                                          .center,
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Row(
                                                      mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .center,
                                                      children: [
                                                        SizedBox(
                                                          width: 32,
                                                          height:
                                                          32,
                                                          child:
                                                          IconButton(
                                                            icon: const Icon(
                                                              Icons
                                                                  .edit,
                                                              color:
                                                              Colors
                                                                  .blue,
                                                              size:
                                                              16,
                                                            ),
                                                            padding:
                                                            EdgeInsets
                                                                .zero,
                                                            onPressed:
                                                                () {
                                                              _showEditCreditDialog(
                                                                app,
                                                                app[
                                                                'id'],
                                                              );
                                                            },
                                                          ),
                                                        ),
                                                        SizedBox(
                                                          width: 32,
                                                          height:
                                                          32,
                                                          child:
                                                          IconButton(
                                                            icon: const Icon(
                                                              Icons
                                                                  .delete,
                                                              color:
                                                              Colors
                                                                  .red,
                                                              size:
                                                              16,
                                                            ),
                                                            padding:
                                                            EdgeInsets
                                                                .zero,
                                                            onPressed:
                                                                () {
                                                              _deleteCustomerApplication(
                                                                app[
                                                                'id'],
                                                              );
                                                            },
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    )
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color color,
    bool isNumber = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.phone : TextInputType.text,
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
}

// ============================================
// ADD APP DIALOG
// ============================================
class _AddAppDialogWithNotifier extends StatefulWidget {
  final CustomerModel customer;
  final List<ApplicationModel> applications;
  final Function(int, double) onAddApp;

  const _AddAppDialogWithNotifier({
    required this.customer,
    required this.applications,
    required this.onAddApp,
  });

  @override
  State<_AddAppDialogWithNotifier> createState() =>
      _AddAppDialogWithNotifierState();
}

class _AddAppDialogWithNotifierState extends State<_AddAppDialogWithNotifier> {
  late ValueNotifier<int?> appIdNotifier;
  late TextEditingController creditController;

  @override
  void initState() {
    super.initState();
    appIdNotifier = ValueNotifier<int?>(null);
    creditController = TextEditingController();
  }

  @override
  void dispose() {
    appIdNotifier.dispose();
    creditController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
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
                  Text(
                    'Add App to ${widget.customer.customerName}',
                    style: const TextStyle(
                      fontSize: 18,
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
              ValueListenableBuilder<int?>(
                valueListenable: appIdNotifier,
                builder: (context, selectedAppId, _) {
                  return DropdownButtonFormField<int>(
                    decoration: InputDecoration(
                      labelText: 'Select Application',
                      labelStyle: const TextStyle(color: Colors.blue),
                      prefixIcon: const Icon(Icons.app_registration,
                          color: Colors.blue),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.blue),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                        const BorderSide(color: Colors.blue, width: 2),
                      ),
                    ),
                    value: selectedAppId,
                    onChanged: (value) {
                      appIdNotifier.value = value;
                    },
                    items: widget.applications
                        .map((app) => DropdownMenuItem<int>(
                      value: app.id,
                      child: Text(app.applicationName),
                    ))
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: creditController,
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) {
                  setState(() {});
                },
                decoration: InputDecoration(
                  labelText: 'Opening Credit',
                  labelStyle: const TextStyle(color: Colors.green),
                  prefixIcon: const Icon(Icons.payments, color: Colors.green),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.green),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.green, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ValueListenableBuilder<int?>(
                valueListenable: appIdNotifier,
                builder: (context, selectedAppId, _) {
                  return SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: (selectedAppId != null &&
                          creditController.text.isNotEmpty)
                          ? () {
                        widget.onAddApp(
                          selectedAppId,
                          double.parse(creditController.text),
                        );
                        Navigator.pop(context);
                      }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        disabledBackgroundColor: Colors.grey,
                      ),
                      child: const Text(
                        'Add Application',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================
// CUSTOMER PROFILE PAGE
// ============================================
