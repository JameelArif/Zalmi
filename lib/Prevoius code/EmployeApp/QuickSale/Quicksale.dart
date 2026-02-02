class QuickSale {
  final int id;
  final int employeeId;
  final int appId;
  final int customerId;
  final double coinsAmount;
  final double pkrAmount;
  final String rateType; // 'retail' or 'wholesale'
  final String status; // 'pending', 'approved', 'rejected'
  final DateTime saleDate;
  final String saleBy; // Employee email
  final String? approvedBy; // Admin email (null if pending)
  final DateTime createdAt;
  final DateTime updatedAt;

  QuickSale({
    required this.id,
    required this.employeeId,
    required this.appId,
    required this.customerId,
    required this.coinsAmount,
    required this.pkrAmount,
    required this.rateType,
    required this.status,
    required this.saleDate,
    required this.saleBy,
    this.approvedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory QuickSale.fromJson(Map<String, dynamic> json) {
    return QuickSale(
      id: json['id'] as int,
      employeeId: json['employee_id'] as int,
      appId: json['app_id'] as int,
      customerId: json['customer_id'] as int,
      coinsAmount: (json['coins_amount'] as num).toDouble(),
      pkrAmount: (json['pkr_amount'] as num).toDouble(),
      rateType: json['rate_type'] as String,
      status: json['status'] as String,
      saleDate: DateTime.parse(json['sale_date'] as String),
      saleBy: json['sale_by'] as String,
      approvedBy: json['approved_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'employee_id': employeeId,
      'app_id': appId,
      'customer_id': customerId,
      'coins_amount': coinsAmount,
      'pkr_amount': pkrAmount,
      'rate_type': rateType,
      'status': status,
      'sale_date': saleDate.toIso8601String(),
      'sale_by': saleBy,
      'approved_by': approvedBy,
    };
  }
}