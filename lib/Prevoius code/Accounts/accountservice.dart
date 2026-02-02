import 'package:supabase_flutter/supabase_flutter.dart';

import 'accountsmodel.dart';


class AccountService {
  final _supabase = Supabase.instance.client;

  // CREATE - Add new bank account
  Future<BankAccount> createAccount({
    required String bankName,
    required String holderName,
    String? accountNumber,
    required double initialBalance,
  }) async {
    try {
      final response = await _supabase
          .from('bank_accounts')
          .insert({
        'bank_name': bankName,
        'holder_name': holderName,
        'account_number': accountNumber,
        'total_balance': initialBalance,
      })
          .select()
          .single();

      return BankAccount.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create account: $e');
    }
  }

  // READ - Get all accounts
  Future<List<BankAccount>> getAllAccounts() async {
    try {
      final response = await _supabase
          .from('bank_accounts')
          .select()
          .order('created_at', ascending: false);

      return (response as List)
          .map((item) => BankAccount.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch accounts: $e');
    }
  }

  // READ - Get single account
  Future<BankAccount?> getAccountById(int id) async {
    try {
      final response = await _supabase
          .from('bank_accounts')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return BankAccount.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch account: $e');
    }
  }

  // UPDATE - Update account
  Future<BankAccount> updateAccount({
    required int id,
    required String bankName,
    required String holderName,
    String? accountNumber,
    required double totalBalance,
  }) async {
    try {
      final response = await _supabase
          .from('bank_accounts')
          .update({
        'bank_name': bankName,
        'holder_name': holderName,
        'account_number': accountNumber,
        'total_balance': totalBalance,
      })
          .eq('id', id)
          .select()
          .single();

      return BankAccount.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update account: $e');
    }
  }

  // DELETE - Delete account
  Future<void> deleteAccount(int id) async {
    try {
      await _supabase.from('bank_accounts').delete().eq('id', id);
    } catch (e) {
      throw Exception('Failed to delete account: $e');
    }
  }

  // TRANSFER - Transfer amount between accounts
  Future<AccountTransaction> transferAmount({
    required int fromAccountId,
    required int toAccountId,
    required double amount,
    required DateTime transactionDate,
    String? reason,
    required String performedBy,
  }) async {
    try {
      final fromAccount = await getAccountById(fromAccountId);
      final toAccount = await getAccountById(toAccountId);

      if (fromAccount == null || toAccount == null) {
        throw Exception('One or both accounts not found');
      }

      if (fromAccount.totalBalance < amount) {
        throw Exception('Insufficient balance in source account');
      }

      // Create transaction record
      final transactionResponse = await _supabase
          .from('account_transactions')
          .insert({
        'transaction_type': 'transfer',
        'from_account_id': fromAccountId,
        'to_account_id': toAccountId,
        'amount': amount,
        'transaction_date': transactionDate.toIso8601String().split('T')[0],
        'reason': reason,
        'performed_by': performedBy,
      })
          .select()
          .single();

      // Update account balances
      await _supabase
          .from('bank_accounts')
          .update({'total_balance': fromAccount.totalBalance - amount})
          .eq('id', fromAccountId);

      await _supabase
          .from('bank_accounts')
          .update({'total_balance': toAccount.totalBalance + amount})
          .eq('id', toAccountId);

      return AccountTransaction.fromJson(transactionResponse);
    } catch (e) {
      throw Exception('Transfer failed: $e');
    }
  }

  // WITHDRAWAL - Withdraw amount from account
  Future<AccountTransaction> withdrawAmount({
    required int accountId,
    required double amount,
    required DateTime transactionDate,
    String? reason,
    required String performedBy,
  }) async {
    try {
      final account = await getAccountById(accountId);

      if (account == null) {
        throw Exception('Account not found');
      }

      if (account.totalBalance < amount) {
        throw Exception('Insufficient balance');
      }

      // Create transaction record
      final transactionResponse = await _supabase
          .from('account_transactions')
          .insert({
        'transaction_type': 'withdrawal',
        'from_account_id': accountId,
        'amount': amount,
        'transaction_date': transactionDate.toIso8601String().split('T')[0],
        'reason': reason,
        'performed_by': performedBy,
      })
          .select()
          .single();

      // Update account balance
      await _supabase
          .from('bank_accounts')
          .update({'total_balance': account.totalBalance - amount})
          .eq('id', accountId);

      return AccountTransaction.fromJson(transactionResponse);
    } catch (e) {
      throw Exception('Withdrawal failed: $e');
    }
  }

  // DEPOSIT - Deposit amount to account
  Future<AccountTransaction> depositAmount({
    required int accountId,
    required double amount,
    required DateTime transactionDate,
    String? reason,
    required String performedBy,
  }) async {
    try {
      final account = await getAccountById(accountId);

      if (account == null) {
        throw Exception('Account not found');
      }

      // Create transaction record
      final transactionResponse = await _supabase
          .from('account_transactions')
          .insert({
        'transaction_type': 'deposit',
        'to_account_id': accountId,
        'amount': amount,
        'transaction_date': transactionDate.toIso8601String().split('T')[0],
        'reason': reason,
        'performed_by': performedBy,
      })
          .select()
          .single();

      // Update account balance
      await _supabase
          .from('bank_accounts')
          .update({'total_balance': account.totalBalance + amount})
          .eq('id', accountId);

      return AccountTransaction.fromJson(transactionResponse);
    } catch (e) {
      throw Exception('Deposit failed: $e');
    }
  }

  // GET TRANSACTIONS - Get all transactions
  Future<List<AccountTransaction>> getAllTransactions() async {
    try {
      final response = await _supabase
          .from('account_transactions')
          .select()
          .order('transaction_date', ascending: false);

      return (response as List)
          .map((item) => AccountTransaction.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch transactions: $e');
    }
  }

  // GET TRANSACTIONS BY ACCOUNT
  Future<List<AccountTransaction>> getAccountTransactions(int accountId) async {
    try {
      final response = await _supabase
          .from('account_transactions')
          .select()
          .or('from_account_id.eq.$accountId,to_account_id.eq.$accountId')
          .order('transaction_date', ascending: false);

      return (response as List)
          .map((item) => AccountTransaction.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch account transactions: $e');
    }
  }

  // GET TRANSACTIONS BY TYPE
  Future<List<AccountTransaction>> getTransactionsByType(String type) async {
    try {
      final response = await _supabase
          .from('account_transactions')
          .select()
          .eq('transaction_type', type)
          .order('transaction_date', ascending: false);

      return (response as List)
          .map((item) => AccountTransaction.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch transactions: $e');
    }
  }

  // GET TRANSACTIONS BY DATE RANGE
  Future<List<AccountTransaction>> getTransactionsByDateRange(
      DateTime startDate,
      DateTime endDate,
      ) async {
    try {
      final response = await _supabase
          .from('account_transactions')
          .select()
          .gte('transaction_date', startDate.toIso8601String().split('T')[0])
          .lte('transaction_date', endDate.toIso8601String().split('T')[0])
          .order('transaction_date', ascending: false);

      return (response as List)
          .map((item) => AccountTransaction.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch transactions: $e');
    }
  }

  // DELETE TRANSACTION (with password protection handled in UI)
  Future<void> deleteTransaction(int transactionId) async {
    try {
      await _supabase
          .from('account_transactions')
          .delete()
          .eq('id', transactionId);
    } catch (e) {
      throw Exception('Failed to delete transaction: $e');
    }
  }

  // GET TOTAL BALANCE ACROSS ALL ACCOUNTS
  Future<double> getTotalBalance() async {
    try {
      final accounts = await getAllAccounts();
      double total = 0.0;
      for (var account in accounts) {
        total += account.totalBalance;
      }
      return total;
    } catch (e) {
      throw Exception('Failed to calculate total balance: $e');
    }
  }
}