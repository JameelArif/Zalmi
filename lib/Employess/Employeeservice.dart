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
      id: json['id'] as int,
      adminId: json['admin_id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      contact: json['contact'] as String,
      authId: json['auth_id'] as String,
      status: json['status'] as String,
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

  // Get all employees
  Future<List<EmployeeModel>> getEmployees() async {
    try {
      final adminId = await _getAdminId();

      final response = await _supabase
          .from('employees')
          .select()
          .eq('admin_id', adminId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((item) => EmployeeModel.fromJson(item))
          .toList();
    } catch (e) {
      throw Exception('Error fetching employees: $e');
    }
  }

  // Get single employee
  Future<EmployeeModel> getEmployee(int id) async {
    try {
      final adminId = await _getAdminId();

      final response = await _supabase
          .from('employees')
          .select()
          .eq('id', id)
          .eq('admin_id', adminId)
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
      final adminId = await _getAdminId();
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
      return await updateEmployee(
        id: employee.id,
        status: newStatus,
      );
    } catch (e) {
      throw Exception('Error toggling status: $e');
    }
  }
}