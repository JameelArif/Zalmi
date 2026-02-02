import 'package:flutter/material.dart';
import '../Login/authservice.dart';
import 'Customerservice.dart';
import 'Customersmodel.dart';


class CustomerManagement extends StatefulWidget {
  const CustomerManagement({super.key});

  @override
  State<CustomerManagement> createState() => _CustomerManagementState();
}

class _CustomerManagementState extends State<CustomerManagement> {
  final customerService = CustomerService();
  final authService = AuthService();
  List<Customer> customers = [];
  Map<int, List<CustomerAppBalance>> customerBalances = {};
  bool isLoading = true;
  double totalCredit = 0;
  double totalBalance = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final customersList = await customerService.getAllCustomers();
      final totals = await customerService.getTotals();

      Map<int, List<CustomerAppBalance>> balances = {};
      for (var customer in customersList) {
        balances[customer.id] = await customerService.getCustomerAppBalances(customer.id);
      }

      setState(() {
        customers = customersList;
        customerBalances = balances;
        totalCredit = totals['total_credit'] ?? 0;
        totalBalance = totals['total_balance'] ?? 0;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showAddDialog() {
    showDialog(context: context, builder: (_) => AddCustomerDialog(onAdd: (customer) async {
      try {
        await customerService.createCustomer(customerName: customer['customerName'], contact: customer['contact']);
        _loadData();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Customer added successfully')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }));
  }

  void _showAddAppBalanceDialog(Customer customer) {
    showDialog(context: context, builder: (_) => AddAppBalanceDialog(customer: customer, customerService: customerService, onAdd: (balance) async {
      try {
        await customerService.addAppBalance(customerId: customer.id, appId: balance['appId'], openingCredit: balance['openingCredit']);
        _loadData();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('App balance added successfully')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }));
  }

  void _showRecoveryDialog(CustomerAppBalance balance) {
    showDialog(context: context, builder: (_) => AddRecoveryDialog(balance: balance, onAdd: (recovery) async {
      try {
        final user = authService.getCurrentUser();
        await customerService.addRecovery(customerAppBalanceId: balance.id, recoveryAmount: recovery['amount'], recoveryDate: recovery['date'], notes: recovery['notes'], recordedBy: user?.email ?? 'Unknown');
        _loadData();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recovery added successfully')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }));
  }

  void _showEditCustomerDialog(Customer customer) {
    showDialog(context: context, builder: (_) => EditCustomerDialog(customer: customer, onUpdate: (updated) async {
      try {
        await customerService.updateCustomer(id: customer.id, customerName: updated['customerName'], contact: updated['contact']);
        _loadData();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Customer updated successfully')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }));
  }

  void _showEditBalanceDialog(CustomerAppBalance balance) {
    showDialog(context: context, builder: (_) => EditBalanceDialog(balance: balance, onUpdate: (updated) async {
      try {
        await customerService.updateAppBalance(balanceId: balance.id, openingCredit: updated['openingCredit'], overallBalance: updated['overallBalance']);
        _loadData();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Balance updated successfully')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Customers', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  ElevatedButton.icon(onPressed: _showAddDialog, icon: const Icon(Icons.add, size: 18), label: const Text('Add Customer'), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[600], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8))),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Row(children: [Expanded(child: _buildSummaryCard(title: 'Overall Credit', value: '${totalCredit.toStringAsFixed(2)} PKR', icon: Icons.account_balance_wallet, color: Colors.blue)), const SizedBox(width: 12), Expanded(child: _buildSummaryCard(title: 'Overall Balance', value: '${totalBalance.toStringAsFixed(2)} PKR', icon: Icons.balance, color: Colors.green))]),
                  const SizedBox(height: 12),
                  _buildSummaryCard(title: 'Total Customers', value: customers.length.toString(), icon: Icons.people, color: Colors.cyan, fullWidth: true),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Customers Table', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  customers.isEmpty
                      ? Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 40), child: Text('No customers added yet', style: TextStyle(fontSize: 16, color: Colors.grey[600]))))
                      : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                        boxShadow: [BoxShadow(color: Colors.grey[200]!, blurRadius: 4, offset: const Offset(0, 2))],
                      ),
                      child: DataTable(
                        headingRowColor: MaterialStateColor.resolveWith((_) => Colors.blue[100]!),
                        dataRowHeight: 80,
                        columns: const [
                          DataColumn(label: SizedBox(width: 150, child: Text('Customer Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
                          DataColumn(label: SizedBox(width: 120, child: Text('Contact', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
                          DataColumn(label: SizedBox(width: 140, child: Text('Total Credit\n(PKR)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center))),
                          DataColumn(label: SizedBox(width: 140, child: Text('Total Balance\n(PKR)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center))),
                          DataColumn(label: SizedBox(width: 120, child: Text('Apps Count', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center))),
                          DataColumn(label: SizedBox(width: 150, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center))),
                        ],
                        rows: customers.map((customer) {
                          final balances = customerBalances[customer.id] ?? [];
                          final totalCredit = balances.fold(0.0, (sum, b) => sum + b.openingCredit);
                          final totalBalance = balances.fold(0.0, (sum, b) => sum + b.overallBalance);

                          return DataRow(cells: [
                            DataCell(SizedBox(width: 150, child: Text(customer.customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis))),
                            DataCell(SizedBox(width: 120, child: Text(customer.contact, style: TextStyle(fontSize: 11, color: Colors.grey[700])))),
                            DataCell(SizedBox(width: 140, child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(4)), child: Text(totalCredit.toStringAsFixed(2), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Colors.blue[700]), textAlign: TextAlign.center)))),
                            DataCell(SizedBox(width: 140, child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(4)), child: Text(totalBalance.toStringAsFixed(2), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Colors.green[700]), textAlign: TextAlign.center)))),
                            DataCell(SizedBox(width: 120, child: Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.purple[100], borderRadius: BorderRadius.circular(12)), child: Text(balances.length.toString(), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.purple[700])))))),
                            DataCell(SizedBox(width: 150, child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                              IconButton(icon: Icon(Icons.edit, color: Colors.orange[600], size: 18), onPressed: () => _showEditCustomerDialog(customer), tooltip: 'Edit'),
                              IconButton(icon: Icon(Icons.add_circle, color: Colors.green[600], size: 18), onPressed: () => _showAddAppBalanceDialog(customer), tooltip: 'Add App'),
                              PopupMenuButton(icon: Icon(Icons.more_vert, color: Colors.blue[600], size: 18), itemBuilder: (context) => [
                                PopupMenuItem(child: const Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))]), onTap: () async {
                                  if (await _confirmDelete()) {
                                    try {
                                      await customerService.deleteCustomer(customer.id);
                                      _loadData();
                                    } catch (e) {
                                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                                    }
                                  }
                                }),
                              ]),
                            ]))),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // App Wise Balances Table
            if (customers.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('App Wise Balances', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                          boxShadow: [BoxShadow(color: Colors.grey[200]!, blurRadius: 4, offset: const Offset(0, 2))],
                        ),
                        child: DataTable(
                          headingRowColor: MaterialStateColor.resolveWith((_) => Colors.green[100]!),
                          dataRowHeight: 70,
                          columns: const [
                            DataColumn(label: SizedBox(width: 140, child: Text('Customer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
                            DataColumn(label: SizedBox(width: 100, child: Text('App ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center))),
                            DataColumn(label: SizedBox(width: 130, child: Text('Opening\nCredit (PKR)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center))),
                            DataColumn(label: SizedBox(width: 130, child: Text('Overall\nBalance (PKR)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center))),
                            DataColumn(label: SizedBox(width: 120, child: Text('Recoveries', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center))),
                            DataColumn(label: SizedBox(width: 130, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center))),
                          ],
                          rows: _buildAppBalanceRows(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  List<DataRow> _buildAppBalanceRows() {
    List<DataRow> rows = [];
    for (var customer in customers) {
      final balances = customerBalances[customer.id] ?? [];
      for (var balance in balances) {
        rows.add(
          DataRow(cells: [
            DataCell(SizedBox(width: 140, child: Text(customer.customerName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11), overflow: TextOverflow.ellipsis))),
            DataCell(SizedBox(width: 100, child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(4)), child: Text(balance.appId.toString(), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Colors.blue[700]), textAlign: TextAlign.center)))),
            DataCell(SizedBox(width: 130, child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(4)), child: Text(balance.openingCredit.toStringAsFixed(2), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Colors.orange[700]), textAlign: TextAlign.center)))),
            DataCell(SizedBox(width: 130, child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(4)), child: Text(balance.overallBalance.toStringAsFixed(2), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Colors.green[700]), textAlign: TextAlign.center)))),
            DataCell(SizedBox(width: 120, child: FutureBuilder<List<CustomerRecovery>>(
              future: customerService.getAppBalanceRecoveries(balance.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2));
                final count = snapshot.data?.length ?? 0;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.purple[100], borderRadius: BorderRadius.circular(12)),
                  child: Text(count.toString(), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.purple[700])),
                );
              },
            ))),
            DataCell(SizedBox(width: 130, child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              IconButton(icon: Icon(Icons.edit, color: Colors.orange[600], size: 18), onPressed: () => _showEditBalanceDialog(balance), tooltip: 'Edit'),
              IconButton(icon: Icon(Icons.money, color: Colors.green[600], size: 18), onPressed: () => _showRecoveryDialog(balance), tooltip: 'Add Recovery'),
              PopupMenuButton(icon: Icon(Icons.more_vert, color: Colors.blue[600], size: 18), itemBuilder: (context) => [
                PopupMenuItem(child: const Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))]), onTap: () async {
                  if (await _confirmDelete()) {
                    try {
                      await customerService.deleteAppBalance(balance.id);
                      _loadData();
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  }
                }),
              ]),
            ]))),
          ]),
        );
      }
    }
    return rows;
  }

  Widget _buildSummaryCard({required String title, required String value, required IconData icon, required Color color, bool fullWidth = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.grey[300]!, blurRadius: 8, offset: const Offset(0, 2))], border: Border(left: BorderSide(color: color, width: 4))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, color: color, size: 24), const SizedBox(width: 8), Expanded(child: Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)))]),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Future<bool> _confirmDelete() async {
    final result = await showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Delete'), content: const Text('Are you sure?'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red)))]));
    return result ?? false;
  }
}

// ADD CUSTOMER DIALOG
class AddCustomerDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onAdd;
  const AddCustomerDialog({super.key, required this.onAdd});
  @override
  State<AddCustomerDialog> createState() => _AddCustomerDialogState();
}

class _AddCustomerDialogState extends State<AddCustomerDialog> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final contactController = TextEditingController();

  @override
  void dispose() {
    nameController.dispose();
    contactController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Customer'),
      content: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: nameController, decoration: InputDecoration(labelText: 'Customer Name', prefixIcon: const Icon(Icons.person, color: Colors.blue), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), validator: (v) => v?.isEmpty ?? true ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(controller: contactController, decoration: InputDecoration(labelText: 'Contact', prefixIcon: const Icon(Icons.phone, color: Colors.blue), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), keyboardType: TextInputType.phone, validator: (v) => v?.isEmpty ?? true ? 'Required' : null),
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), ElevatedButton(onPressed: () { if (formKey.currentState!.validate()) { widget.onAdd({'customerName': nameController.text, 'contact': contactController.text}); Navigator.pop(context); } }, style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[600]), child: const Text('Add', style: TextStyle(color: Colors.white)))],
    );
  }
}

