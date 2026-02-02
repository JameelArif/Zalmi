import 'package:supabase_flutter/supabase_flutter.dart';

import 'Quicksale.dart';


class QuickSaleService {
  final _supabase = Supabase.instance.client;

  // CREATE - Add new sale
  Future<QuickSale> createSale({
    required int employeeId,
    required int appId,
    required int customerId,
    required double coinsAmount,
    required double pkrAmount,
    required String rateType,
    required DateTime saleDate,
    required String saleBy,
  }) async {
    try {
      final response = await _supabase
          .from('quick_sales')
          .insert({
        'employee_id': employeeId,
        'app_id': appId,
        'customer_id': customerId,
        'coins_amount': coinsAmount,
        'pkr_amount': pkrAmount,
        'rate_type': rateType,
        'status': 'pending',
        'sale_date': saleDate.toIso8601String(),
        'sale_by': saleBy,
        'approved_by': null,
      })
          .select()
          .single();

      return QuickSale.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create sale: $e');
    }
  }

  // READ - Get all sales
  Future<List<QuickSale>> getAllSales() async {
    try {
      final response = await _supabase
          .from('quick_sales')
          .select()
          .order('sale_date', ascending: false);

      return (response as List)
          .map((item) => QuickSale.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch sales: $e');
    }
  }

  // READ - Get sales by employee
  Future<List<QuickSale>> getSalesByEmployee(int employeeId) async {
    try {
      final response = await _supabase
          .from('quick_sales')
          .select()
          .eq('employee_id', employeeId)
          .order('sale_date', ascending: false);

      return (response as List)
          .map((item) => QuickSale.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch employee sales: $e');
    }
  }

  // READ - Get sales by status
  Future<List<QuickSale>> getSalesByStatus(String status) async {
    try {
      final response = await _supabase
          .from('quick_sales')
          .select()
          .eq('status', status)
          .order('sale_date', ascending: false);

      return (response as List)
          .map((item) => QuickSale.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch sales by status: $e');
    }
  }

  // READ - Get pending sales
  Future<List<QuickSale>> getPendingSales() async {
    return getSalesByStatus('pending');
  }

  // UPDATE - Approve sale
  Future<QuickSale> approveSale({
    required int saleId,
    required String approvedBy,
  }) async {
    try {
      final response = await _supabase
          .from('quick_sales')
          .update({
        'status': 'approved',
        'approved_by': approvedBy,
      })
          .eq('id', saleId)
          .select()
          .single();

      return QuickSale.fromJson(response);
    } catch (e) {
      throw Exception('Failed to approve sale: $e');
    }
  }

  // UPDATE - Reject sale
  Future<QuickSale> rejectSale(int saleId) async {
    try {
      final response = await _supabase
          .from('quick_sales')
          .update({
        'status': 'rejected',
      })
          .eq('id', saleId)
          .select()
          .single();

      return QuickSale.fromJson(response);
    } catch (e) {
      throw Exception('Failed to reject sale: $e');
    }
  }

  // DELETE - Delete sale
  Future<void> deleteSale(int saleId) async {
    try {
      await _supabase.from('quick_sales').delete().eq('id', saleId);
    } catch (e) {
      throw Exception('Failed to delete sale: $e');
    }
  }

  // GET - Total sales amount for employee
  Future<double> getTotalSalesAmount(int employeeId) async {
    try {
      final response = await _supabase
          .from('quick_sales')
          .select('pkr_amount')
          .eq('employee_id', employeeId)
          .eq('status', 'approved');

      double total = 0;
      for (var sale in response) {
        total += (sale['pkr_amount'] as num).toDouble();
      }
      return total;
    } catch (e) {
      throw Exception('Failed to calculate total sales: $e');
    }
  }

  // GET - Get sales by date range
  Future<List<QuickSale>> getSalesByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final response = await _supabase
          .from('quick_sales')
          .select()
          .gte('sale_date', startDate.toIso8601String())
          .lte('sale_date', endDate.toIso8601String())
          .order('sale_date', ascending: false);

      return (response as List)
          .map((item) => QuickSale.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch sales by date range: $e');
    }
  }
}