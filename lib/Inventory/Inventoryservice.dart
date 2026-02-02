import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================
// APPLICATION MODEL
// ============================================
class ApplicationModel {
  final int id;
  final int adminId;
  final String applicationName;
  final double previousCredit;
  final double newCredit;
  final double totalCredit;
  final double totalCoins;
  final double perCoinRate;
  final double wholesaleRate;
  final DateTime createdAt;
  final DateTime updatedAt;

  ApplicationModel({
    required this.id,
    required this.adminId,
    required this.applicationName,
    required this.previousCredit,
    required this.newCredit,
    required this.totalCredit,
    required this.totalCoins,
    required this.perCoinRate,
    required this.wholesaleRate,
    required this.createdAt,
    required this.updatedAt,
  });

  // Convert from JSON (Supabase response)
  factory ApplicationModel.fromJson(Map<String, dynamic> json) {
    return ApplicationModel(
      id: json['id'] as int,
      adminId: json['admin_id'] as int,
      applicationName: json['application_name'] as String,
      previousCredit: (json['previous_credit'] as num).toDouble(),
      newCredit: (json['new_credit'] as num).toDouble(),
      totalCredit: (json['total_credit'] as num).toDouble(),
      totalCoins: (json['total_coins'] as num).toDouble(),
      perCoinRate: (json['per_coin_rate'] as num).toDouble(),
      wholesaleRate: (json['wholesale_rate'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  // Convert to JSON (for Supabase insert/update)
  Map<String, dynamic> toJson() {
    return {
      'application_name': applicationName,
      'previous_credit': previousCredit,
      'new_credit': newCredit,
      'total_coins': totalCoins,
      'per_coin_rate': perCoinRate,
      'wholesale_rate': wholesaleRate,
    };
  }

  // Create a copy with modifications
  ApplicationModel copyWith({
    int? id,
    int? adminId,
    String? applicationName,
    double? previousCredit,
    double? newCredit,
    double? totalCredit,
    double? totalCoins,
    double? perCoinRate,
    double? wholesaleRate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ApplicationModel(
      id: id ?? this.id,
      adminId: adminId ?? this.adminId,
      applicationName: applicationName ?? this.applicationName,
      previousCredit: previousCredit ?? this.previousCredit,
      newCredit: newCredit ?? this.newCredit,
      totalCredit: totalCredit ?? this.totalCredit,
      totalCoins: totalCoins ?? this.totalCoins,
      perCoinRate: perCoinRate ?? this.perCoinRate,
      wholesaleRate: wholesaleRate ?? this.wholesaleRate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'ApplicationModel(id: $id, applicationName: $applicationName, totalCredit: $totalCredit, totalCoins: $totalCoins)';
}

// ============================================
// INVENTORY SERVICE
// ============================================
class InventoryService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Get current admin ID
  Future<int> _getAdminId() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Get admin ID from admin table using user's email or ID
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

  // Get all applications for current admin
  Future<List<ApplicationModel>> getApplications() async {
    try {
      final adminId = await _getAdminId();

      final response = await _supabase
          .from('applications')
          .select()
          .eq('admin_id', adminId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((item) => ApplicationModel.fromJson(item))
          .toList();
    } catch (e) {
      throw Exception('Error fetching applications: $e');
    }
  }

  // Get single application by ID
  Future<ApplicationModel> getApplicationById(int id) async {
    try {
      final adminId = await _getAdminId();

      final response = await _supabase
          .from('applications')
          .select()
          .eq('id', id)
          .eq('admin_id', adminId)
          .single();

      return ApplicationModel.fromJson(response);
    } catch (e) {
      throw Exception('Error fetching application: $e');
    }
  }

  // Add new application
  Future<ApplicationModel> addApplication({
    required String applicationName,
    required double previousCredit,
    required double totalCoins,
    required double perCoinRate,
    required double wholesaleRate,
  }) async {
    try {
      final adminId = await _getAdminId();

      if (applicationName.trim().isEmpty) {
        throw Exception('Application name cannot be empty');
      }

      if (previousCredit < 0) {
        throw Exception('Previous credit cannot be negative');
      }

      if (totalCoins < 0) {
        throw Exception('Total coins cannot be negative');
      }

      if (perCoinRate < 0) {
        throw Exception('Per coin rate cannot be negative');
      }

      if (wholesaleRate < 0) {
        throw Exception('Wholesale rate cannot be negative');
      }

      final response = await _supabase
          .from('applications')
          .insert({
        'admin_id': adminId,
        'application_name': applicationName.trim(),
        'previous_credit': previousCredit,
        'new_credit': 0,
        'total_coins': totalCoins,
        'per_coin_rate': perCoinRate,
        'wholesale_rate': wholesaleRate,
      })
          .select()
          .single();

      return ApplicationModel.fromJson(response);
    } catch (e) {
      throw Exception('Error adding application: $e');
    }
  }

  // Update application
  Future<ApplicationModel> updateApplication({
    required int id,
    double? previousCredit,
    double? newCredit,
    double? totalCoins,
    double? perCoinRate,
    double? wholesaleRate,
  }) async {
    try {
      final adminId = await _getAdminId();
      final updateData = <String, dynamic>{};

      if (previousCredit != null) {
        if (previousCredit < 0) {
          throw Exception('Previous credit cannot be negative');
        }
        updateData['previous_credit'] = previousCredit;
      }

      if (newCredit != null) {
        if (newCredit < 0) {
          throw Exception('New credit cannot be negative');
        }
        updateData['new_credit'] = newCredit;
      }

      if (totalCoins != null) {
        if (totalCoins < 0) {
          throw Exception('Total coins cannot be negative');
        }
        updateData['total_coins'] = totalCoins;
      }

      if (perCoinRate != null) {
        if (perCoinRate < 0) {
          throw Exception('Per coin rate cannot be negative');
        }
        updateData['per_coin_rate'] = perCoinRate;
      }

      if (wholesaleRate != null) {
        if (wholesaleRate < 0) {
          throw Exception('Wholesale rate cannot be negative');
        }
        updateData['wholesale_rate'] = wholesaleRate;
      }

      if (updateData.isEmpty) {
        throw Exception('No data to update');
      }

      final response = await _supabase
          .from('applications')
          .update(updateData)
          .eq('id', id)
          .eq('admin_id', adminId)
          .select()
          .single();

      return ApplicationModel.fromJson(response);
    } catch (e) {
      throw Exception('Error updating application: $e');
    }
  }

  // Delete application
  Future<void> deleteApplication(int id) async {
    try {
      final adminId = await _getAdminId();

      await _supabase
          .from('applications')
          .delete()
          .eq('id', id)
          .eq('admin_id', adminId);
    } catch (e) {
      throw Exception('Error deleting application: $e');
    }
  }

  // Search applications
  Future<List<ApplicationModel>> searchApplications(String query) async {
    try {
      final adminId = await _getAdminId();

      if (query.trim().isEmpty) {
        return getApplications();
      }

      final response = await _supabase
          .from('applications')
          .select()
          .eq('admin_id', adminId)
          .ilike('application_name', '%$query%')
          .order('created_at', ascending: false);

      return (response as List)
          .map((item) => ApplicationModel.fromJson(item))
          .toList();
    } catch (e) {
      throw Exception('Error searching applications: $e');
    }
  }

  // Get statistics
  Future<Map<String, dynamic>> getStatistics() async {
    try {
      final applications = await getApplications();

      double totalPreviousCredit = 0;
      double totalNewCredit = 0;
      double totalCredit = 0;
      double totalCoins = 0;
      double sumPerCoinRate = 0;
      double sumWholesaleRate = 0;

      for (var app in applications) {
        totalPreviousCredit += app.previousCredit;
        totalNewCredit += app.newCredit;
        totalCredit += app.totalCredit;
        totalCoins += app.totalCoins;
        sumPerCoinRate += app.perCoinRate;
        sumWholesaleRate += app.wholesaleRate;
      }

      int appCount = applications.length;

      return {
        'totalApplications': appCount,
        'totalPreviousCredit': totalPreviousCredit,
        'totalNewCredit': totalNewCredit,
        'totalCredit': totalCredit,
        'totalCoins': totalCoins,
        'avgPerCoinRate': appCount > 0 ? sumPerCoinRate / appCount : 0.0,
        'avgWholesaleRate': appCount > 0 ? sumWholesaleRate / appCount : 0.0,
      };
    } catch (e) {
      throw Exception('Error getting statistics: $e');
    }
  }
}