import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================
// BANK ACCOUNT MODEL
// ============================================
class BankAccountModel {
  final int id;
  final int adminId;
  final String bankName;
  final String holderName;
  final String accountNumber;
  final double openingBalance;
  final double currentBalance;
  final String status; // 'active' or 'inactive'
  final DateTime createdAt;
  final DateTime updatedAt;

  BankAccountModel({
    required this.id,
    required this.adminId,
    required this.bankName,
    required this.holderName,
    required this.accountNumber,
    required this.openingBalance,
    required this.currentBalance,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BankAccountModel.fromJson(Map<String, dynamic> json) {
    return BankAccountModel(
      id: json['id'] as int,
      adminId: json['admin_id'] as int,
      bankName: json['bank_name'] as String,
      holderName: json['holder_name'] as String,
      accountNumber: json['account_number'] as String,
      openingBalance: (json['opening_balance'] as num).toDouble(),
      currentBalance: (json['current_balance'] as num).toDouble(),
      status: json['status'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bank_name': bankName,
      'holder_name': holderName,
      'account_number': accountNumber,
      'opening_balance': openingBalance,
      'current_balance': currentBalance,
      'status': status,
    };
  }

  BankAccountModel copyWith({
    int? id,
    int? adminId,
    String? bankName,
    String? holderName,
    String? accountNumber,
    double? openingBalance,
    double? currentBalance,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BankAccountModel(
      id: id ?? this.id,
      adminId: adminId ?? this.adminId,
      bankName: bankName ?? this.bankName,
      holderName: holderName ?? this.holderName,
      accountNumber: accountNumber ?? this.accountNumber,
      openingBalance: openingBalance ?? this.openingBalance,
      currentBalance: currentBalance ?? this.currentBalance,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'BankAccountModel(id: $id, bankName: $bankName, holderName: $holderName, accountNumber: $accountNumber, currentBalance: $currentBalance, status: $status)';
}

// ============================================
// BANK TRANSACTION MODEL
// ============================================
class BankTransactionModel {
  final int id;
  final int adminId;
  final int fromAccountId;
  final int? toAccountId;
  final String transactionType; // 'transfer' or 'withdrawal'
  final double amount;
  final String reason;
  final String? referenceNo;
  final DateTime transactionDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  BankTransactionModel({
    required this.id,
    required this.adminId,
    required this.fromAccountId,
    required this.toAccountId,
    required this.transactionType,
    required this.amount,
    required this.reason,
    required this.referenceNo,
    required this.transactionDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BankTransactionModel.fromJson(Map<String, dynamic> json) {
    return BankTransactionModel(
      id: json['id'] as int,
      adminId: json['admin_id'] as int,
      fromAccountId: json['from_account_id'] as int,
      toAccountId: json['to_account_id'] as int?,
      transactionType: json['transaction_type'] as String,
      amount: (json['amount'] as num).toDouble(),
      reason: json['reason'] as String,
      referenceNo: json['reference_no'] as String?,
      transactionDate: json['transaction_date'] != null
          ? DateTime.parse(json['transaction_date'] as String)
          : DateTime.now(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'from_account_id': fromAccountId,
      'to_account_id': toAccountId,
      'transaction_type': transactionType,
      'amount': amount,
      'reason': reason,
      'reference_no': referenceNo,
      'transaction_date': transactionDate.toIso8601String(),
    };
  }

  @override
  String toString() =>
      'BankTransactionModel(id: $id, transactionType: $transactionType, amount: $amount, reason: $reason)';
}

// ============================================
// BANK ACCOUNT SERVICE
// ============================================
class BankAccountService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Get current admin ID
  Future<int> _getAdminId() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final response = await _supabase
          .from('admin')
          .select('id')
          .eq('auth_id', user.id)
          .single();

      return response['id'] as int;
    } catch (e) {
      throw Exception('Error getting admin ID: $e');
    }
  }

  // Get all bank accounts
  Future<List<BankAccountModel>> getBankAccounts() async {
    try {
      final adminId = await _getAdminId();

      final response = await _supabase
          .from('bank_accounts')
          .select()
          .eq('admin_id', adminId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((item) => BankAccountModel.fromJson(item))
          .toList();
    } catch (e) {
      throw Exception('Error fetching bank accounts: $e');
    }
  }

  // Get active bank accounts only
  Future<List<BankAccountModel>> getActiveBankAccounts() async {
    try {
      final adminId = await _getAdminId();

      final response = await _supabase
          .from('bank_accounts')
          .select()
          .eq('admin_id', adminId)
          .eq('status', 'active')
          .order('created_at', ascending: false);

      return (response as List)
          .map((item) => BankAccountModel.fromJson(item))
          .toList();
    } catch (e) {
      throw Exception('Error fetching active bank accounts: $e');
    }
  }

  // Add new bank account
  Future<BankAccountModel> addBankAccount({
    required String bankName,
    required String holderName,
    required String accountNumber,
    required double openingBalance,
  }) async {
    try {
      final adminId = await _getAdminId();

      if (bankName.trim().isEmpty) {
        throw Exception('Bank name cannot be empty');
      }

      if (holderName.trim().isEmpty) {
        throw Exception('Holder name cannot be empty');
      }

      if (accountNumber.trim().isEmpty) {
        throw Exception('Account number cannot be empty');
      }

      if (openingBalance < 0) {
        throw Exception('Opening balance cannot be negative');
      }

      final response = await _supabase
          .from('bank_accounts')
          .insert({
        'admin_id': adminId,
        'bank_name': bankName.trim(),
        'holder_name': holderName.trim(),
        'account_number': accountNumber.trim(),
        'opening_balance': openingBalance,
        'current_balance': openingBalance,
        'status': 'active',
      })
          .select()
          .single();

      // Handle response - it might be List or Map
      final jsonData = response is List ? response[0] : response;
      return BankAccountModel.fromJson(jsonData as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Error adding bank account: $e');
    }
  }

  // Update bank account
  Future<BankAccountModel> updateBankAccount({
    required int id,
    String? bankName,
    String? holderName,
    String? accountNumber,
    String? status,
  }) async {
    try {
      final adminId = await _getAdminId();
      final updateData = <String, dynamic>{};

      if (bankName != null && bankName.isNotEmpty) {
        updateData['bank_name'] = bankName.trim();
      }

      if (holderName != null && holderName.isNotEmpty) {
        updateData['holder_name'] = holderName.trim();
      }

      if (accountNumber != null && accountNumber.isNotEmpty) {
        updateData['account_number'] = accountNumber.trim();
      }

      if (status != null) {
        if (status != 'active' && status != 'inactive') {
          throw Exception('Invalid status. Must be active or inactive');
        }
        updateData['status'] = status;
      }

      if (updateData.isEmpty) {
        throw Exception('No data to update');
      }

      final response = await _supabase
          .from('bank_accounts')
          .update(updateData)
          .eq('id', id)
          .eq('admin_id', adminId)
          .select()
          .single();

      final jsonData = response is List ? response[0] : response;
      return BankAccountModel.fromJson(jsonData as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Error updating bank account: $e');
    }
  }

  // Delete bank account
  Future<void> deleteBankAccount(int id) async {
    try {
      final adminId = await _getAdminId();

      await _supabase
          .from('bank_accounts')
          .delete()
          .eq('id', id)
          .eq('admin_id', adminId);
    } catch (e) {
      throw Exception('Error deleting bank account: $e');
    }
  }

  // Transfer between accounts
  Future<BankTransactionModel> transferBetweenAccounts({
    required int fromAccountId,
    required int toAccountId,
    required double amount,
    required String reason,
    String? referenceNo,
  }) async {
    try {
      final adminId = await _getAdminId();

      if (amount <= 0) {
        throw Exception('Amount must be greater than 0');
      }

      if (fromAccountId == toAccountId) {
        throw Exception('Cannot transfer to the same account');
      }

      if (reason.trim().isEmpty) {
        throw Exception('Reason cannot be empty');
      }

      // Get from account
      final fromAccount = await _supabase
          .from('bank_accounts')
          .select()
          .eq('id', fromAccountId)
          .eq('admin_id', adminId)
          .single();

      final fromAccountJson = fromAccount is List ? fromAccount[0] : fromAccount;
      final fromAccountData = BankAccountModel.fromJson(fromAccountJson as Map<String, dynamic>);

      if (fromAccountData.status != 'active') {
        throw Exception('From account is inactive');
      }

      if (fromAccountData.currentBalance < amount) {
        throw Exception('Insufficient balance in from account');
      }

      // Get to account
      final toAccount = await _supabase
          .from('bank_accounts')
          .select()
          .eq('id', toAccountId)
          .eq('admin_id', adminId)
          .single();

      final toAccountJson = toAccount is List ? toAccount[0] : toAccount;
      final toAccountData = BankAccountModel.fromJson(toAccountJson as Map<String, dynamic>);

      if (toAccountData.status != 'active') {
        throw Exception('To account is inactive');
      }

      // Create transaction
      final transactionResponse = await _supabase
          .from('bank_transactions')
          .insert({
        'admin_id': adminId,
        'from_account_id': fromAccountId,
        'to_account_id': toAccountId,
        'transaction_type': 'transfer',
        'amount': amount,
        'reason': reason.trim(),
        'reference_no': referenceNo?.trim(),
        'transaction_date': DateTime.now().toIso8601String(),
      })
          .select()
          .single();

      final transactionJson = transactionResponse is List ? transactionResponse[0] : transactionResponse;

      // Update balances
      await _supabase
          .from('bank_accounts')
          .update({'current_balance': fromAccountData.currentBalance - amount})
          .eq('id', fromAccountId);

      await _supabase
          .from('bank_accounts')
          .update({'current_balance': toAccountData.currentBalance + amount})
          .eq('id', toAccountId);

      return BankTransactionModel.fromJson(transactionJson as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Error transferring between accounts: $e');
    }
  }

  // Withdraw from account
  Future<BankTransactionModel> withdrawFromAccount({
    required int accountId,
    required double amount,
    required String reason,
    String? referenceNo,
  }) async {
    try {
      final adminId = await _getAdminId();

      if (amount <= 0) {
        throw Exception('Amount must be greater than 0');
      }

      if (reason.trim().isEmpty) {
        throw Exception('Reason cannot be empty');
      }

      // Get account
      final account = await _supabase
          .from('bank_accounts')
          .select()
          .eq('id', accountId)
          .eq('admin_id', adminId)
          .single();

      final accountJson = account is List ? account[0] : account;
      final accountData = BankAccountModel.fromJson(accountJson as Map<String, dynamic>);

      if (accountData.status != 'active') {
        throw Exception('Account is inactive');
      }

      if (accountData.currentBalance < amount) {
        throw Exception('Insufficient balance');
      }

      // Create transaction
      final transactionResponse = await _supabase
          .from('bank_transactions')
          .insert({
        'admin_id': adminId,
        'from_account_id': accountId,
        'to_account_id': null,
        'transaction_type': 'withdrawal',
        'amount': amount,
        'reason': reason.trim(),
        'reference_no': referenceNo?.trim(),
        'transaction_date': DateTime.now().toIso8601String(),
      })
          .select()
          .single();

      final transactionJson = transactionResponse is List ? transactionResponse[0] : transactionResponse;

      // Update balance
      await _supabase
          .from('bank_accounts')
          .update({'current_balance': accountData.currentBalance - amount})
          .eq('id', accountId);

      return BankTransactionModel.fromJson(transactionJson as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Error withdrawing from account: $e');
    }
  }

  // Get transactions with filters
  Future<List<BankTransactionModel>> getTransactions({
    DateTime? fromDate,
    DateTime? toDate,
    int? accountId,
    String? transactionType,
  }) async {
    try {
      final adminId = await _getAdminId();

      var query = _supabase
          .from('bank_transactions')
          .select()
          .eq('admin_id', adminId);

      if (fromDate != null) {
        query = query.gte(
            'transaction_date', fromDate.toIso8601String());
      }

      if (toDate != null) {
        query = query.lte(
            'transaction_date', toDate.toIso8601String());
      }

      if (accountId != null) {
        query = query.or(
            'from_account_id.eq.$accountId,to_account_id.eq.$accountId');
      }

      if (transactionType != null) {
        query = query.eq('transaction_type', transactionType);
      }

      final response = await query.order('transaction_date', ascending: false);

      return (response as List)
          .map((item) => BankTransactionModel.fromJson(item))
          .toList();
    } catch (e) {
      throw Exception('Error fetching transactions: $e');
    }
  }

  // Get account balance
  Future<double> getAccountBalance(int accountId) async {
    try {
      final adminId = await _getAdminId();

      final response = await _supabase
          .from('bank_accounts')
          .select('current_balance')
          .eq('id', accountId)
          .eq('admin_id', adminId)
          .single();

      return (response['current_balance'] as num).toDouble();
    } catch (e) {
      throw Exception('Error getting account balance: $e');
    }
  }

  // Get total balance across all active accounts
  Future<double> getTotalBalance() async {
    try {
      final accounts = await getActiveBankAccounts();
      double totalBalance = 0.0;
      for (var account in accounts) {
        totalBalance += account.currentBalance;
      }
      return totalBalance;
    } catch (e) {
      throw Exception('Error getting total balance: $e');
    }
  }

  // Get statistics
  Future<Map<String, dynamic>> getBankStatistics() async {
    try {
      final adminId = await _getAdminId();
      final accounts = await getBankAccounts();

      double totalBalance = 0;
      double totalDeposits = 0;
      double totalWithdrawals = 0;
      int activeAccountsCount = 0;
      int inactiveAccountsCount = 0;

      for (var account in accounts) {
        totalBalance += account.currentBalance;
        if (account.status == 'active') {
          activeAccountsCount++;
        } else {
          inactiveAccountsCount++;
        }
      }

      // Get transaction statistics
      final transactions = await _supabase
          .from('bank_transactions')
          .select()
          .eq('admin_id', adminId);

      for (var transaction in transactions as List) {
        final amount = (transaction['amount'] as num).toDouble();
        if (transaction['transaction_type'] == 'transfer') {
          totalDeposits += amount;
        } else if (transaction['transaction_type'] == 'withdrawal') {
          totalWithdrawals += amount;
        }
      }

      return {
        'totalBalance': totalBalance,
        'totalAccounts': accounts.length,
        'activeAccounts': activeAccountsCount,
        'inactiveAccounts': inactiveAccountsCount,
        'totalDeposits': totalDeposits,
        'totalWithdrawals': totalWithdrawals,
      };
    } catch (e) {
      throw Exception('Error getting bank statistics: $e');
    }
  }
}