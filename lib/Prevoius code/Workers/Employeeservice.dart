import 'package:supabase_flutter/supabase_flutter.dart';

import 'EmployeeAppAssignment.dart';
import 'employemodel.dart';


class EmployeeService {
  final _supabase = Supabase.instance.client;

  // REGISTER - Add new employee with Supabase Auth
  Future<Employee> registerEmployee({
    required String email,
    required String password,
    required String name,
    required String contact,
  }) async {
    try {
      // Check if email already exists in employees table
      final existingEmail = await _supabase
          .from('employees')
          .select('id')
          .eq('email', email)
          .maybeSingle();

      if (existingEmail != null) {
        throw Exception('Email already registered');
      }

      // Check if contact already exists
      final existingContact = await _supabase
          .from('employees')
          .select('id')
          .eq('contact', contact)
          .maybeSingle();

      if (existingContact != null) {
        throw Exception('Contact already registered');
      }

      // Create Supabase Auth user
      final authResponse = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      final uid = authResponse.user?.id;
      if (uid == null) {
        throw Exception('Failed to create auth user');
      }

      // Insert employee with uid
      final response = await _supabase
          .from('employees')
          .insert({
        'email': email,
        'name': name,
        'contact': contact,
        'uid': uid,
      })
          .select()
          .single();

      return Employee.fromJson(response);
    } catch (e) {
      throw Exception('Registration failed: $e');
    }
  }

  // LOGIN - Authenticate employee with Supabase Auth
  Future<Employee?> loginEmployee({
    required String email,
    required String password,
  }) async {
    try {
      // Sign in with Supabase Auth
      final authResponse = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final uid = authResponse.user?.id;
      if (uid == null) {
        return null;
      }

      // Get employee data
      final response = await _supabase
          .from('employees')
          .select()
          .eq('uid', uid)
          .eq('is_active', true)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return Employee.fromJson(response);
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  // LOGOUT - Sign out current user
  Future<void> logoutEmployee() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      throw Exception('Logout failed: $e');
    }
  }

  // GET CURRENT - Get current logged in employee
  Future<Employee?> getCurrentEmployee() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final response = await _supabase
          .from('employees')
          .select()
          .eq('uid', user.id)
          .maybeSingle();