// EDIT CUSTOMER DIALOG
class EditCustomerDialog extends StatefulWidget {
  final Customer customer;
  final Function(Map<String, dynamic>) onUpdate;
  const EditCustomerDialog({super.key, required this.customer, required this.onUpdate});
  @override
  State<EditCustomerDialog> createState() => _EditCustomerDialogState();
}

class _EditCustomerDialogState extends State<EditCustomerDialog> {
  final formKey = GlobalKey<FormState>();
  late TextEditingController nameController;
  late TextEditingController contactController;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.customer.customerName);
    contactController = TextEditingController(text: widget.customer.contact);
  }

  @override
  void dispose() {
    nameController.dispose();
    contactController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Customer'),
      content: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: nameController, decoration: InputDecoration(labelText: 'Customer Name', prefixIcon: const Icon(Icons.person, color: Colors.blue), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), validator: (v) => v?.isEmpty ?? true ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(controller: contactController, decoration: InputDecoration(labelText: 'Contact', prefixIcon: const Icon(Icons.phone, color: Colors.blue), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), keyboardType: TextInputType.phone, validator: (v) => v?.isEmpty ?? true ? 'Required' : null),
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), ElevatedButton(onPressed: () { if (formKey.currentState!.validate()) { widget.onUpdate({'customerName': nameController.text, 'contact': contactController.text}); Navigator.pop(context); } }, style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[600]), child: const Text('Update', style: TextStyle(color: Colors.white)))],
    );
  }
}

