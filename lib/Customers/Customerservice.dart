import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================
// CUSTOMER MODEL
// ============================================
class CustomerModel {
  final int id;
  final int adminId;
  final String customerName;
  final String customerContact;
  final DateTime createdAt;
  final DateTime updatedAt;

  CustomerModel({
    required this.id,
    required this.adminId,
    required this.customerName,
    required this.customerContact,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: json['id'] as int,
      adminId: json['admin_id'] as int,
      customerName: json['customer_name'] as String,
      customerContact: json['customer_contact'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'customer_name': customerName,
      'customer_contact': customerContact,
    };
  }

  CustomerModel copyWith({
    int? id,
    int? adminId,
    String? customerName,
    String? customerContact,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      adminId: adminId ?? this.adminId,
      customerName: customerName ?? this.customerName,
      customerContact: customerContact ?? this.customerContact,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'CustomerModel(id: $id, customerName: $customerName, customerContact: $customerContact)';
}

// ============================================
// CUSTOMER APPLICATION MODEL
// ============================================
class CustomerApplicationModel {
  final int id;
  final int customerId;
  final int applicationId;
  final double totalCredit;
  final DateTime createdAt;
  final DateTime updatedAt;

  CustomerApplicationModel({
    required this.id,
    required this.customerId,
    required this.applicationId,
    required this.totalCredit,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CustomerApplicationModel.fromJson(Map<String, dynamic> json) {
    return CustomerApplicationModel(
      id: json['id'] as int,
      customerId: json['customer_id'] as int,
      applicationId: json['application_id'] as int,
      totalCredit: (json['total_credit'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'customer_id': customerId,
      'application_id': applicationId,
      'total_credit': totalCredit,
    };
  }
}

// ============================================
// CUSTOMER SERVICE
// ============================================
class CustomerService {
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

  // Get all customers for current admin
  Future<List<CustomerModel>> getCustomers() async {
    try {
      final adminId = await _getAdminId();

      final response = await _supabase
          .from('customers')
          .select()
          .eq('admin_id', adminId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((item) => CustomerModel.fromJson(item))
          .toList();
    } catch (e) {
      throw Exception('Error fetching customers: $e');
    }
  }

  // Get single customer by ID
  Future<CustomerModel> getCustomerById(int id) async {
    try {
      final adminId = await _getAdminId();

      final response = await _supabase
          .from('customers')
          .select()
          .eq('id', id)
          .eq('admin_id', adminId)
          .single();

      return CustomerModel.fromJson(response);
    } catch (e) {
      throw Exception('Error fetching customer: $e');
    }
  }

  // Add new customer
  Future<CustomerModel> addCustomer({
    required String customerName,
    required String customerContact,
  }) async {
    try {
      final adminId = await _getAdminId();

      if (customerName.trim().isEmpty) {
        throw Exception('Customer name cannot be empty');
      }

      if (customerContact.trim().isEmpty) {
        throw Exception('Customer contact cannot be empty');
      }

      // Validate contact is numeric
      if (!RegExp(r'^[0-9\+\-\s]+$').hasMatch(customerContact)) {
        throw Exception('Contact should contain only numbers and +/-');
      }

      final response = await _supabase
          .from('customers')
          .insert({
        'admin_id': adminId,
        'customer_name': customerName.trim(),
        'customer_contact': customerContact.trim(),
      })
          .select()
          .single();

      return CustomerModel.fromJson(response);
    } catch (e) {
      throw Exception('Error adding customer: $e');
    }
  }

  // Update customer
  Future<CustomerModel> updateCustomer({
    required int id,
    String? customerName,
    String? customerContact,
  }) async {
    try {
      final adminId = await _getAdminId();
      final updateData = <String, dynamic>{};

      if (customerName != null) {
        if (customerName.trim().isEmpty) {
          throw Exception('Customer name cannot be empty');
        }
        updateData['customer_name'] = customerName.trim();
      }

      if (customerContact != null) {
        if (customerContact.trim().isEmpty) {
          throw Exception('Customer contact cannot be empty');
        }
        if (!RegExp(r'^[0-9\+\-\s]+$').hasMatch(customerContact)) {
          throw Exception('Contact should contain only numbers and +/-');
        }
        updateData['customer_contact'] = customerContact.trim();
      }

      if (updateData.isEmpty) {
        throw Exception('No data to update');
      }

      final response = await _supabase
          .from('customers')
          .update(updateData)
          .eq('id', id)
          .eq('admin_id', adminId)
          .select()
          .single();

      return CustomerModel.fromJson(response);
    } catch (e) {
      throw Exception('Error updating customer: $e');
    }
  }

  // Delete customer
  Future<void> deleteCustomer(int id) async {
    try {
      final adminId = await _getAdminId();

      await _supabase
          .from('customers')
          .delete()
          .eq('id', id)
          .eq('admin_id', adminId);
    } catch (e) {
      throw Exception('Error deleting customer: $e');
    }
  }

  // Search customers
  Future<List<CustomerModel>> searchCustomers(String query) async {
    try {
      final adminId = await _getAdminId();

      if (query.trim().isEmpty) {
        return getCustomers();
      }

      final response = await _supabase
          .from('customers')
          .select()
          .eq('admin_id', adminId)
          .or('customer_name.ilike.%$query%,customer_contact.ilike.%$query%')
          .order('created_at', ascending: false);

      return (response as List)
          .map((item) => CustomerModel.fromJson(item))
          .toList();
    } catch (e) {
      throw Exception('Error searching customers: $e');
    }
  }

  // Add application to customer
  Future<CustomerApplicationModel> addApplicationToCustomer({
    required int customerId,
    required int applicationId,
    required double totalCredit,
  }) async {
    try {
      if (totalCredit < 0) {
        throw Exception('Total credit cannot be negative');
      }

      final response = await _supabase
          .from('customer_applications')
          .insert({
        'customer_id': customerId,
        'application_id': applicationId,
        'total_credit': totalCredit,
      })
          .select()
          .single();

      return CustomerApplicationModel.fromJson(response);
    } catch (e) {
      throw Exception('Error adding application to customer: $e');
    }
  }

  // Get customer applications
  Future<List<Map<String, dynamic>>> getCustomerApplications(int customerId) async {
    try {
      final response = await _supabase
          .from('customer_applications')
          .select('*, applications(application_name, per_coin_rate, wholesale_rate)')
          .eq('customer_id', customerId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Error fetching customer applications: $e');
    }
  }

  // Update customer application credit
  Future<void> updateCustomerApplicationCredit({
    required int customerAppId,
    required double totalCredit,
  }) async {
    try {
      if (totalCredit < 0) {
        throw Exception('Total credit cannot be negative');
      }

      await _supabase
          .from('customer_applications')
          .update({'total_credit': totalCredit})
          .eq('id', customerAppId);
    } catch (e) {
      throw Exception('Error updating application credit: $e');
    }
  }

  // Delete customer application
  Future<void> deleteCustomerApplication(int customerAppId) async {
    try {
      await _supabase
          .from('customer_applications')
          .delete()
          .eq('id', customerAppId);
    } catch (e) {
      throw Exception('Error deleting customer application: $e');
    }
  }

  // Get statistics
  Future<Map<String, dynamic>> getStatistics() async {
    try {
      final customers = await getCustomers();

      return {
        'totalCustomers': customers.length,
      };
    } catch (e) {
      throw Exception('Error getting statistics: $e');
    }
  }
}