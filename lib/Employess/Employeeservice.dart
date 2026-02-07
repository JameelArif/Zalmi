import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================
// EMPLOYEE MODEL
// ============================================
class EmployeeModel {
  final int id;
  final int adminId;
  final String name;
  final String email;
  final String contact;
  final String authId;
  final String status; // 'active' or 'inactive'
  final DateTime createdAt;
  final DateTime updatedAt;

  EmployeeModel({
    required this.id,
    required this.adminId,
    required this.name,
    required this.email,
    required this.contact,
    required this.authId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    return EmployeeModel(
      id: (json['id'] as num).toInt(),
      adminId: (json['admin_id'] as num).toInt(),
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      contact: (json['contact'] ?? '').toString(),
      authId: (json['auth_id'] ?? '').toString(),
      status: (json['status'] ?? 'active').toString(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'admin_id': adminId,
      'name': name,
      'email': email,
      'contact': contact,
      'auth_id': authId,
      'status': status,
    };
  }

  @override
  String toString() =>
      'EmployeeModel(id: $id, name: $name, email: $email, contact: $contact, status: $status)';
}

// ============================================
// EMPLOYEE APP ASSIGNMENT MODEL
// ============================================
class EmployeeAppModel {
  final int id;
  final int employeeId;
  final int applicationId;
  final String applicationName;
  final DateTime assignedDate;
  final DateTime createdAt;

  EmployeeAppModel({
    required this.id,
    required this.employeeId,
    required this.applicationId,
    required this.applicationName,
    required this.assignedDate,
    required this.createdAt,
  });

  factory EmployeeAppModel.fromJson(Map<String, dynamic> json) {
    return EmployeeAppModel(
      id: json['id'] as int,
      employeeId: json['employee_id'] as int,
      applicationId: json['application_id'] as int,
      applicationName: json['application_name'] as String,
      assignedDate: json['assigned_date'] != null
          ? DateTime.parse(json['assigned_date'] as String)
          : DateTime.now(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'employee_id': employeeId,
      'application_id': applicationId,
      'application_name': applicationName,
      'assigned_date': assignedDate.toIso8601String(),
    };
  }
}

// ============================================
// EMPLOYEE SERVICE
// ============================================
class EmployeeService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Get current admin ID (same logic as cutsomer_addition: try employee then admin)
  Future<int> _getAdminId() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Not authenticated. Please log in again.');
      }

      // If logged in as employee, use their admin_id so web and phone behave the same
      final empRow = await _supabase
          .from('employees')
          .select('admin_id')
          .eq('auth_id', user.id)
          .maybeSingle();

      if (empRow != null) {
        return (empRow['admin_id'] as num).toInt();
      }

      // Otherwise treat as admin
      final adminRow = await _supabase
          .from('admin')
          .select('id')
          .eq('auth_id', user.id)
          .maybeSingle();

      if (adminRow != null) {
        return (adminRow['id'] as num).toInt();
      }

      throw Exception(
        'No admin or employee record found for this account. '
        'On web, ensure you are logged in with the same admin account used on the phone.',
      );
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Error getting admin ID: $e');
    }
  }

  /// Returns current admin/employee context ID or null (for debugging empty lists).
  Future<int?> getCurrentAdminIdOrNull() async {
    try {
      return await _getAdminId();
    } catch (_) {
      return null;
    }
  }

  /// Returns current auth.uid() (for debugging: compare with admin.auth_id in Supabase).
  String? getCurrentAuthUserId() {
    return _supabase.auth.currentUser?.id;
  }

  // Register and create employee
  Future<EmployeeModel> registerEmployee({
    required String name,
    required String email,
    required String password,
    required String contact,
  }) async {
    try {
      final adminId = await _getAdminId();

      if (name.trim().isEmpty) {
        throw Exception('Name cannot be empty');
      }

      if (email.trim().isEmpty) {
        throw Exception('Email cannot be empty');
      }

      if (password.trim().isEmpty || password.length < 6) {
        throw Exception('Password must be at least 6 characters');
      }

      if (contact.trim().isEmpty) {
        throw Exception('Contact cannot be empty');
      }

      // Register with Auth
      final authResponse = await _supabase.auth.signUp(
        email: email.trim(),
        password: password.trim(),
      );

      if (authResponse.user == null) {
        throw Exception('Failed to create authentication account');
      }

      final userId = authResponse.user!.id;

      // Create employee record
      final response = await _supabase
          .from('employees')
          .insert({
            'admin_id': adminId,
            'name': name.trim(),
            'email': email.trim(),
            'contact': contact.trim(),
            'auth_id': userId,
            'status': 'active',
          })
          .select()
          .single();

      final jsonData = response is List ? response[0] : response;
      return EmployeeModel.fromJson(jsonData as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Error registering employee: $e');
    }
  }

  // Get all employees (for all admins)
  Future<List<EmployeeModel>> getEmployees() async {
    try {
      final response = await _supabase
          .from('employees')
          .select()
          .order('created_at', ascending: false);

      final List<dynamic> rawList = _normalizeListResponse(response);
      return rawList
          .map((item) => EmployeeModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Error fetching employees: $e');
    }
  }

  /// Handles Supabase response: can be List or Map with 'data' key (platform-dependent).
  List<dynamic> _normalizeListResponse(dynamic response) {
    if (response == null) return [];
    if (response is List) return response;
    if (response is Map && response.containsKey('data')) {
      final data = response['data'];
      return data is List ? data : [];
    }
    return [];
  }

  // Get single employee
  Future<EmployeeModel> getEmployee(int id) async {
    try {
      final response = await _supabase
          .from('employees')
          .select()
          .eq('id', id)
          .single();

      final jsonData = response is List ? response[0] : response;
      return EmployeeModel.fromJson(jsonData as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Error fetching employee: $e');
    }
  }

  // Update employee
  Future<EmployeeModel> updateEmployee({
    required int id,
    String? name,
    String? email,
    String? contact,
    String? status,
  }) async {
    try {
      final adminId = await _getAdminId();
      final updateData = <String, dynamic>{};

      if (name != null && name.isNotEmpty) {
        updateData['name'] = name.trim();
      }

      if (email != null && email.isNotEmpty) {
        updateData['email'] = email.trim();
      }

      if (contact != null && contact.isNotEmpty) {
        updateData['contact'] = contact.trim();
      }

      if (status != null) {
        if (status != 'active' && status != 'inactive') {
          throw Exception('Invalid status. Must be active or inactive');
        }
        updateData['status'] = status;
      }

      if (updateData.isEmpty) {
        throw Exception('No data to update');
      }

      final response = await _supabase
          .from('employees')
          .update(updateData)
          .eq('id', id)
          .eq('admin_id', adminId)
          .select()
          .single();

      final jsonData = response is List ? response[0] : response;
      return EmployeeModel.fromJson(jsonData as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Error updating employee: $e');
    }
  }

  // Delete employee
  Future<void> deleteEmployee(int id) async {
    try {
      final adminId = await _getAdminId();

      await _supabase
          .from('employees')
          .delete()
          .eq('id', id)
          .eq('admin_id', adminId);
    } catch (e) {
      throw Exception('Error deleting employee: $e');
    }
  }

  // Assign app to employee
  Future<EmployeeAppModel> assignAppToEmployee({
    required int employeeId,
    required int applicationId,
    required String applicationName,
  }) async {
    try {
      // Check if already assigned
      final existing = await _supabase
          .from('employee_applications')
          .select()
          .eq('employee_id', employeeId)
          .eq('application_id', applicationId);

      if (existing.isNotEmpty) {
        throw Exception('This app is already assigned to this employee');
      }

      final response = await _supabase
          .from('employee_applications')
          .insert({
            'employee_id': employeeId,
            'application_id': applicationId,
            'application_name': applicationName,
            'assigned_date': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      final jsonData = response is List ? response[0] : response;
      return EmployeeAppModel.fromJson(jsonData as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Error assigning app: $e');
    }
  }

  // Get employee apps
  Future<List<EmployeeAppModel>> getEmployeeApps(int employeeId) async {
    try {
      final response = await _supabase
          .from('employee_applications')
          .select()
          .eq('employee_id', employeeId)
          .order('assigned_date', ascending: false);

      return (response as List)
          .map((item) => EmployeeAppModel.fromJson(item))
          .toList();
    } catch (e) {
      throw Exception('Error fetching employee apps: $e');
    }
  }

  // Remove app from employee
  Future<void> removeAppFromEmployee(int employeeAppId) async {
    try {
      await _supabase
          .from('employee_applications')
          .delete()
          .eq('id', employeeAppId);
    } catch (e) {
      throw Exception('Error removing app: $e');
    }
  }

  // Get employee statistics
  Future<Map<String, dynamic>> getEmployeeStatistics() async {
    try {
      final employees = await getEmployees();

      int activeCount = 0;
      int inactiveCount = 0;
      int totalAppsAssigned = 0;

      for (var employee in employees) {
        if (employee.status == 'active') {
          activeCount++;
        } else {
          inactiveCount++;
        }

        final apps = await getEmployeeApps(employee.id);
        totalAppsAssigned += apps.length;
      }

      return {
        'totalEmployees': employees.length,
        'activeEmployees': activeCount,
        'inactiveEmployees': inactiveCount,
        'totalAppsAssigned': totalAppsAssigned,
      };
    } catch (e) {
      throw Exception('Error getting statistics: $e');
    }
  }

  // Toggle employee status
  Future<EmployeeModel> toggleEmployeeStatus(EmployeeModel employee) async {
    try {
      final newStatus = employee.status == 'active' ? 'inactive' : 'active';
      return await updateEmployee(id: employee.id, status: newStatus);
    } catch (e) {
      throw Exception('Error toggling status: $e');
    }
  }
}