// ADD APP BALANCE DIALOG
class AddAppBalanceDialog extends StatefulWidget {
  final Customer customer;
  final CustomerService customerService;
  final Function(Map<String, dynamic>) onAdd;
  const AddAppBalanceDialog({super.key, required this.customer, required this.customerService, required this.onAdd});
  @override
  State<AddAppBalanceDialog> createState() => _AddAppBalanceDialogState();
}

class _AddAppBalanceDialogState extends State<AddAppBalanceDialog> {
  final formKey = GlobalKey<FormState>();
  int? selectedAppId;
  final creditController = TextEditingController();
  List<Map<String, dynamic>> apps = [];
  bool isLoadingApps = true;

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  Future<void> _loadApps() async {
    try {
      final appsList = await widget.customerService.getAllApps();
      setState(() {
        apps = appsList;
        isLoadingApps = false;
      });
    } catch (e) {
      setState(() => isLoadingApps = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  void dispose() {
    creditController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add App Balance'),
      content: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Customer: ${widget.customer.customerName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 16),
              isLoadingApps ? const CircularProgressIndicator() : DropdownButtonFormField<int>(value: selectedAppId, decoration: InputDecoration(labelText: 'Select App', prefixIcon: const Icon(Icons.apps, color: Colors.blue), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), items: apps.map((app) => DropdownMenuItem(value: app['id'] as int, child: Text(app['app_name'] as String))).toList(), onChanged: (value) => setState(() => selectedAppId = value), validator: (v) => v == null ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(controller: creditController, decoration: InputDecoration(labelText: 'Opening Credit (PKR)', prefixIcon: const Icon(Icons.account_balance_wallet, color: Colors.blue), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), keyboardType: TextInputType.number, validator: (v) => v?.isEmpty ?? true ? 'Required' : null),
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), ElevatedButton(onPressed: () { if (formKey.currentState!.validate() && selectedAppId != null) { widget.onAdd({'appId': selectedAppId, 'openingCredit': double.parse(creditController.text)}); Navigator.pop(context); } }, style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[600]), child: const Text('Add', style: TextStyle(color: Colors.white)))],
    );
  }
}

