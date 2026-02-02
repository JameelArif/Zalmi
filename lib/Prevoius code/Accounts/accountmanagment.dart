import 'package:flutter/material.dart';
import '../Login/authservice.dart';
import 'accountservice.dart';
import 'accountsmodel.dart';


class AccountManagement extends StatefulWidget {
  const AccountManagement({super.key});

  @override
  State<AccountManagement> createState() => _AccountManagementState();
}

class _AccountManagementState extends State<AccountManagement> {
  final accountService = AccountService();
  final authService = AuthService();

  List<BankAccount> accounts = [];
  List<AccountTransaction> allTransactions = [];
  List<AccountTransaction> filteredTransactions = [];
  bool isLoading = true;
  double totalBalance = 0;

  String filterType = 'All';
  String selectedAccount = 'All';
  DateTime? filterStartDate;
  DateTime? filterEndDate;

  // Colors for bank cards
  final List<LinearGradient> cardGradients = [
    LinearGradient(colors: [Colors.blue[600]!, Colors.blue[400]!]),
    LinearGradient(colors: [Colors.green[600]!, Colors.green[400]!]),
    LinearGradient(colors: [Colors.purple[600]!, Colors.purple[400]!]),
    LinearGradient(colors: [Colors.orange[600]!, Colors.orange[400]!]),
    LinearGradient(colors: [Colors.red[600]!, Colors.red[400]!]),
    LinearGradient(colors: [Colors.teal[600]!, Colors.teal[400]!]),
    LinearGradient(colors: [Colors.indigo[600]!, Colors.indigo[400]!]),
    LinearGradient(colors: [Colors.pink[600]!, Colors.pink[400]!]),
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final accountsList = await accountService.getAllAccounts();
      final transactions = await accountService.getAllTransactions();
      final total = await accountService.getTotalBalance();

      setState(() {
        accounts = accountsList;
        allTransactions = transactions;
        filteredTransactions = transactions;
        totalBalance = total;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  String _calculateTotalAmount() {
    double total = 0.0;
    for (var transaction in filteredTransactions) {
      total += transaction.amount;
    }
    return total.toStringAsFixed(2);
  }

  void _applyFilters() {
    List<AccountTransaction> filtered = allTransactions;

    if (filterType != 'All') {
      filtered = filtered.where((t) => t.transactionType.toLowerCase() == filterType.toLowerCase()).toList();
    }

    if (selectedAccount != 'All') {
      final accountId = int.parse(selectedAccount);
      filtered = filtered.where((t) => t.fromAccountId == accountId || t.toAccountId == accountId).toList();
    }

    if (filterStartDate != null && filterEndDate != null) {
      filtered = filtered.where((t) => t.transactionDate.isAfter(filterStartDate!) && t.transactionDate.isBefore(filterEndDate!.add(const Duration(days: 1)))).toList();
    }

    setState(() => filteredTransactions = filtered);
  }

  void _showAddAccountDialog() {
    showDialog(context: context, builder: (_) => AddAccountDialog(onAdd: (account) async {
      try {
        await accountService.createAccount(bankName: account['bankName'], holderName: account['holderName'], accountNumber: account['accountNumber'], initialBalance: account['initialBalance']);
        _loadData();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account added successfully')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }));
  }

  void _showTransferDialog() {
    showDialog(context: context, builder: (_) => TransferDialog(accounts: accounts, onTransfer: (transfer) async {
      try {
        final user = authService.getCurrentUser();
        await accountService.transferAmount(fromAccountId: transfer['fromAccountId'], toAccountId: transfer['toAccountId'], amount: transfer['amount'], transactionDate: transfer['date'], reason: transfer['reason'], performedBy: user?.email ?? 'Unknown');
        _loadData();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transfer completed successfully')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }));
  }

  void _showWithdrawalDialog() {
    showDialog(context: context, builder: (_) => WithdrawalDialog(accounts: accounts, onWithdraw: (withdrawal) async {
      try {
        final user = authService.getCurrentUser();
        await accountService.withdrawAmount(accountId: withdrawal['accountId'], amount: withdrawal['amount'], transactionDate: withdrawal['date'], reason: withdrawal['reason'], performedBy: user?.email ?? 'Unknown');
        _loadData();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Withdrawal completed successfully')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }));
  }

  void _showTransactionDetails(AccountTransaction transaction) {
    showDialog(context: context, builder: (_) => TransactionDetailsDialog(transaction: transaction, accounts: accounts, onDelete: (transactionId) async {
      final passwordController = TextEditingController();
      final result = await showDialog(context: context, builder: (context) => AlertDialog(title: const Text('Delete Transaction'), content: Column(mainAxisSize: MainAxisSize.min, children: [const Text('Enter security code to delete:'), const SizedBox(height: 16), TextField(controller: passwordController, obscureText: true, decoration: InputDecoration(hintText: 'Security Code', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), prefixIcon: const Icon(Icons.lock, color: Colors.blue)), keyboardType: TextInputType.number)]), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), ElevatedButton(onPressed: () { if (passwordController.text == '0909') { Navigator.pop(context, true); } else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid code'))); } }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red[600]), child: const Text('Delete', style: TextStyle(color: Colors.white)))]));

      if (result == true) {
        try {
          await accountService.deleteTransaction(transactionId);
          _loadData();
          Navigator.pop(context);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transaction deleted')));
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
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
                  const Text('Bank Accounts', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  ElevatedButton.icon(onPressed: _showAddAccountDialog, icon: const Icon(Icons.add, size: 18), label: const Text('Add Account'), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[600], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8))),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.grey[300]!, blurRadius: 8, offset: const Offset(0, 2))], border: Border(left: BorderSide(color: Colors.green, width: 4))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [Icon(Icons.account_balance, color: Colors.green, size: 24), const SizedBox(width: 8), Expanded(child: Text('Total Balance Across All Accounts', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)))]),
                    const SizedBox(height: 8),
                    Text('${totalBalance.toStringAsFixed(2)} PKR', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Accounts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  accounts.isEmpty
                      ? Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Text('No accounts yet', style: TextStyle(fontSize: 14, color: Colors.grey[600]))))
                      : SizedBox(
                    height: 180,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: accounts.length,
                      itemBuilder: (context, index) {
                        final account = accounts[index];
                        final gradient = cardGradients[index % cardGradients.length];
                        return Container(
                          width: 280,
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: gradient,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(color: gradient.colors[0].withOpacity(0.3), blurRadius: 8)],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(account.bankName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                                  const SizedBox(height: 4),
                                  Text(account.holderName, style: TextStyle(fontSize: 12, color: Colors.white70)),
                                  if (account.accountNumber != null) ...[
                                    const SizedBox(height: 4),
                                    Text('A/C: ${account.accountNumber}', style: TextStyle(fontSize: 11, color: Colors.white70)),
                                  ],
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Balance', style: TextStyle(fontSize: 11, color: Colors.white70)),
                                  Text('${account.totalBalance.toStringAsFixed(2)} PKR', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(child: ElevatedButton.icon(onPressed: _showTransferDialog, icon: const Icon(Icons.swap_horiz), label: const Text('Transfer'), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[600], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)))),
                  const SizedBox(width: 12),
                  Expanded(child: ElevatedButton.icon(onPressed: _showWithdrawalDialog, icon: const Icon(Icons.money_off), label: const Text('Withdrawal'), style: ElevatedButton.styleFrom(backgroundColor: Colors.red[600], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)))),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Filter Transactions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: DropdownButton<String>(value: filterType, isExpanded: true, items: ['All', 'Transfer', 'Withdrawal', 'Deposit'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (value) { setState(() => filterType = value ?? 'All'); _applyFilters(); })),
                      const SizedBox(width: 12),
                      Expanded(child: DropdownButton<String>(value: selectedAccount, isExpanded: true, items: [const DropdownMenuItem(value: 'All', child: Text('All Accounts')), ...accounts.map((a) => DropdownMenuItem(value: a.id.toString(), child: Text(a.bankName)))].toList(), onChanged: (value) { setState(() => selectedAccount = value ?? 'All'); _applyFilters(); })),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: InkWell(onTap: () async { final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now()); if (picked != null) setState(() => filterStartDate = picked); }, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)), child: Text(filterStartDate != null ? 'From: ${filterStartDate!.toString().split(' ')[0]}' : 'From Date', style: TextStyle(fontSize: 12, color: Colors.grey[700]))))),
                      const SizedBox(width: 12),
                      Expanded(child: InkWell(onTap: () async { final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now()); if (picked != null) setState(() => filterEndDate = picked); }, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)), child: Text(filterEndDate != null ? 'To: ${filterEndDate!.toString().split(' ')[0]}' : 'To Date', style: TextStyle(fontSize: 12, color: Colors.grey[700]))))),
                      const SizedBox(width: 12),
                      ElevatedButton(onPressed: _applyFilters, style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[600]), child: const Text('Apply')),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Transactions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      if (filteredTransactions.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.blue[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Total: ${_calculateTotalAmount()} PKR',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  filteredTransactions.isEmpty
                      ? Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Text('No transactions found', style: TextStyle(fontSize: 14, color: Colors.grey[600]))))
                      : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredTransactions.length,
                    itemBuilder: (context, index) {
                      final transaction = filteredTransactions[index];
                      final iconData = transaction.transactionType == 'transfer' ? Icons.swap_horiz : transaction.transactionType == 'withdrawal' ? Icons.money_off : Icons.arrow_downward;
                      final color = transaction.transactionType == 'transfer' ? Colors.orange : transaction.transactionType == 'withdrawal' ? Colors.red : Colors.green;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(backgroundColor: color.withOpacity(0.2), child: Icon(iconData, color: color)),
                          title: Text('${transaction.transactionType[0].toUpperCase()}${transaction.transactionType.substring(1)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(transaction.transactionDate.toString().split(' ')[0]),
                          trailing: Text('${transaction.amount.toStringAsFixed(2)} PKR', style: TextStyle(fontWeight: FontWeight.w600, color: color)),
                          onTap: () => _showTransactionDetails(transaction),
                        ),
                      );
                    },
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
}

// ADD ACCOUNT DIALOG
class AddAccountDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onAdd;
  const AddAccountDialog({super.key, required this.onAdd});
  @override
  State<AddAccountDialog> createState() => _AddAccountDialogState();
}

class _AddAccountDialogState extends State<AddAccountDialog> {
  final formKey = GlobalKey<FormState>();
  final bankNameController = TextEditingController();
  final holderNameController = TextEditingController();
  final accountNumberController = TextEditingController();
  final balanceController = TextEditingController();

  @override
  void dispose() {
    bankNameController.dispose();
    holderNameController.dispose();
    accountNumberController.dispose();
    balanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Bank Account'),
      content: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: bankNameController, decoration: InputDecoration(labelText: 'Bank Name', prefixIcon: const Icon(Icons.account_balance, color: Colors.blue), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), validator: (v) => v?.isEmpty ?? true ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(controller: holderNameController, decoration: InputDecoration(labelText: 'Holder Name', prefixIcon: const Icon(Icons.person, color: Colors.blue), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), validator: (v) => v?.isEmpty ?? true ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(controller: accountNumberController, decoration: InputDecoration(labelText: 'Account Number (Optional)', prefixIcon: const Icon(Icons.numbers, color: Colors.blue), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
              const SizedBox(height: 12),
              TextFormField(controller: balanceController, decoration: InputDecoration(labelText: 'Opening Balance (PKR)', prefixIcon: const Icon(Icons.money, color: Colors.blue), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), keyboardType: TextInputType.number, validator: (v) => v?.isEmpty ?? true ? 'Required' : null),
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), ElevatedButton(onPressed: () { if (formKey.currentState!.validate()) { widget.onAdd({'bankName': bankNameController.text, 'holderName': holderNameController.text, 'accountNumber': accountNumberController.text.isEmpty ? null : accountNumberController.text, 'initialBalance': double.parse(balanceController.text)}); Navigator.pop(context); } }, style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[600]), child: const Text('Add', style: TextStyle(color: Colors.white)))],
    );
  }
}

// TRANSFER DIALOG
class TransferDialog extends StatefulWidget {
  final List<BankAccount> accounts;
  final Function(Map<String, dynamic>) onTransfer;
  const TransferDialog({super.key, required this.accounts, required this.onTransfer});
  @override
  State<TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends State<TransferDialog> {
  final formKey = GlobalKey<FormState>();
  int? fromAccountId;
  int? toAccountId;
  final amountController = TextEditingController();
  final reasonController = TextEditingController();
  late DateTime selectedDate;

  @override
  void initState() {
    super.initState();
    selectedDate = DateTime.now();
  }

  @override
  void dispose() {
    amountController.dispose();
    reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Transfer Amount'),
      content: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: fromAccountId,
                decoration: InputDecoration(labelText: 'From Account', prefixIcon: const Icon(Icons.account_balance, color: Colors.blue), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                items: widget.accounts.map((a) => DropdownMenuItem(
                  value: a.id,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(a.bankName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('${a.holderName} - ${a.totalBalance.toStringAsFixed(2)} PKR', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    ],
                  ),
                )).toList(),
                onChanged: (value) => setState(() => fromAccountId = value),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: toAccountId,
                decoration: InputDecoration(labelText: 'To Account', prefixIcon: const Icon(Icons.account_balance, color: Colors.blue), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                items: widget.accounts.where((a) => a.id != fromAccountId).map((a) => DropdownMenuItem(
                  value: a.id,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(a.bankName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('${a.holderName} - ${a.totalBalance.toStringAsFixed(2)} PKR', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    ],
                  ),
                )).toList(),
                onChanged: (value) => setState(() => toAccountId = value),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(controller: amountController, decoration: InputDecoration(labelText: 'Amount (PKR)', prefixIcon: const Icon(Icons.money, color: Colors.blue), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), keyboardType: TextInputType.number, validator: (v) => v?.isEmpty ?? true ? 'Required' : null),
              const SizedBox(height: 12),
              ListTile(title: const Text('Date'), subtitle: Text(selectedDate.toString().split(' ')[0]), trailing: const Icon(Icons.calendar_today, color: Colors.blue), onTap: () async { final picked = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now()); if (picked != null) setState(() => selectedDate = picked); }),
              const SizedBox(height: 12),
              TextFormField(controller: reasonController, decoration: InputDecoration(labelText: 'Reason (Optional)', prefixIcon: const Icon(Icons.note, color: Colors.blue), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), maxLines: 2),
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), ElevatedButton(onPressed: () { if (formKey.currentState!.validate() && fromAccountId != null && toAccountId != null) { widget.onTransfer({'fromAccountId': fromAccountId, 'toAccountId': toAccountId, 'amount': double.parse(amountController.text), 'date': selectedDate, 'reason': reasonController.text}); Navigator.pop(context); } }, style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[600]), child: const Text('Transfer', style: TextStyle(color: Colors.white)))],
    );
  }
}

// WITHDRAWAL DIALOG
class WithdrawalDialog extends StatefulWidget {
  final List<BankAccount> accounts;
  final Function(Map<String, dynamic>) onWithdraw;
  const WithdrawalDialog({super.key, required this.accounts, required this.onWithdraw});
  @override
  State<WithdrawalDialog> createState() => _WithdrawalDialogState();
}

class _WithdrawalDialogState extends State<WithdrawalDialog> {
  final formKey = GlobalKey<FormState>();
  int? accountId;
  final amountController = TextEditingController();
  final reasonController = TextEditingController();
  late DateTime selectedDate;

  @override
  void initState() {
    super.initState();
    selectedDate = DateTime.now();
  }

  @override
  void dispose() {
    amountController.dispose();
    reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Withdrawal'),
      content: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: accountId,
                decoration: InputDecoration(labelText: 'Account', prefixIcon: const Icon(Icons.account_balance, color: Colors.blue), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                items: widget.accounts.map((a) => DropdownMenuItem(
                  value: a.id,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(a.bankName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('${a.holderName} - ${a.totalBalance.toStringAsFixed(2)} PKR', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    ],
                  ),
                )).toList(),
                onChanged: (value) => setState(() => accountId = value),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(controller: amountController, decoration: InputDecoration(labelText: 'Amount (PKR)', prefixIcon: const Icon(Icons.money, color: Colors.blue), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), keyboardType: TextInputType.number, validator: (v) => v?.isEmpty ?? true ? 'Required' : null),
              const SizedBox(height: 12),
              ListTile(title: const Text('Date'), subtitle: Text(selectedDate.toString().split(' ')[0]), trailing: const Icon(Icons.calendar_today, color: Colors.blue), onTap: () async { final picked = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now()); if (picked != null) setState(() => selectedDate = picked); }),
              const SizedBox(height: 12),
              TextFormField(controller: reasonController, decoration: InputDecoration(labelText: 'Reason (Optional)', prefixIcon: const Icon(Icons.note, color: Colors.blue), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), maxLines: 2),
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), ElevatedButton(onPressed: () { if (formKey.currentState!.validate() && accountId != null) { widget.onWithdraw({'accountId': accountId, 'amount': double.parse(amountController.text), 'date': selectedDate, 'reason': reasonController.text}); Navigator.pop(context); } }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red[600]), child: const Text('Withdraw', style: TextStyle(color: Colors.white)))],
    );
  }
}

