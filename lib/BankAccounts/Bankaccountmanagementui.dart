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

  // ✅ NEW: Edit balance controllers
  final _newBalanceController = TextEditingController();
  final _editReasonController = TextEditingController();

  // Filter variables
  DateTime? _filterFromDate;
  DateTime? _filterToDate;
  String _filterTransactionType = 'All';

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
    _newBalanceController.dispose();
    _editReasonController.dispose();
    super.dispose();
  }

  // ✅ UPDATED: Added pull-to-refresh support
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
        _showSnackBar('Account status changed to $newStatus!', Colors.green);
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', Colors.red);
    }
  }

  // ✅ NEW: Edit Balance
  Future<void> _editBalance(int accountId) async {
    if (_newBalanceController.text.isEmpty ||
        _editReasonController.text.isEmpty) {
      _showSnackBar('Please fill all fields', Colors.red);
      return;
    }

    try {
      setState(() => _isProcessing = true);

      await _bankAccountService.editAccountBalance(
        accountId: accountId,
        newBalance: double.parse(_newBalanceController.text),
        reason: _editReasonController.text.trim(),
      );

      _newBalanceController.clear();
      _editReasonController.clear();

      await _loadData();

      if (mounted) {
        _showSnackBar('Balance updated successfully!', Colors.green);
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', Colors.red);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  // ✅ NEW: Show Edit Balance Dialog
  void _showEditBalanceDialog(BankAccountModel account) {
    _newBalanceController.text = account.currentBalance.toString();
    _editReasonController.clear();

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
                    Expanded(
                      child: Text(
                        'Edit Balance - ${account.bankName}',
                        style: const TextStyle(
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
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Current Balance:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '₨ ${account.currentBalance.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _newBalanceController,
                  label: 'New Balance',
                  icon: Icons.account_balance_wallet,
                  color: Colors.green,
                  isNumber: true,
                  decimal: true,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _editReasonController,
                  label: 'Reason for Edit (Required)',
                  icon: Icons.edit_note,
                  color: Colors.orange,
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
                        onPressed: _isProcessing
                            ? null
                            : () => _editBalance(account.id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
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
                            : const Text('Update Balance'),
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

  // ✅ NEW: Show Edit Logs Dialog
  void _showEditLogsDialog(BankAccountModel account) async {
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Edit History - ${account.bankName}',
                      style: const TextStyle(
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
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<List<BalanceEditLogModel>>(
                  future: _bankAccountService.getBalanceEditLogs(account.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      );
                    }

                    final logs = snapshot.data ?? [];

                    if (logs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            const Text(
                              'No edit history',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: logs.length,
                      itemBuilder: (context, index) {
                        final log = logs[index];
                        final isIncrease = log.editType == 'increase';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isIncrease
                                            ? Colors.green[50]
                                            : Colors.red[50],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        isIncrease
                                            ? Icons.arrow_upward
                                            : Icons.arrow_downward,
                                        color: isIncrease
                                            ? Colors.green
                                            : Colors.red,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isIncrease
                                                ? 'Balance Increased'
                                                : 'Balance Decreased',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            DateFormat('MMM dd, yyyy - hh:mm a')
                                                .format(log.createdAt),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '${isIncrease ? '+' : '-'}₨ ${log.changeAmount.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isIncrease
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                const Divider(height: 1),
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
                                          'Previous',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '₨ ${log.previousBalance.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Icon(Icons.arrow_forward,
                                        size: 20, color: Colors.grey[400]),
                                    Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'New Balance',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '₨ ${log.newBalance.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.blue[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey[200]!),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_note,
                                          size: 16, color: Colors.grey[600]),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          log.reason,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
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
                            .map((account) => DropdownMenuItem<int>(
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
                            .map((account) => DropdownMenuItem<int>(
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
                              child: const Text('Cancel',
                                  style: TextStyle(fontSize: 14)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: selectedFromAccount != null &&
                                  selectedToAccount != null &&
                                  !_isProcessing
                                  ? () => _makeTransfer(
                                  selectedFromAccount!, selectedToAccount!)
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                disabledBackgroundColor: Colors.grey,
                              ),
                              child: const Text('Transfer',
                                  style: TextStyle(fontSize: 14)),
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
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.65,
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
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
                        child: const Text('Cancel',
                            style: TextStyle(fontSize: 14)),
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
                        child: const Text('Withdraw',
                            style: TextStyle(fontSize: 14)),
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
            // ✅ UPDATED: Accounts Tab with RefreshIndicator
            RefreshIndicator(
              onRefresh: _loadData,
              child: Column(
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.account_balance,
                              size: 64, color: Colors.grey[300]),
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
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
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
                                            const SizedBox(height: 4),
                                            Text(
                                              account.holderName,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color:
                                                Colors.grey[600],
                                              ),
                                            ),
                                            const SizedBox(height: 4),
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
                                          BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isActive
                                                ? Colors.green[300]!
                                                : Colors.red[300]!,
                                          ),
                                        ),
                                        child: Text(
                                          account.status.toUpperCase(),
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
                                        CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Current Balance',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
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
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: [
                                            ElevatedButton.icon(
                                              onPressed: () =>
                                                  _showTransferDialog(),
                                              icon: const Icon(
                                                  Icons.swap_horiz,
                                                  size: 16),
                                              label: const Text(
                                                  'Transfer',
                                                  style: TextStyle(
                                                      fontSize: 12)),
                                              style: ElevatedButton
                                                  .styleFrom(
                                                backgroundColor:
                                                Colors.blue,
                                                foregroundColor:
                                                Colors.white,
                                                padding:
                                                const EdgeInsets
                                                    .symmetric(
                                                    horizontal: 8,
                                                    vertical: 8),
                                              ),
                                            ),
                                            ElevatedButton.icon(
                                              onPressed: () =>
                                                  _showWithdrawalDialog(
                                                      account.id),
                                              icon: const Icon(
                                                  Icons.money_off,
                                                  size: 16),
                                              label: const Text(
                                                  'Withdraw',
                                                  style: TextStyle(
                                                      fontSize: 12)),
                                              style: ElevatedButton
                                                  .styleFrom(
                                                backgroundColor:
                                                Colors.red,
                                                foregroundColor:
                                                Colors.white,
                                                padding:
                                                const EdgeInsets
                                                    .symmetric(
                                                    horizontal: 8,
                                                    vertical: 8),
                                              ),
                                            ),
                                          ],
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
                                          // ✅ NEW: Edit Balance option
                                          PopupMenuItem(
                                            child: const Row(
                                              children: [
                                                Icon(Icons.edit,
                                                    color: Colors
                                                        .orange),
                                                SizedBox(width: 8),
                                                Text('Edit Balance'),
                                              ],
                                            ),
                                            onTap: () {
                                              Future.delayed(
                                                const Duration(
                                                    milliseconds: 200),
                                                    () =>
                                                    _showEditBalanceDialog(
                                                        account),
                                              );
                                            },
                                          ),
                                          // ✅ NEW: View Edit Logs option
                                          PopupMenuItem(
                                            child: const Row(
                                              children: [
                                                Icon(Icons.history,
                                                    color:
                                                    Colors.purple),
                                                SizedBox(width: 8),
                                                Text('Edit History'),
                                              ],
                                            ),
                                            onTap: () {
                                              Future.delayed(
                                                const Duration(
                                                    milliseconds: 200),
                                                    () =>
                                                    _showEditLogsDialog(
                                                        account),
                                              );
                                            },
                                          ),
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
                                                          'Delete Account'),
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
                                                            _deleteAccount(
                                                                account
                                                                    .id);
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
            ),

            // Transactions Tab (continues in next message due to length)
            // ✅ UPDATED: Transactions Tab with RefreshIndicator
            RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Coming soon: Transaction filters and list',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
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