import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'Bankaccountservice.dart';


class BankAccountManagement extends StatefulWidget {
  const BankAccountManagement({super.key});

  @override
  State<BankAccountManagement> createState() => _BankAccountManagementState();
}

class _BankAccountManagementState extends State<BankAccountManagement> {
  final _bankAccountService = BankAccountService();

  List<BankAccountModel> _accounts = [];
  List<BankTransactionModel> _transactions = [];
  Map<String, dynamic> _statistics = {};

  bool _isLoading = true;
  bool _isProcessing = false;
  String _searchQuery = '';

  // Form controllers
  final _bankNameController = TextEditingController();
  final _holderNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _openingBalanceController = TextEditingController();

  // Transaction controllers
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();
  final _referenceNoController = TextEditingController();

  // Filter variables
  DateTime? _filterFromDate;
  DateTime? _filterToDate;
  String _filterTransactionType = 'All'; // All, transfer, withdrawal

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _bankNameController.dispose();
    _holderNameController.dispose();
    _accountNumberController.dispose();
    _openingBalanceController.dispose();
    _amountController.dispose();
    _reasonController.dispose();
    _referenceNoController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);

      final accounts = await _bankAccountService.getBankAccounts();
      final stats = await _bankAccountService.getBankStatistics();
      final transactions = await _bankAccountService.getTransactions();

      setState(() {
        _accounts = accounts;
        _statistics = stats;
        _transactions = transactions;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error: ${e.toString()}', Colors.red);
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addBankAccount() async {
    if (_bankNameController.text.isEmpty ||
        _holderNameController.text.isEmpty ||
        _accountNumberController.text.isEmpty ||
        _openingBalanceController.text.isEmpty) {
      _showSnackBar('Please fill all fields', Colors.red);
      return;
    }

    try {
      setState(() => _isProcessing = true);

      await _bankAccountService.addBankAccount(
        bankName: _bankNameController.text.trim(),
        holderName: _holderNameController.text.trim(),
        accountNumber: _accountNumberController.text.trim(),
        openingBalance: double.parse(_openingBalanceController.text),
      );

      _bankNameController.clear();
      _holderNameController.clear();
      _accountNumberController.clear();
      _openingBalanceController.clear();

      await _loadData();

      if (mounted) {
        _showSnackBar('Bank account added successfully!', Colors.green);
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', Colors.red);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _deleteAccount(int id) async {
    try {
      await _bankAccountService.deleteBankAccount(id);
      await _loadData();
      if (mounted) {
        _showSnackBar('Account deleted!', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', Colors.red);
    }
  }

  Future<void> _toggleAccountStatus(BankAccountModel account) async {
    try {
      final newStatus = account.status == 'active' ? 'inactive' : 'active';
      await _bankAccountService.updateBankAccount(
        id: account.id,
        status: newStatus,
      );
      await _loadData();
      if (mounted) {
        _showSnackBar(
            'Account status changed to $newStatus!', Colors.green);
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', Colors.red);
    }
  }

  Future<void> _makeTransfer(int fromAccountId, int toAccountId) async {
    if (_amountController.text.isEmpty || _reasonController.text.isEmpty) {
      _showSnackBar('Please fill all fields', Colors.red);
      return;
    }

    try {
      setState(() => _isProcessing = true);

      await _bankAccountService.transferBetweenAccounts(
        fromAccountId: fromAccountId,
        toAccountId: toAccountId,
        amount: double.parse(_amountController.text),
        reason: _reasonController.text.trim(),
        referenceNo: _referenceNoController.text.trim(),
      );

      _amountController.clear();
      _reasonController.clear();
      _referenceNoController.clear();

      await _loadData();

      if (mounted) {
        _showSnackBar('Transfer successful!', Colors.green);
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', Colors.red);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _makeWithdrawal(int accountId) async {
    if (_amountController.text.isEmpty || _reasonController.text.isEmpty) {
      _showSnackBar('Please fill all fields', Colors.red);
      return;
    }

    try {
      setState(() => _isProcessing = true);

      await _bankAccountService.withdrawFromAccount(
        accountId: accountId,
        amount: double.parse(_amountController.text),
        reason: _reasonController.text.trim(),
        referenceNo: _referenceNoController.text.trim(),
      );

      _amountController.clear();
      _reasonController.clear();
      _referenceNoController.clear();

      await _loadData();

      if (mounted) {
        _showSnackBar('Withdrawal successful!', Colors.green);
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', Colors.red);
    } finally {
      setState(() => _isProcessing = false);
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

  void _showAddAccountDialog() {
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
                      'Add Bank Account',
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
                  controller: _bankNameController,
                  label: 'Bank Name',
                  icon: Icons.account_balance,
                  color: Colors.blue,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _holderNameController,
                  label: 'Account Holder Name',
                  icon: Icons.person,
                  color: Colors.green,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _accountNumberController,
                  label: 'Account Number',
                  icon: Icons.numbers,
                  color: Colors.orange,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _openingBalanceController,
                  label: 'Opening Balance',
                  icon: Icons.payments,
                  color: Colors.purple,
                  isNumber: true,
                  decimal: true,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _addBankAccount,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      disabledBackgroundColor: Colors.grey,
                    ),
                    child: _isProcessing
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
                      'Add Account',
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

  void _showTransferDialog() {
    int? selectedFromAccount;
    int? selectedToAccount;
    DateTime? selectedDate;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: const Text(
                        'Transfer Between Accounts',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close, color: Colors.black54),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                StatefulBuilder(
                  builder: (context, setState) => Column(
                    children: [
                      // From Account
                      DropdownButtonFormField<int>(
                        decoration: InputDecoration(
                          labelText: 'From Account',
                          labelStyle: const TextStyle(color: Colors.blue),
                          prefixIcon: const Icon(Icons.account_balance,
                              color: Colors.blue),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.blue),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                        ),
                        value: selectedFromAccount,
                        isExpanded: true,
                        onChanged: (value) {
                          setState(() => selectedFromAccount = value);
                        },
                        items: _accounts
                            .where((a) => a.status == 'active')
                            .map((account) =>
                            DropdownMenuItem<int>(
                              value: account.id,
                              child: Text(
                                '${account.bankName} - ${account.holderName}\n(${account.accountNumber})',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ))
                            .toList(),
                      ),
                      const SizedBox(height: 14),
                      // To Account
                      DropdownButtonFormField<int>(
                        decoration: InputDecoration(
                          labelText: 'To Account',
                          labelStyle: const TextStyle(color: Colors.green),
                          prefixIcon: const Icon(Icons.account_balance,
                              color: Colors.green),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.green),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                        ),
                        value: selectedToAccount,
                        isExpanded: true,
                        onChanged: (value) {
                          setState(() => selectedToAccount = value);
                        },
                        items: _accounts
                            .where((a) =>
                        a.status == 'active' &&
                            a.id != selectedFromAccount)
                            .map((account) =>
                            DropdownMenuItem<int>(
                              value: account.id,
                              child: Text(
                                '${account.bankName} - ${account.holderName}\n(${account.accountNumber})',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ))
                            .toList(),
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _amountController,
                        label: 'Amount',
                        icon: Icons.payments,
                        color: Colors.orange,
                        isNumber: true,
                        decimal: true,
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _reasonController,
                        label: 'Reason',
                        icon: Icons.description,
                        color: Colors.purple,
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _referenceNoController,
                        label: 'Reference No (Optional)',
                        icon: Icons.error,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 14),
                      // Date Picker
                      GestureDetector(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: selectedDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setState(() => selectedDate = date);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.teal),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, color: Colors.teal),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  selectedDate == null
                                      ? 'Transaction Date (Today)'
                                      : DateFormat('MMM dd, yyyy')
                                      .format(selectedDate!),
                                  style: TextStyle(
                                    color: selectedDate == null
                                        ? Colors.grey[600]
                                        : Colors.black,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey[300],
                                foregroundColor: Colors.black,
                                padding:
                                const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Cancel', style: TextStyle(fontSize: 14)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: selectedFromAccount != null &&
                                  selectedToAccount != null &&
                                  !_isProcessing
                                  ? () => _makeTransfer(
                                  selectedFromAccount!,
                                  selectedToAccount!)
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding:
                                const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                disabledBackgroundColor: Colors.grey,
                              ),
                              child: const Text('Transfer', style: TextStyle(fontSize: 14)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showWithdrawalDialog(int accountId) {
    DateTime? selectedDate;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: const Text(
                        'Withdraw from Account',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close, color: Colors.black54),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                StatefulBuilder(
                  builder: (context, setState) => Column(
                    children: [
                      _buildTextField(
                        controller: _amountController,
                        label: 'Amount',
                        icon: Icons.payments,
                        color: Colors.orange,
                        isNumber: true,
                        decimal: true,
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _reasonController,
                        label: 'Reason for Withdrawal',
                        icon: Icons.description,
                        color: Colors.purple,
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(
                        controller: _referenceNoController,
                        label: 'Reference No (Optional)',
                        icon: Icons.error,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 14),
                      // Date Picker
                      GestureDetector(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: selectedDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setState(() => selectedDate = date);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.deepOrange),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, color: Colors.deepOrange),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  selectedDate == null
                                      ? 'Withdrawal Date (Today)'
                                      : DateFormat('MMM dd, yyyy')
                                      .format(selectedDate!),
                                  style: TextStyle(
                                    color: selectedDate == null
                                        ? Colors.grey[600]
                                        : Colors.black,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey[300],
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Cancel', style: TextStyle(fontSize: 14)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: !_isProcessing
                                  ? () => _makeWithdrawal(accountId)
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                disabledBackgroundColor: Colors.grey,
                              ),
                              child: const Text('Withdraw', style: TextStyle(fontSize: 14)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _applyTransactionFilters() async {
    try {
      var transactions = await _bankAccountService.getTransactions(
        fromDate: _filterFromDate,
        toDate: _filterToDate,
        transactionType:
        _filterTransactionType == 'All' ? null : _filterTransactionType,
      );

      setState(() {
        _transactions = transactions;
      });
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.blue,
          elevation: 0,
          title: const Text('Bank Account Management'),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'Accounts'),
              Tab(text: 'Transactions'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
        )
            : TabBarView(
          children: [
            // Accounts Tab
            Column(
              children: [
                // Statistics Header
                Container(
                  width: MediaQuery.of(context).size.width * 0.9,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1976D2), Color(0xFF1565C0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bank Accounts',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                        children: [
                          _statsCard(
                            label: 'Total Balance',
                            value:
                            '₨ ${(_statistics['totalBalance'] ?? 0.0).toStringAsFixed(2)}',
                            icon: Icons.account_balance_wallet,
                            color: Colors.green,
                          ),
                          _statsCard(
                            label: 'Active Accounts',
                            value: (_statistics['activeAccounts'] ?? 0)
                                .toString(),
                            icon: Icons.check_circle,
                            color: Colors.lightGreen,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                        children: [
                          _statsCard(
                            label: 'Total Accounts',
                            value: (_statistics['totalAccounts'] ?? 0)
                                .toString(),
                            icon: Icons.account_balance,
                            color: Colors.blue,
                          ),
                          _statsCard(
                            label: 'Inactive Accounts',
                            value: (_statistics['inactiveAccounts'] ?? 0)
                                .toString(),
                            icon: Icons.block,
                            color: Colors.red,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Accounts List
                Expanded(
                  child: _accounts.isEmpty
                      ? Center(
                    child: Column(
                      mainAxisAlignment:
                      MainAxisAlignment.center,
                      children: [
                        Icon(Icons.account_balance,
                            size: 64,
                            color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        const Text(
                          'No bank accounts yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                      : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    itemCount: _accounts.length,
                    itemBuilder: (context, index) {
                      final account = _accounts[index];
                      final isActive = account.status == 'active';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(16),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius:
                            BorderRadius.circular(16),
                            border: Border(
                              left: BorderSide(
                                color: isActive
                                    ? Colors.green[700]!
                                    : Colors.red[700]!,
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
                                Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment
                                      .spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment
                                            .start,
                                        children: [
                                          Text(
                                            account.bankName,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight:
                                              FontWeight.bold,
                                              color: Colors.black,
                                            ),
                                          ),
                                          const SizedBox(
                                              height: 4),
                                          Text(
                                            account.holderName,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color:
                                              Colors.grey[600],
                                            ),
                                          ),
                                          const SizedBox(
                                              height: 4),
                                          Text(
                                            'Account: ${account.accountNumber}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color:
                                              Colors.grey[500],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding:
                                      const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isActive
                                            ? Colors.green[50]
                                            : Colors.red[50],
                                        borderRadius:
                                        BorderRadius.circular(
                                            8),
                                        border: Border.all(
                                          color: isActive
                                              ? Colors.green[300]!
                                              : Colors.red[300]!,
                                        ),
                                      ),
                                      child: Text(
                                        account.status
                                            .toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight:
                                          FontWeight.bold,
                                          color: isActive
                                              ? Colors.green[700]
                                              : Colors.red[700],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                const Divider(height: 1),
                                const SizedBox(height: 12),
                                Row(
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
                                          'Current Balance',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color:
                                            Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '₨ ${account.currentBalance.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight:
                                            FontWeight.bold,
                                            color: Colors.blue,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (isActive)
                                      Flexible(
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Flexible(
                                              child: ElevatedButton.icon(
                                                onPressed: () =>
                                                    _showTransferDialog(),
                                                icon: const Icon(
                                                    Icons.swap_horiz,
                                                    size: 18),
                                                label: const Text(
                                                    'Transfer',
                                                    overflow:
                                                    TextOverflow.ellipsis),
                                                style:
                                                ElevatedButton
                                                    .styleFrom(
                                                  backgroundColor:
                                                  Colors.blue,
                                                  foregroundColor:
                                                  Colors.white,
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 10),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: ElevatedButton.icon(
                                                onPressed: () =>
                                                    _showWithdrawalDialog(
                                                        account.id),
                                                icon: const Icon(
                                                    Icons.money_off,
                                                    size: 18),
                                                label: const Text(
                                                    'Withdraw',
                                                    overflow:
                                                    TextOverflow.ellipsis),
                                                style:
                                                ElevatedButton
                                                    .styleFrom(
                                                  backgroundColor:
                                                  Colors.red,
                                                  foregroundColor:
                                                  Colors.white,
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 10),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.end,
                                  children: [
                                    PopupMenuButton(
                                      itemBuilder: (context) => [
                                        PopupMenuItem(
                                          child: Row(
                                            children: [
                                              Icon(
                                                isActive
                                                    ? Icons.block
                                                    : Icons
                                                    .check_circle,
                                                color: isActive
                                                    ? Colors.red
                                                    : Colors.green,
                                              ),
                                              const SizedBox(
                                                  width: 8),
                                              Text(isActive
                                                  ? 'Deactivate'
                                                  : 'Activate'),
                                            ],
                                          ),
                                          onTap: () {
                                            _toggleAccountStatus(
                                                account);
                                          },
                                        ),
                                        PopupMenuItem(
                                          child: const Row(
                                            children: [
                                              Icon(Icons.delete,
                                                  color:
                                                  Colors.red),
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
                                                        'Delete Account'),
                                                    content: const Text(
                                                        'Are you sure?'),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator
                                                                .pop(
                                                                context),
                                                        child: const Text(
                                                            'Cancel'),
                                                      ),
                                                      TextButton(
                                                        onPressed: () {
                                                          _deleteAccount(
                                                              account
                                                                  .id);
                                                          Navigator
                                                              .pop(
                                                              context);
                                                        },
                                                        child: const Text(
                                                          'Delete',
                                                          style: TextStyle(
                                                              color:
                                                              Colors
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

            // Transactions Tab
            Column(
              children: [
                // Filter Section
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Filters',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Date filters
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: _filterFromDate ??
                                      DateTime.now()
                                          .subtract(
                                          const Duration(days: 30)),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now(),
                                );
                                if (date != null) {
                                  setState(() =>
                                  _filterFromDate = date);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: Colors.grey[300]!),
                                  borderRadius:
                                  BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today,
                                        size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _filterFromDate == null
                                            ? 'From Date'
                                            : DateFormat('MMM dd, yyyy')
                                            .format(_filterFromDate!),
                                        style: const TextStyle(
                                            fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: _filterToDate ??
                                      DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now(),
                                );
                                if (date != null) {
                                  setState(() => _filterToDate = date);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: Colors.grey[300]!),
                                  borderRadius:
                                  BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today,
                                        size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _filterToDate == null
                                            ? 'To Date'
                                            : DateFormat('MMM dd, yyyy')
                                            .format(_filterToDate!),
                                        style: const TextStyle(
                                            fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Bank Account Filter
                      DropdownButtonFormField<int?>(
                        decoration: InputDecoration(
                          labelText: 'Bank Account',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        value: null,
                        onChanged: (value) {
                          // Filter will be applied with Apply Filters button
                        },
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('All Accounts'),
                          ),
                          ..._accounts
                              .map((account) =>
                              DropdownMenuItem<int>(
                                value: account.id,
                                child: Text(
                                  '${account.bankName} - ${account.accountNumber}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                              .toList(),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Transaction type filter
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Transaction Type',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        value: _filterTransactionType,
                        onChanged: (value) {
                          setState(() =>
                          _filterTransactionType = value ?? 'All');
                        },
                        items: ['All', 'transfer', 'withdrawal']
                            .map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        ))
                            .toList(),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _applyTransactionFilters,
                          icon: const Icon(Icons.filter_list),
                          label: const Text('Apply Filters'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding:
                            const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Transaction Summary
                if (_transactions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.blue[400]!,
                          Colors.blue[600]!,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Transaction Summary',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total Transactions',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _transactions.length.toString(),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Total Amount',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '₨ ${_transactions.fold(0.0, (sum, transaction) => sum + transaction.amount).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius:
                                  BorderRadius.circular(10),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Transfers',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.white
                                            .withOpacity(0.7),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '₨ ${_transactions.where((t) => t.transactionType == 'transfer').fold(0.0, (sum, transaction) => sum + transaction.amount).toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius:
                                  BorderRadius.circular(10),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Withdrawals',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.white
                                            .withOpacity(0.7),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '₨ ${_transactions.where((t) => t.transactionType == 'withdrawal').fold(0.0, (sum, transaction) => sum + transaction.amount).toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                // Transactions List
                Expanded(
                  child: _transactions.isEmpty
                      ? Center(
                    child: Column(
                      mainAxisAlignment:
                      MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history,
                            size: 64,
                            color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        const Text(
                          'No transactions found',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                      : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    itemCount: _transactions.length,
                    itemBuilder: (context, index) {
                      final transaction =
                      _transactions[index];
                      final isTransfer =
                          transaction.transactionType ==
                              'transfer';

                      // Get bank account names
                      final fromAccount = _accounts.firstWhere(
                            (acc) => acc.id == transaction.fromAccountId,
                        orElse: () => BankAccountModel(
                          id: 0,
                          adminId: 0,
                          bankName: 'Unknown',
                          holderName: 'Unknown',
                          accountNumber: '---',
                          openingBalance: 0,
                          currentBalance: 0,
                          status: 'unknown',
                          createdAt: DateTime.now(),
                          updatedAt: DateTime.now(),
                        ),
                      );

                      BankAccountModel? toAccount;
                      if (isTransfer && transaction.toAccountId != null) {
                        toAccount = _accounts.firstWhere(
                              (acc) => acc.id == transaction.toAccountId,
                          orElse: () => BankAccountModel(
                            id: 0,
                            adminId: 0,
                            bankName: 'Unknown',
                            holderName: 'Unknown',
                            accountNumber: '---',
                            openingBalance: 0,
                            currentBalance: 0,
                            status: 'unknown',
                            createdAt: DateTime.now(),
                            updatedAt: DateTime.now(),
                          ),
                        );
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isTransfer
                                          ? Colors.blue[50]
                                          : Colors.red[50],
                                      borderRadius:
                                      BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      isTransfer
                                          ? Icons.swap_horiz
                                          : Icons.money_off,
                                      color: isTransfer
                                          ? Colors.blue
                                          : Colors.red,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                      children: [
                                        Text(
                                          transaction.reason,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight:
                                            FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                          maxLines: 1,
                                          overflow:
                                          TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          isTransfer
                                              ? 'Inter-Bank Transfer'
                                              : 'Withdrawal',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          DateFormat(
                                              'MMM dd, yyyy - hh:mm a')
                                              .format(transaction
                                              .transactionDate),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '₨ ${transaction.amount.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight:
                                          FontWeight.bold,
                                          color: isTransfer
                                              ? Colors.blue
                                              : Colors.red,
                                        ),
                                      ),
                                      if (transaction.referenceNo !=
                                          null &&
                                          transaction.referenceNo!
                                              .isNotEmpty)
                                        const SizedBox(height: 4),
                                      if (transaction.referenceNo !=
                                          null &&
                                          transaction.referenceNo!
                                              .isNotEmpty)
                                        Text(
                                          'Ref: ${transaction.referenceNo}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Divider(height: 1),
                              const SizedBox(height: 12),
                              // Bank Details
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'From Account',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                            fontWeight:
                                            FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          fromAccount.bankName,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight:
                                            FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${fromAccount.holderName} (${fromAccount.accountNumber})',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[500],
                                          ),
                                          maxLines: 1,
                                          overflow:
                                          TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isTransfer && toAccount != null)
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment
                                            .start,
                                        children: [
                                          Text(
                                            'To Account',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[600],
                                              fontWeight:
                                              FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            toAccount.bankName,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight:
                                              FontWeight.bold,
                                              color: Colors.black,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${toAccount.holderName} (${toAccount.accountNumber})',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[500],
                                            ),
                                            maxLines: 1,
                                            overflow:
                                            TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showAddAccountDialog,
          backgroundColor: Colors.blue[700],
          elevation: 4,
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  Widget _statsCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
          ],
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
}