// EDIT BALANCE DIALOG
class EditBalanceDialog extends StatefulWidget {
  final CustomerAppBalance balance;
  final Function(Map<String, dynamic>) onUpdate;
  const EditBalanceDialog({super.key, required this.balance, required this.onUpdate});
  @override
  State<EditBalanceDialog> createState() => _EditBalanceDialogState();
}

class _EditBalanceDialogState extends State<EditBalanceDialog> {
  final formKey = GlobalKey<FormState>();
  late TextEditingController openingCreditController;
  late TextEditingController overallBalanceController;

  @override
  void initState() {
    super.initState();
    openingCreditController = TextEditingController(text: widget.balance.openingCredit.toStringAsFixed(2));
    overallBalanceController = TextEditingController(text: widget.balance.overallBalance.toStringAsFixed(2));
  }

  @override
  void dispose() {
    openingCreditController.dispose();
    overallBalanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit App Balance'),
      content: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('App ID: ${widget.balance.appId}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 16),
              TextFormField(controller: openingCreditController, decoration: InputDecoration(labelText: 'Opening Credit (PKR)', prefixIcon: const Icon(Icons.money, color: Colors.blue), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), keyboardType: TextInputType.number, validator: (v) => v?.isEmpty ?? true ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(controller: overallBalanceController, decoration: InputDecoration(labelText: 'Overall Balance (PKR)', prefixIcon: const Icon(Icons.account_balance, color: Colors.green), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), keyboardType: TextInputType.number, validator: (v) => v?.isEmpty ?? true ? 'Required' : null),
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), ElevatedButton(onPressed: () { if (formKey.currentState!.validate()) { widget.onUpdate({'openingCredit': double.parse(openingCreditController.text), 'overallBalance': double.parse(overallBalanceController.text)}); Navigator.pop(context); } }, style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[600]), child: const Text('Update', style: TextStyle(color: Colors.white)))],
    );
  }
}

// ADD RECOVERY DIALOG
class AddRecoveryDialog extends StatefulWidget {
  final CustomerAppBalance balance;
  final Function(Map<String, dynamic>) onAdd;
  const AddRecoveryDialog({super.key, required this.balance, required this.onAdd});
  @override
  State<AddRecoveryDialog> createState() => _AddRecoveryDialogState();
}

class _AddRecoveryDialogState extends State<AddRecoveryDialog> {
  final formKey = GlobalKey<FormState>();
  final amountController = TextEditingController();
  final notesController = TextEditingController();
  late DateTime selectedDate;

  @override
  void initState() {
    super.initState();
    selectedDate = DateTime.now();
  }

  @override
  void dispose() {
    amountController.dispose();
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Recovery'),
      content: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('App: ${widget.balance.appId}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 12),
              TextFormField(controller: amountController, decoration: InputDecoration(labelText: 'Recovery Amount (PKR)', prefixIcon: const Icon(Icons.money, color: Colors.green), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), keyboardType: TextInputType.number, validator: (v) => v?.isEmpty ?? true ? 'Required' : null),
              const SizedBox(height: 12),
              ListTile(title: const Text('Date'), subtitle: Text(selectedDate.toString().split(' ')[0]), trailing: const Icon(Icons.calendar_today, color: Colors.blue), onTap: () async { final picked = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now()); if (picked != null) setState(() => selectedDate = picked); }),
              const SizedBox(height: 12),
              TextFormField(controller: notesController, decoration: InputDecoration(labelText: 'Notes (Optional)', prefixIcon: const Icon(Icons.note, color: Colors.blue), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), maxLines: 2),
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), ElevatedButton(onPressed: () { if (formKey.currentState!.validate()) { widget.onAdd({'amount': double.parse(amountController.text), 'date': selectedDate, 'notes': notesController.text}); Navigator.pop(context); } }, style: ElevatedButton.styleFrom(backgroundColor: Colors.green[600]), child: const Text('Add Recovery', style: TextStyle(color: Colors.white)))],
    );
  }
}