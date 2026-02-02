import 'package:supabase_flutter/supabase_flutter.dart';

import 'Customersmodel.dart';


class CustomerService {
  final _supabase = Supabase.instance.client;

  // CREATE - Add new customer
  Future<Customer> createCustomer({
    required String customerName,
    required String contact,
  }) async {
    try {
      final response = await _supabase
          .from('customers')
          .insert({
        'customer_name': customerName,
        'contact': contact,
      })
          .select()
          .single();

      return Customer.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create customer: $e');
    }
  }

  // READ - Get all customers
  Future<List<Customer>> getAllCustomers() async {
    try {
      final response = await _supabase
          .from('customers')
          .select()
          .order('created_at', ascending: false);

      return (response as List)
          .map((item) => Customer.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch customers: $e');
    }
  }

  // READ - Get single customer
  Future<Customer?> getCustomerById(int id) async {
    try {
      final response = await _supabase
          .from('customers')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return Customer.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch customer: $e');
    }
  }

  // UPDATE - Update customer
  Future<Customer> updateCustomer({
    required int id,
    required String customerName,
    required String contact,
  }) async {
    try {
      final response = await _supabase
          .from('customers')
          .update({
        'customer_name': customerName,
        'contact': contact,
      })
          .eq('id', id)
          .select()
          .single();

      return Customer.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update customer: $e');
    }
  }

  // DELETE - Delete customer
  Future<void> deleteCustomer(int id) async {
    try {
      await _supabase.from('customers').delete().eq('id', id);
    } catch (e) {
      throw Exception('Failed to delete customer: $e');
    }
  }

  // ADD APP BALANCE - Add balance for customer-app combination
  Future<CustomerAppBalance> addAppBalance({
    required int customerId,
    required int appId,
    required double openingCredit,
  }) async {
    try {
      final response = await _supabase
          .from('customer_app_balances')
          .insert({
        'customer_id': customerId,
        'app_id': appId,
        'opening_credit': openingCredit,
        'overall_balance': openingCredit,
      })
          .select()
          .single();

      return CustomerAppBalance.fromJson(response);
    } catch (e) {
      throw Exception('Failed to add app balance: $e');
    }
  }

  // GET APP BALANCES - Get all app balances for a customer
  Future<List<CustomerAppBalance>> getCustomerAppBalances(int customerId) async {
    try {
      final response = await _supabase
          .from('customer_app_balances')
          .select()
          .eq('customer_id', customerId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((item) => CustomerAppBalance.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch app balances: $e');
    }
  }

  // UPDATE APP BALANCE
  Future<CustomerAppBalance> updateAppBalance({
    required int balanceId,
    required double openingCredit,
    required double overallBalance,
  }) async {
    try {
      final response = await _supabase
          .from('customer_app_balances')
          .update({
        'opening_credit': openingCredit,
        'overall_balance': overallBalance,
      })
          .eq('id', balanceId)
          .select()
          .single();

      return CustomerAppBalance.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update app balance: $e');
    }
  }

  // DELETE APP BALANCE
  Future<void> deleteAppBalance(int balanceId) async {
    try {
      await _supabase
          .from('customer_app_balances')
          .delete()
          .eq('id', balanceId);
    } catch (e) {
      throw Exception('Failed to delete app balance: $e');
    }
  }

  // RECOVERY - Add recovery amount for app balance
  Future<CustomerRecovery> addRecovery({
    required int customerAppBalanceId,
    required double recoveryAmount,
    required DateTime recoveryDate,
    String? notes,
    required String recordedBy,
  }) async {
    try {
      // Get current balance
      final balanceResponse = await _supabase
          .from('customer_app_balances')
          .select()
          .eq('id', customerAppBalanceId)
          .single();

      final currentBalance = (balanceResponse['overall_balance'] as num).toDouble();

      // Add recovery record
      final recoveryResponse = await _supabase
          .from('customer_recovery')
          .insert({
        'customer_app_balance_id': customerAppBalanceId,
        'recovery_amount': recoveryAmount,
        'recovery_date': recoveryDate.toIso8601String().split('T')[0],
        'notes': notes,
        'recorded_by': recordedBy,
      })
          .select()
          .single();

      // Update balance (minus recovery from balance)
      final newBalance = currentBalance - recoveryAmount;
      await _supabase
          .from('customer_app_balances')
          .update({
        'overall_balance': newBalance,
        'last_recovery': DateTime.now().toIso8601String(),
      })
          .eq('id', customerAppBalanceId);

      return CustomerRecovery.fromJson(recoveryResponse);
    } catch (e) {
      throw Exception('Failed to add recovery: $e');
    }
  }

  // GET RECOVERIES - Get all recoveries for app balance
  Future<List<CustomerRecovery>> getAppBalanceRecoveries(int balanceId) async {
    try {
      final response = await _supabase
          .from('customer_recovery')
          .select()
          .eq('customer_app_balance_id', balanceId)
          .order('recovery_date', ascending: false);

      return (response as List)
          .map((item) => CustomerRecovery.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch recoveries: $e');
    }
  }

  // TOTALS - Get overall credit and balance
  Future<Map<String, double>> getTotals() async {
    try {
      final balances = await _supabase
          .from('customer_app_balances')
          .select('opening_credit, overall_balance');

      double totalCredit = 0.0;
      double totalBalance = 0.0;

      for (var item in balances) {
        totalCredit += (item['opening_credit'] as num).toDouble();
        totalBalance += (item['overall_balance'] as num).toDouble();
      }

      return {
        'total_credit': totalCredit,
        'total_balance': totalBalance,
      };
    } catch (e) {
      throw Exception('Failed to calculate totals: $e');
    }
  }

  // CHECK - Contact exists
  Future<bool> contactExists(String contact) async {
    try {
      final response = await _supabase
          .from('customers')
          .select('id')
          .eq('contact', contact)
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  // GET - Get all apps for dropdown (from inventory_apps table)
  Future<List<Map<String, dynamic>>> getAllApps() async {
    try {
      final response = await _supabase
          .from('inventory_apps')
          .select('id, app_name')
          .order('app_name', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch apps: $e');
    }
  }

  // GET - Get all customers with their balance for a specific app
  Future<List<CustomerAppBalance>> getAllCustomersWithAppBalance(int appId) async {
    try {
      final response = await _supabase
          .from('customer_app_balances')
          .select()
          .eq('app_id', appId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((item) => CustomerAppBalance.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch customers with balance: $e');
    }
  }
}