// TRANSACTION DETAILS DIALOG
class TransactionDetailsDialog extends StatelessWidget {
  final AccountTransaction transaction;
  final List<BankAccount> accounts;
  final Function(int) onDelete;

  const TransactionDetailsDialog({super.key, required this.transaction, required this.accounts, required this.onDelete});

  String _getAccountName(int? accountId) {
    if (accountId == null) return 'N/A';
    return accounts.firstWhere((a) => a.id == accountId, orElse: () => BankAccount(id: 0, bankName: 'Unknown', holderName: 'Unknown', totalBalance: 0, createdAt: DateTime.now(), updatedAt: DateTime.now())).bankName;
  }

  @override
  Widget build(BuildContext context) {
    final fromName = transaction.transactionType == 'deposit' ? 'Deposit' : _getAccountName(transaction.fromAccountId);
    final toName = transaction.transactionType == 'withdrawal' ? 'Withdrawal' : _getAccountName(transaction.toAccountId);

    return AlertDialog(
      title: const Text('Transaction Details'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailTile('Type', '${transaction.transactionType[0].toUpperCase()}${transaction.transactionType.substring(1)}', Colors.blue),
            _buildDetailTile('Amount', '${transaction.amount.toStringAsFixed(2)} PKR', Colors.green),
            _buildDetailTile('Date', transaction.transactionDate.toString().split(' ')[0], Colors.orange),
            if (transaction.transactionType != 'deposit') _buildDetailTile('From', fromName, Colors.purple),
            if (transaction.transactionType != 'withdrawal') _buildDetailTile('To', toName, Colors.purple),
            if (transaction.reason != null) _buildDetailTile('Reason', transaction.reason!, Colors.grey),
            _buildDetailTile('By', transaction.performedBy ?? 'Unknown', Colors.grey),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => onDelete(transaction.id)),
      ],
    );
  }

  Widget _buildDetailTile(String label, String value, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.3))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w600)), Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color))],
      ),
    );
  }
}