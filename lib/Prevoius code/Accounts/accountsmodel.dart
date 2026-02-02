class BankAccount {
  final int id;
  final String bankName;
  final String holderName;
  final String? accountNumber;
  final double totalBalance;
  final DateTime createdAt;
  final DateTime updatedAt;

  BankAccount({
    required this.id,
    required this.bankName,
    required this.holderName,
    this.accountNumber,
    required this.totalBalance,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BankAccount.fromJson(Map<String, dynamic> json) {
    return BankAccount(
      id: json['id'] as int,
      bankName: json['bank_name'] as String,
      holderName: json['holder_name'] as String,
      accountNumber: json['account_number'] as String?,
      totalBalance: (json['total_balance'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bank_name': bankName,
      'holder_name': holderName,
      'account_number': accountNumber,
      'total_balance': totalBalance,
    };
  }
}

class AccountTransaction {
  final int id;
  final String transactionType; // 'transfer', 'withdrawal', 'deposit'
  final int? fromAccountId;
  final int? toAccountId;
  final double amount;
  final DateTime transactionDate;
  final String? reason;
  final String? performedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  // For display purposes
  String? fromAccountName;
  String? toAccountName;

  AccountTransaction({
    required this.id,
    required this.transactionType,
    this.fromAccountId,
    this.toAccountId,
    required this.amount,
    required this.transactionDate,
    this.reason,
    this.performedBy,
    required this.createdAt,
    required this.updatedAt,
    this.fromAccountName,
    this.toAccountName,
  });

  factory AccountTransaction.fromJson(Map<String, dynamic> json) {
    return AccountTransaction(
      id: json['id'] as int,
      transactionType: json['transaction_type'] as String,
      fromAccountId: json['from_account_id'] as int?,
      toAccountId: json['to_account_id'] as int?,
      amount: (json['amount'] as num).toDouble(),
      transactionDate: DateTime.parse(json['transaction_date'] as String),
      reason: json['reason'] as String?,
      performedBy: json['performed_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transaction_type': transactionType,
      'from_account_id': fromAccountId,
      'to_account_id': toAccountId,
      'amount': amount,
      'transaction_date': transactionDate.toIso8601String().split('T')[0],
      'reason': reason,
      'performed_by': performedBy,
    };
  }
}