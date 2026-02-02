import 'package:supabase_flutter/supabase_flutter.dart';

import 'Inventorymodel.dart';

class InventoryService {
  final _supabase = Supabase.instance.client;

  // CREATE
  Future<InventoryApp> createApp({
    required String appName,
    required String details,
    required double openingCoins,
    required double totalCredit,
    required double coinSellingPrice,
    required double coinBuyingPrice,
    required double wholesalePrice,
    required String changedBy,
  }) async {
    try {
      final response = await _supabase
          .from('inventory_apps')
          .insert({
        'app_name': appName,
        'details': details,
        'opening_coins': openingCoins,
        'overall_coins': openingCoins,
        'total_credit': totalCredit,
        'coin_selling_price': coinSellingPrice,
        'coin_buying_price': coinBuyingPrice,
        'wholesale_price': wholesalePrice,
      })
          .select()
          .single();

      return InventoryApp.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create app: $e');
    }
  }

  // READ - Get all apps
  Future<List<InventoryApp>> getAllApps() async {
    try {
      final response = await _supabase
          .from('inventory_apps')
          .select()
          .order('created_at', ascending: false);

      return (response as List)
          .map((item) => InventoryApp.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch apps: $e');
    }
  }

  // READ - Get single app
  Future<InventoryApp?> getAppById(int id) async {
    try {
      final response = await _supabase
          .from('inventory_apps')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return InventoryApp.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch app: $e');
    }
  }

  // UPDATE - Update app with logging
  Future<InventoryApp> updateApp({
    required int id,
    required String appName,
    required String details,
    required double openingCoins,
    required double overallCoins,
    required double totalCredit,
    required double coinSellingPrice,
    required double coinBuyingPrice,
    required String changedBy,
  }) async {
    try {
      // Get old values for logging
      final oldApp = await getAppById(id);
      if (oldApp == null) throw Exception('App not found');

      // Update app
      final response = await _supabase
          .from('inventory_apps')
          .update({
        'app_name': appName,
        'details': details,
        'opening_coins': openingCoins,
        'overall_coins': overallCoins,
        'total_credit': totalCredit,
        'coin_selling_price': coinSellingPrice,
        'coin_buying_price': coinBuyingPrice,
      })
          .eq('id', id)
          .select()
          .single();

      final newApp = InventoryApp.fromJson(response);

      // Log all changes
      if (oldApp.appName != appName) {
        await _logChange(id, 'app_name', oldApp.appName, appName, changedBy);
      }
      if (oldApp.details != details) {
        await _logChange(id, 'details', oldApp.details, details, changedBy);
      }
      if (oldApp.openingCoins != openingCoins) {
        await _logChange(
            id, 'opening_coins', oldApp.openingCoins.toString(), openingCoins.toString(), changedBy);
      }
      if (oldApp.overallCoins != overallCoins) {
        await _logChange(
            id, 'overall_coins', oldApp.overallCoins.toString(), overallCoins.toString(), changedBy);
      }
      if (oldApp.totalCredit != totalCredit) {
        await _logChange(
            id, 'total_credit', oldApp.totalCredit.toString(), totalCredit.toString(), changedBy);
      }
      if (oldApp.coinSellingPrice != coinSellingPrice) {
        await _logChange(id, 'coin_selling_price', oldApp.coinSellingPrice.toString(),
            coinSellingPrice.toString(), changedBy);
      }
      if (oldApp.coinBuyingPrice != coinBuyingPrice) {
        await _logChange(id, 'coin_buying_price', oldApp.coinBuyingPrice.toString(),
            coinBuyingPrice.toString(), changedBy);
      }

      return newApp;
    } catch (e) {
      throw Exception('Failed to update app: $e');
    }
  }

  // DELETE
  Future<void> deleteApp(int id) async {
    try {
      await _supabase.from('inventory_apps').delete().eq('id', id);
    } catch (e) {
      throw Exception('Failed to delete app: $e');
    }
  }

  // LOGGING - Log changes
  Future<void> _logChange(
      int appId,
      String fieldName,
      String oldValue,
      String newValue,
      String changedBy,
      ) async {
    try {
      await _supabase.from('inventory_logs').insert({
        'app_id': appId,
        'field_name': fieldName,
        'old_value': oldValue,
        'new_value': newValue,
        'changed_by': changedBy,
      });
    } catch (e) {
      print('Failed to log change: $e');
    }
  }

  // GET LOGS - Get all logs for an app
  Future<List<InventoryLog>> getAppLogs(int appId) async {
    try {
      final response = await _supabase
          .from('inventory_logs')
          .select()
          .eq('app_id', appId)
          .order('changed_at', ascending: false);

      return (response as List)
          .map((item) => InventoryLog.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch logs: $e');
    }
  }

  // DELETE LOG - Delete a log entry
  Future<void> deleteLog(int logId) async {
    try {
      await _supabase.from('inventory_logs').delete().eq('id', logId);
    } catch (e) {
      throw Exception('Failed to delete log: $e');
    }
  }
}