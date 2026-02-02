import 'package:flutter/material.dart';

import '../Accounts/accountservice.dart';
import '../Accounts/accountsmodel.dart';
import '../Employes/Customerservice.dart';
import '../Employes/Customersmodel.dart';
import '../Inventoy/Inventorymodel.dart';
import '../Inventoy/Inventoryservice.dart';
import '../Workers/EmployeeAppAssignment.dart';
import '../Workers/Employeeservice.dart';
import '../Workers/employemodel.dart';


class EmployeeQuickSalesPage extends StatefulWidget {
  final Employee employee;
  const EmployeeQuickSalesPage({super.key, required this.employee});

  @override
  State<EmployeeQuickSalesPage> createState() => _EmployeeQuickSalesPageState();
}

class _EmployeeQuickSalesPageState extends State<EmployeeQuickSalesPage> {
  final _employeeService = EmployeeService();
  final _customerService = CustomerService();
  final _inventoryService = InventoryService();
  final _accountService = AccountService();
  List<EmployeeAppAssignment> assignedApps = [];
  Map<int, double> appBalances = {};
  Map<int, int> appCustomerCounts = {};
  Map<int, InventoryApp> appDetails = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAssignedApps();
  }

  Future<void> _loadAssignedApps() async {
    try {
      final apps = await _employeeService.getEmployeeAssignedApps(widget.employee.id);

      Map<int, double> balances = {};
      Map<int, int> customerCounts = {};
      Map<int, InventoryApp> details = {};

      for (var app in apps) {
        final response = await _customerService.getAllCustomersWithAppBalance(app.appId);

        double totalBalance = 0;
        for (var customer in response) {
          totalBalance += customer.overallBalance;
        }

        balances[app.appId] = totalBalance;
        customerCounts[app.appId] = response.length;

        final appDetail = await _inventoryService.getAppById(app.appId);
        if (appDetail != null) {
          details[app.appId] = appDetail;
        }
      }

      setState(() {
        assignedApps = apps;
        appBalances = balances;
        appCustomerCounts = customerCounts;
        appDetails = details;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading apps: $e')),
        );
      }
    }
  }

  void _showMakeSaleDialog(EmployeeAppAssignment app) {
    showDialog(
      context: context,
      builder: (_) => MakeSaleDialog(
        employee: widget.employee,
        app: app,
        appDetails: appDetails[app.appId],
        customerService: _customerService,
        accountService: _accountService,
        onSaleCreate: (sale) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Sale created: ${sale['coinsAmount']} coins')),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Quick Sales'),
        backgroundColor: Colors.blue[600],
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : assignedApps.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.apps_outage, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No Apps Assigned',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Contact admin to assign apps',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Assigned Apps',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: assignedApps.length,
              itemBuilder: (context, index) {
                final app = assignedApps[index];
                final totalBalance = appBalances[app.appId] ?? 0.0;
                final customerCount = appCustomerCounts[app.appId] ?? 0;

                return _buildAppCard(
                  app: app,
                  totalBalance: totalBalance,
                  customerCount: customerCount,
                  onMakeSale: () => _showMakeSaleDialog(app),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppCard({
    required EmployeeAppAssignment app,
    required double totalBalance,
    required int customerCount,
    required VoidCallback onMakeSale,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey[300]!,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    app.appName ?? 'App ${app.appId}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'ID: ${app.appId}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey[400],
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Balance',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${totalBalance.toStringAsFixed(2)} PKR',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.purple[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Customers',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.purple[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        customerCount.toString(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onMakeSale,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, size: 20),
                  SizedBox(width: 8),
                  Text('Make Sale'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// MAKE SALE DIALOG
class MakeSaleDialog extends StatefulWidget {
  final Employee employee;
  final EmployeeAppAssignment app;
  final InventoryApp? appDetails;
  final CustomerService customerService;
  final AccountService accountService;
  final Function(Map<String, dynamic>) onSaleCreate;

  const MakeSaleDialog({
    super.key,
    required this.employee,
    required this.app,
    this.appDetails,
    required this.customerService,
    required this.accountService,
    required this.onSaleCreate,
  });

  @override
  State<MakeSaleDialog> createState() => _MakeSaleDialogState();
}

class _MakeSaleDialogState extends State<MakeSaleDialog> {
  late TextEditingController coinsController;
  late TextEditingController pkrController;
  late TextEditingController customerNameController;
  late TextEditingController customerContactController;
  late TextEditingController searchController;

  Customer? selectedCustomer;
  BankAccount? selectedAccount;
  String selectedRateType = 'retail';
  String selectedPaymentType = 'cash';
  bool isLoadingCustomers = true;
  bool isLoadingAccounts = true;
  List<Customer> allCustomers = [];
  List<Customer> filteredCustomers = [];
  List<BankAccount> bankAccounts = [];
  bool showAddCustomer = false;
  final formKey = GlobalKey<FormState>();
  String? validationMessage;
  double? creditLimit;
  bool isValidatingCredit = false;

  @override
  void initState() {
    super.initState();
    coinsController = TextEditingController();
    pkrController = TextEditingController();
    customerNameController = TextEditingController();
    customerContactController = TextEditingController();
    searchController = TextEditingController();
    _loadData();
  }

  @override
  void dispose() {
    coinsController.dispose();
    pkrController.dispose();
    customerNameController.dispose();
    customerContactController.dispose();
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final customers = await widget.customerService.getAllCustomers();
      final accounts = await widget.accountService.getAllAccounts();

      setState(() {
        allCustomers = customers;
        filteredCustomers = customers;
        bankAccounts = accounts;
        isLoadingCustomers = false;
        isLoadingAccounts = false;
        if (accounts.isNotEmpty) {
          selectedAccount = accounts[0];
        }
      });
    } catch (e) {
      setState(() {
        isLoadingCustomers = false;
        isLoadingAccounts = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  void _searchCustomers(String query) {
    if (query.isEmpty) {
      setState(() => filteredCustomers = allCustomers);
    } else {
      setState(() {
        filteredCustomers = allCustomers
            .where((c) =>
        c.customerName.toLowerCase().contains(query.toLowerCase()) ||
            c.contact.contains(query))
            .toList();
      });
    }
  }

  void _createWalkInCustomer() {
    // Create anonymous walk-in customer (not registered)
    final walkInCustomer = Customer(
      id: -1, // Temporary ID for walk-in
      customerName: 'Walk-In Customer',
      contact: 'WALK-IN-${DateTime.now().millisecondsSinceEpoch}',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    setState(() {
      selectedCustomer = walkInCustomer;
      searchController.text = 'Walk-In Customer';
      validationMessage = null;
      creditLimit = null;
      selectedPaymentType = 'cash'; // Force cash for walk-in
    });
  }

  void _calculateCoins(String pkrAmount) {
    if (pkrAmount.isEmpty || widget.appDetails == null) return;

    try {
      final price = selectedRateType == 'retail'
          ? widget.appDetails!.coinSellingPrice
          : widget.appDetails!.wholesalePrice;

      if (price > 0) {
        final coins = double.parse(pkrAmount) / price;
        coinsController.text = coins.toStringAsFixed(2);
      }
    } catch (e) {
      // Invalid input
    }
  }

  void _calculatePKR(String coinsAmount) {
    if (coinsAmount.isEmpty || widget.appDetails == null) return;

    try {
      final price = selectedRateType == 'retail'
          ? widget.appDetails!.coinSellingPrice
          : widget.appDetails!.wholesalePrice;

      final pkr = double.parse(coinsAmount) * price;
      pkrController.text = pkr.toStringAsFixed(2);
    } catch (e) {
      // Invalid input
    }
  }

  Future<void> _addNewCustomer() async {
    if (formKey.currentState!.validate()) {
      try {
        final exists = await widget.customerService
            .contactExists(customerContactController.text);

        if (exists) {
          setState(() => validationMessage = 'Contact already registered');
          return;
        }

        final newCustomer = await widget.customerService.createCustomer(
          customerName: customerNameController.text,
          contact: customerContactController.text,
        );

        setState(() {
          selectedCustomer = newCustomer;
          allCustomers.add(newCustomer);
          filteredCustomers.add(newCustomer);
          showAddCustomer = false;
          customerNameController.clear();
          customerContactController.clear();
          validationMessage = null;
          searchController.text = newCustomer.customerName;
          creditLimit = null;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Customer added successfully')),
          );
        }
      } catch (e) {
        setState(() => validationMessage = 'Error: $e');
      }
    }
  }

  Future<bool> _validateCreditSale() async {
    if (selectedPaymentType == 'credit' && selectedCustomer != null && selectedCustomer!.id > 0) {
      try {
        setState(() => isValidatingCredit = true);

        // TODO: Get previous cash sales for this customer from QuickSaleService
        // For now: Reject credit
        // When implemented:
        // double totalCashSales = await quickSaleService.getCashSalesTotal(selectedCustomer!.id);
        // double creditLimit = totalCashSales * 0.02; // 2% of cash sales

        setState(() {
          isValidatingCredit = false;
          validationMessage = 'Credit sales not yet available. Use Cash payment.';
        });
        return false;

      } catch (e) {
        setState(() {
          isValidatingCredit = false;
          validationMessage = 'Error validating credit: $e';
        });
        return false;
      }
    }
    return true;
  }

  Future<void> _submitSale() async {
    setState(() => validationMessage = null);

    if (selectedCustomer == null) {
      setState(() => validationMessage = 'Please select a customer or use Walk-In');
      return;
    }

    if (coinsController.text.isEmpty || pkrController.text.isEmpty) {
      setState(() => validationMessage = 'Please enter coins or PKR amount');
      return;
    }

    // Walk-in customers can only use cash
    if (selectedCustomer!.id == -1 && selectedPaymentType == 'credit') {
      setState(() => validationMessage = 'Walk-In customers must use Cash payment');
      return;
    }

    if (selectedPaymentType == 'cash' && selectedAccount == null) {
      setState(() => validationMessage = 'Please select a bank account');
      return;
    }

    // Validate credit limit
    if (!await _validateCreditSale()) {
      return;
    }

    widget.onSaleCreate({
      'customerId': selectedCustomer!.id,
      'customerName': selectedCustomer!.customerName,
      'coinsAmount': double.parse(coinsController.text),
      'pkrAmount': double.parse(pkrController.text),
      'rateType': selectedRateType,
      'paymentType': selectedPaymentType,
      'accountId': selectedPaymentType == 'cash' ? selectedAccount?.id : null,
      'status': 'pending',
      'saleDate': DateTime.now(),
      'saleBy': widget.employee.email,
      'approvedBy': null,
    });

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Make Sale - ${widget.app.appName}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ERROR MESSAGE
              if (validationMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    border: Border.all(color: Colors.red[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red[600]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          validationMessage!,
                          style: TextStyle(color: Colors.red[700], fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              if (validationMessage != null) const SizedBox(height: 16),

              // CUSTOMER SECTION
              const Text('Select Customer',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              // Search Field
              TextField(
                controller: searchController,
                decoration: InputDecoration(
                  labelText: 'Search customer...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onChanged: _searchCustomers,
              ),
              const SizedBox(height: 12),

              // Customers List
              if (isLoadingCustomers)
                const Center(child: CircularProgressIndicator())
              else if (filteredCustomers.isEmpty)
                Center(
                  child: Text(
                    'No customers found',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                )
              else
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    itemCount: filteredCustomers.length,
                    itemBuilder: (context, index) {
                      final customer = filteredCustomers[index];
                      final isSelected = selectedCustomer?.id == customer.id;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.blue[50] : Colors.white,
                          border: Border.all(
                            color: isSelected ? Colors.blue[400]! : Colors.grey[300]!,
                            width: isSelected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          title: Text(customer.customerName),
                          subtitle: Text(customer.contact),
                          onTap: () {
                            setState(() {
                              selectedCustomer = customer;
                              searchController.text = customer.customerName;
                              validationMessage = null;
                              creditLimit = null;
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),

              // WALK-IN CUSTOMER Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _createWalkInCustomer,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Walk-In Customer (Cash Only)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[600],
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ADD CUSTOMER Button
              if (!showAddCustomer)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => setState(() => showAddCustomer = true),
                    icon: const Icon(Icons.person_add),
                    label: const Text('Add New Customer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                    ),
                  ),
                )
              else
                Form(
                  key: formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: customerNameController,
                        decoration: InputDecoration(
                          labelText: 'Customer Name',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: customerContactController,
                        decoration: InputDecoration(
                          labelText: 'Contact Number',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => setState(() => showAddCustomer = false),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[400]),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _addNewCustomer,
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green[600]),
                              child: const Text('Add'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),

              // AMOUNT SECTION
              const Text('Sale Amount',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: coinsController,
                      decoration: InputDecoration(
                        labelText: 'Coins',
                        prefixIcon: const Icon(Icons.monetization_on),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: _calculatePKR,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: pkrController,
                      decoration: InputDecoration(
                        labelText: 'PKR',
                        prefixIcon: const Icon(Icons.currency_exchange),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: _calculateCoins,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // RATE TYPE
              const Text('Rate Type',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Retail', style: TextStyle(fontSize: 12)),
                      subtitle: Text(
                        '${widget.appDetails?.coinSellingPrice.toStringAsFixed(2) ?? 'N/A'} PKR/coin',
                        style: const TextStyle(fontSize: 10),
                      ),
                      value: 'retail',
                      groupValue: selectedRateType,
                      onChanged: (value) {
                        setState(() {
                          selectedRateType = value!;
                          coinsController.clear();
                          pkrController.clear();
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Wholesale', style: TextStyle(fontSize: 12)),
                      subtitle: Text(
                        '${widget.appDetails?.wholesalePrice.toStringAsFixed(2) ?? 'N/A'} PKR/coin',
                        style: const TextStyle(fontSize: 10),
                      ),
                      value: 'wholesale',
                      groupValue: selectedRateType,
                      onChanged: (value) {
                        setState(() {
                          selectedRateType = value!;
                          coinsController.clear();
                          pkrController.clear();
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // PAYMENT TYPE
              const Text('Payment Type',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Cash', style: TextStyle(fontSize: 12)),
                      value: 'cash',
                      groupValue: selectedPaymentType,
                      onChanged: (value) => setState(() => selectedPaymentType = value!),
                    ),
                  ),
                  Expanded(
                    child: Opacity(
                      opacity: selectedCustomer?.id == -1 ? 0.5 : 1.0,
                      child: IgnorePointer(
                        ignoring: selectedCustomer?.id == -1,
                        child: RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Credit', style: TextStyle(fontSize: 12)),
                          value: 'credit',
                          groupValue: selectedPaymentType,
                          onChanged: (value) => setState(() => selectedPaymentType = value!),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // BANK ACCOUNT (only for cash)
              if (selectedPaymentType == 'cash')
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select Bank Account',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (isLoadingAccounts)
                      const Center(child: CircularProgressIndicator())
                    else if (bankAccounts.isEmpty)
                      Center(child: Text('No accounts', style: TextStyle(color: Colors.grey[600])))
                    else
                      SizedBox(
                        height: 120,
                        child: ListView.builder(
                          itemCount: bankAccounts.length,
                          itemBuilder: (context, index) {
                            final account = bankAccounts[index];
                            final isSelected = selectedAccount?.id == account.id;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.green[50] : Colors.white,
                                border: Border.all(
                                  color: isSelected ? Colors.green[400]! : Colors.grey[300]!,
                                  width: isSelected ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                title: Text(
                                  account.bankName,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Holder: ${account.holderName}',
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                    Text(
                                      'Acc: ${account.accountNumber}',
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  ],
                                ),
                                trailing: Text(
                                  '${account.totalBalance.toStringAsFixed(0)} PKR',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[600],
                                  ),
                                ),
                                onTap: () {
                                  setState(() => selectedAccount = account);
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 12),
                  ],
                ),

              // CREDIT LIMIT INFO
              if (selectedPaymentType == 'credit' && selectedCustomer != null && selectedCustomer!.id > 0)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.yellow[50],
                    border: Border.all(color: Colors.yellow[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Credit Limit Info',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Credit is limited to 2% of customer\'s previous cash sales',
                        style: TextStyle(fontSize: 11, color: Colors.yellow[800]),
                      ),
                      if (creditLimit != null)
                        Text(
                          'Available Credit: ${creditLimit!.toStringAsFixed(2)} PKR',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.yellow[800],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),

              // WALK-IN INFO
              if (selectedCustomer?.id == -1)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    border: Border.all(color: Colors.orange[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange[600], size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Walk-In: Anonymous customer (Cash only)',
                          style: TextStyle(fontSize: 11, color: Colors.orange[800]),
                        ),
                      ),
                    ],
                  ),
                ),

              if (selectedPaymentType == 'credit' || selectedCustomer?.id == -1)
                const SizedBox(height: 12),

              // STATUS INFO
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status: PENDING',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Approved By: null',
                      style: TextStyle(fontSize: 11, color: Colors.blue[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sale By: ${widget.employee.email}',
                      style: TextStyle(fontSize: 11, color: Colors.blue[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Time: ${DateTime.now().toString().split('.')[0]}',
                      style: TextStyle(fontSize: 11, color: Colors.blue[600]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // BUTTONS
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[400],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isValidatingCredit ? null : _submitSale,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: isValidatingCredit
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Text('Create Sale'),
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
}