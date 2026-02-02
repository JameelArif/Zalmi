class Customer {
  final int id;
  final String customerName;
  final String contact;
  final DateTime createdAt;
  final DateTime updatedAt;

  Customer({
    required this.id,
    required this.customerName,
    required this.contact,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as int,
      customerName: json['customer_name'] as String,
      contact: json['contact'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'customer_name': customerName,
      'contact': contact,
    };
  }
}

class CustomerAppBalance {
  final int id;
  final int customerId;
  final int appId;
  final String? appName; // For display
  final double openingCredit;
  final double overallBalance;
  final DateTime? lastSale;
  final DateTime? lastRecovery;
  final DateTime createdAt;
  final DateTime updatedAt;

  CustomerAppBalance({
    required this.id,
    required this.customerId,
    required this.appId,
    this.appName,
    required this.openingCredit,
    required this.overallBalance,
    this.lastSale,
    this.lastRecovery,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CustomerAppBalance.fromJson(Map<String, dynamic> json) {
    return CustomerAppBalance(
      id: json['id'] as int,
      customerId: json['customer_id'] as int,
      appId: json['app_id'] as int,
      appName: json['app_name'] as String?,
      openingCredit: (json['opening_credit'] as num).toDouble(),
      overallBalance: (json['overall_balance'] as num).toDouble(),
      lastSale: json['last_sale'] != null ? DateTime.parse(json['last_sale'] as String) : null,
      lastRecovery: json['last_recovery'] != null ? DateTime.parse(json['last_recovery'] as String) : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'customer_id': customerId,
      'app_id': appId,
      'opening_credit': openingCredit,
      'overall_balance': overallBalance,
      'last_sale': lastSale?.toIso8601String(),
      'last_recovery': lastRecovery?.toIso8601String(),
    };
  }
}

class CustomerRecovery {
  final int id;
  final int customerAppBalanceId;
  final double recoveryAmount;
  final DateTime recoveryDate;
  final String? notes;
  final String? recordedBy;
  final DateTime createdAt;

  CustomerRecovery({
    required this.id,
    required this.customerAppBalanceId,
    required this.recoveryAmount,
    required this.recoveryDate,
    this.notes,
    this.recordedBy,
    required this.createdAt,
  });

  factory CustomerRecovery.fromJson(Map<String, dynamic> json) {
    return CustomerRecovery(
      id: json['id'] as int,
      customerAppBalanceId: json['customer_app_balance_id'] as int,
      recoveryAmount: (json['recovery_amount'] as num).toDouble(),
      recoveryDate: DateTime.parse(json['recovery_date'] as String),
      notes: json['notes'] as String?,
      recordedBy: json['recorded_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'customer_app_balance_id': customerAppBalanceId,
      'recovery_amount': recoveryAmount,
      'recovery_date': recoveryDate.toIso8601String(),
      'notes': notes,
      'recorded_by': recordedBy,
    };
  }
}