      if (response == null) return null;
      return Employee.fromJson(response);
    } catch (e) {
      throw Exception('Failed to get current employee: $e');
    }
  }

  // READ - Get all employees
  Future<List<Employee>> getAllEmployees() async {
    try {
      final response = await _supabase
          .from('employees')
          .select()
          .order('created_at', ascending: false);

      return (response as List)
          .map((item) => Employee.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch employees: $e');
    }
  }

  // READ - Get single employee
  Future<Employee?> getEmployeeById(int id) async {
    try {
      final response = await _supabase
          .from('employees')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return Employee.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch employee: $e');
    }
  }

  // UPDATE - Update employee details
  Future<Employee> updateEmployee({
    required int id,
    required String name,
    required String contact,
  }) async {
    try {
      // Check if contact already used by another employee
      final existingContact = await _supabase
          .from('employees')
          .select('id')
          .eq('contact', contact)
          .neq('id', id)
          .maybeSingle();

      if (existingContact != null) {
        throw Exception('Contact already in use');
      }

      final response = await _supabase
          .from('employees')
          .update({
        'name': name,
        'contact': contact,
      })
          .eq('id', id)
          .select()
          .single();

      return Employee.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update employee: $e');
    }
  }

  // UPDATE - Change password using Supabase Auth
  Future<void> changePassword({
    required String newPassword,
  }) async {
    try {
      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } catch (e) {
      throw Exception('Failed to change password: $e');
    }
  }

  // UPDATE - Deactivate employee
  Future<void> deactivateEmployee(int id) async {
    try {
      await _supabase
          .from('employees')
          .update({'is_active': false})
          .eq('id', id);
    } catch (e) {
      throw Exception('Failed to deactivate employee: $e');
    }
  }

  // UPDATE - Activate employee
  Future<void> activateEmployee(int id) async {
    try {
      await _supabase
          .from('employees')
          .update({'is_active': true})
          .eq('id', id);
    } catch (e) {
      throw Exception('Failed to activate employee: $e');
    }
  }

  // DELETE - Delete employee
  Future<void> deleteEmployee(int id) async {
    try {
      await _supabase.from('employees').delete().eq('id', id);
    } catch (e) {
      throw Exception('Failed to delete employee: $e');
    }
  }

  // GET - Count active employees
  Future<int> getActiveEmployeeCount() async {
    try {
      final response = await _supabase
          .from('employees')
          .select('id')
          .eq('is_active', true);

      return (response as List).length;
    } catch (e) {
      throw Exception('Failed to count employees: $e');
    }
  }

  // GET - Get active employees only
  Future<List<Employee>> getActiveEmployees() async {
    try {
      final response = await _supabase
          .from('employees')
          .select()
          .eq('is_active', true)
          .order('name', ascending: true);

      return (response as List)
          .map((item) => Employee.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch active employees: $e');
    }
  }

  // CHECK - Email exists
  Future<bool> emailExists(String email) async {
    try {
      final response = await _supabase
          .from('employees')
          .select('id')
          .eq('email', email)
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  // CHECK - Contact exists
  Future<bool> contactExists(String contact) async {
    try {
      final response = await _supabase
          .from('employees')
          .select('id')
          .eq('contact', contact)
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  // ===== APP ASSIGNMENT METHODS =====

  // ASSIGN - Assign app to employee
  Future<EmployeeAppAssignment> assignAppToEmployee({
    required int employeeId,
    required int appId,
    required String assignedBy,
  }) async {
    try {
      // Check if already assigned
      final existing = await _supabase
          .from('employee_app_assignments')
          .select('id')
          .eq('employee_id', employeeId)
          .eq('app_id', appId)
          .maybeSingle();

      if (existing != null) {
        throw Exception('App already assigned to this employee');
      }

      final response = await _supabase
          .from('employee_app_assignments')
          .insert({
        'employee_id': employeeId,
        'app_id': appId,
        'assigned_by': assignedBy,
      })
          .select()
          .single();

      return EmployeeAppAssignment.fromJson(response);
    } catch (e) {
      throw Exception('Failed to assign app: $e');
    }
  }

  // REMOVE - Remove app assignment from employee
  Future<void> removeAppFromEmployee({
    required int employeeId,
    required int appId,
  }) async {
    try {
      await _supabase
          .from('employee_app_assignments')
          .delete()
          .eq('employee_id', employeeId)
          .eq('app_id', appId);
    } catch (e) {
      throw Exception('Failed to remove app assignment: $e');
    }
  }

  // GET - Get all apps assigned to employee
  Future<List<EmployeeAppAssignment>> getEmployeeAssignedApps(int employeeId) async {
    try {
      final response = await _supabase
          .from('employee_app_assignments')
          .select('*, inventory_apps(id, app_name)')
          .eq('employee_id', employeeId)
          .order('assigned_date', ascending: false);

      return (response as List).map((item) {
        final data = item as Map<String, dynamic>;
        final appData = data['inventory_apps'] as Map<String, dynamic>?;
        return EmployeeAppAssignment(
          id: data['id'] as int,
          employeeId: data['employee_id'] as int,
          appId: data['app_id'] as int,
          appName: appData?['app_name'] as String?,
          assignedDate: DateTime.parse(data['assigned_date'] as String),
          assignedBy: data['assigned_by'] as String?,
          createdAt: DateTime.parse(data['created_at'] as String),
          updatedAt: DateTime.parse(data['updated_at'] as String),
        );
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch assigned apps: $e');
    }
  }

  // GET - Get all unassigned apps for employee
  Future<List<Map<String, dynamic>>> getUnassignedAppsForEmployee(int employeeId) async {
    try {
      // Get all apps
      final allApps = await _supabase
          .from('inventory_apps')
          .select('id, app_name')
          .order('app_name', ascending: true);

      // Get assigned apps for this employee
      final assignedApps = await _supabase
          .from('employee_app_assignments')
          .select('app_id')
          .eq('employee_id', employeeId);

      final assignedAppIds = (assignedApps as List)
          .map((item) => (item as Map<String, dynamic>)['app_id'] as int)
          .toList();

      // Filter out assigned apps
      final unassigned = (allApps as List)
          .where((app) => !assignedAppIds.contains((app as Map<String, dynamic>)['id']))
          .toList();

      return List<Map<String, dynamic>>.from(unassigned);
    } catch (e) {
      throw Exception('Failed to fetch unassigned apps: $e');
    }
  }

  // GET - Get all apps (for dropdown)
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

  // GET - Count apps assigned to employee
  Future<int> getAssignedAppCount(int employeeId) async {
    try {
      final response = await _supabase
          .from('employee_app_assignments')
          .select('id')
          .eq('employee_id', employeeId);

      return (response as List).length;
    } catch (e) {
      throw Exception('Failed to count assigned apps: $e');
    }
  }
}