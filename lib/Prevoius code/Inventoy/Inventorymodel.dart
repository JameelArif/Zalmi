class InventoryApp {
  final int id;
  final String appName;
  final String details;
  final double openingCoins;
  final double overallCoins;
  final double totalCredit;
  final double coinSellingPrice;
  final double coinBuyingPrice;
  final double wholesalePrice;
  final DateTime createdAt;
  final DateTime updatedAt;

  InventoryApp({
    required this.id,
    required this.appName,
    required this.details,
    required this.openingCoins,
    required this.overallCoins,
    required this.totalCredit,
    required this.coinSellingPrice,
    required this.coinBuyingPrice,
    required this.wholesalePrice,
    required this.createdAt,
    required this.updatedAt,
  });

  factory InventoryApp.fromJson(Map<String, dynamic> json) {
    return InventoryApp(
      id: json['id'] as int,
      appName: json['app_name'] as String,
      details: json['details'] as String,
      openingCoins: (json['opening_coins'] as num).toDouble(),
      overallCoins: (json['overall_coins'] as num).toDouble(),
      totalCredit: (json['total_credit'] as num).toDouble(),
      coinSellingPrice: (json['coin_selling_price'] as num).toDouble(),
      coinBuyingPrice: (json['coin_buying_price'] as num).toDouble(),
      wholesalePrice: (json['wholesale_price'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'app_name': appName,
      'details': details,
      'opening_coins': openingCoins,
      'overall_coins': overallCoins,
      'total_credit': totalCredit,
      'coin_selling_price': coinSellingPrice,
      'coin_buying_price': coinBuyingPrice,
      'wholesale_price': wholesalePrice,
    };
  }
}

class InventoryLog {
  final int id;
  final int appId;
  final String fieldName;
  final String oldValue;
  final String newValue;
  final String changedBy;
  final DateTime changedAt;

  InventoryLog({
    required this.id,
    required this.appId,
    required this.fieldName,
    required this.oldValue,
    required this.newValue,
    required this.changedBy,
    required this.changedAt,
  });

  factory InventoryLog.fromJson(Map<String, dynamic> json) {
    return InventoryLog(
      id: json['id'] as int,
      appId: json['app_id'] as int,
      fieldName: json['field_name'] as String,
      oldValue: json['old_value'] as String,
      newValue: json['new_value'] as String,
      changedBy: json['changed_by'] as String,
      changedAt: DateTime.parse(json['changed_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'app_id': appId,
      'field_name': fieldName,
      'old_value': oldValue,
      'new_value': newValue,
      'changed_by': changedBy,
    };
  }
}