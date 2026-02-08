import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'Employeeservice.dart';
import 'employeperfomrcepage.dart';

class EmployeeManagement extends StatefulWidget {
  const EmployeeManagement({super.key});

  @override
  State<EmployeeManagement> createState() => _EmployeeManagementState();
}

class _EmployeeManagementState extends State<EmployeeManagement> {
  final _employeeService = EmployeeService();

  List<EmployeeModel> _employees = [];
  Map<String, dynamic> _statistics = {};
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _lastLoadError;
  int? _currentAdminId;
  String? _currentAuthUserId;

  // Form controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _contactController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _lastLoadError = null;
      });

      // On web, give the session a moment to attach (avoids first request without JWT).
      if (kIsWeb) {
        await Future<void>.delayed(const Duration(milliseconds: 150));
        if (!mounted) return;
      }

      var employees = await _employeeService.getEmployees();
      var stats = await _employeeService.getEmployeeStatistics();
      var adminId = await _employeeService.getCurrentAdminIdOrNull();

      // One retry on web if we got 0 employees but have valid admin (session may have attached late).
      if (kIsWeb && employees.isEmpty && adminId != null) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
        if (!mounted) return;
        employees = await _employeeService.getEmployees();
        stats = await _employeeService.getEmployeeStatistics();
      }

      if (!mounted) return;
      setState(() {
        _employees = employees;
        _statistics = stats;
        _currentAdminId = adminId;
        _currentAuthUserId = _employeeService.getCurrentAuthUserId();
        _isLoading = false;
      });
    } catch (e) {
      final msg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      if (mounted) {
        _showSnackBar(
          msg.contains('Not authenticated') || msg.contains('No admin or employee')
              ? 'Could not load employees. $msg'
              : 'Error loading employees: $msg',
          Colors.red,
        );
      }
      if (mounted) {
        setState(() {
          _employees = [];
          _statistics = {};
          _lastLoadError = msg;
          _currentAdminId = null;
          _currentAuthUserId = null;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _registerEmployee() async {
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _contactController.text.isEmpty) {
      _showSnackBar('Please fill all fields', Colors.red);
      return;
    }

    try {
      setState(() => _isProcessing = true);

      await _employeeService.registerEmployee(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        contact: _contactController.text.trim(),
      );

      _nameController.clear();
      _emailController.clear();
      _passwordController.clear();
      _contactController.clear();

      await _loadData();

      if (mounted) {
        _showSnackBar('Employee registered successfully!', Colors.green);
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', Colors.red);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _deleteEmployee(int id) async {
    try {
      await _employeeService.deleteEmployee(id);
      await _loadData();
      if (mounted) {
        _showSnackBar('Employee deleted!', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', Colors.red);
    }
  }

  Future<void> _toggleEmployeeStatus(EmployeeModel employee) async {
    try {
      await _employeeService.toggleEmployeeStatus(employee);
      await _loadData();
      if (mounted) {
        final newStatus = employee.status == 'active' ? 'inactive' : 'active';
        _showSnackBar('Employee status changed to $newStatus!', Colors.green);
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}', Colors.red);
    }
  }

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showAddEmployeeDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Register Employee',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close, color: Colors.black54),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildTextField(
                  controller: _nameController,
                  label: 'Full Name',
                  icon: Icons.person,
                  color: Colors.blue,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _emailController,
                  label: 'Email Address',
                  icon: Icons.email,
                  color: Colors.green,
                  inputType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _passwordController,
                  label: 'Password (min 6 chars)',
                  icon: Icons.lock,
                  color: Colors.orange,
                  isPassword: true,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _contactController,
                  label: 'Contact Number',
                  icon: Icons.phone,
                  color: Colors.purple,
                  inputType: TextInputType.phone,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _registerEmployee,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      disabledBackgroundColor: Colors.grey,
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                        : const Text(
                      'Register Employee',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.blue,
        elevation: 0,
        title: const Text('Employee Management'),
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
        ),
      )
          : Column(
        children: [
          // Statistics Header
          Container(
            width: MediaQuery.of(context).size.width * 0.9,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1976D2), Color(0xFF1565C0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Employees',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _statsCard(
                      label: 'Total',
                      value: (_statistics['totalEmployees'] ?? 0)
                          .toString(),
                      icon: Icons.people,
                      color: Colors.lightBlue,
                    ),
                    _statsCard(
                      label: 'Active',
                      value:
                      (_statistics['activeEmployees'] ?? 0).toString(),
                      icon: Icons.check_circle,
                      color: Colors.lightGreen,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _statsCard(
                      label: 'Inactive',
                      value: (_statistics['inactiveEmployees'] ?? 0)
                          .toString(),
                      icon: Icons.block,
                      color: Colors.red,
                    ),
                    _statsCard(
                      label: 'Apps Assigned',
                      value: (_statistics['totalAppsAssigned'] ?? 0)
                          .toString(),
                      icon: Icons.apps,
                      color: Colors.amber,
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Employees List
          Expanded(
            child: _employees.isEmpty
                ? Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people,
                        size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    const Text(
                      'No employees yet',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_lastLoadError != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          _lastLoadError!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.red.shade800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                    if (_currentAdminId != null && _lastLoadError == null) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Not CORS — requests return 200 OK; the API is returning empty data.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Your admin ID: $_currentAdminId',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontFamily: 'monospace',
                        ),
                      ),
                      if (_currentAuthUserId != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Auth user ID: ${_currentAuthUserId!.length > 20 ? '${_currentAuthUserId!.substring(0, 20)}...' : _currentAuthUserId}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'In Supabase: Table admin must have a row with auth_id = this Auth user ID and id = $_currentAdminId. '
                          'Table employees must have rows with admin_id = $_currentAdminId.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ] else ...[
                        Text(
                          'In Supabase, employees must have admin_id = $_currentAdminId.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                    const SizedBox(height: 20),
                    Text(
                      'Use the same admin account as on your phone, then tap Retry.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _isLoading ? null : _loadData,
                      icon: const Icon(Icons.refresh, size: 20),
                      label: const Text('Retry'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              itemCount: _employees.length,
              itemBuilder: (context, index) {
                final employee = _employees[index];
                final isActive = employee.status == 'active';

                return _EmployeeCard(
                  employee: employee,
                  isActive: isActive,
                  onDetails: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            EmployeeDetailsPage(
                              employee: employee,
                              onRefresh: _loadData,
                            ),
                      ),
                    );
                  },
                  onToggleStatus: () {
                    _toggleEmployeeStatus(employee);
                  },
                  onDelete: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Employee'),
                        content: const Text('Are you sure?'),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              _deleteEmployee(employee.id);
                              Navigator.pop(context);
                            },
                            child: const Text(
                              'Delete',
                              style: TextStyle(
                                  color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddEmployeeDialog,
        backgroundColor: Colors.blue,
        elevation: 4,
        child: const Icon(Icons.person_add, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _statsCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color color,
    bool isPassword = false,
    TextInputType inputType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: inputType,
      obscureText: isPassword,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: color),
        prefixIcon: Icon(icon, color: color),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: 2),
        ),
      ),
    );
  }
}

// ============================================
// EMPLOYEE DETAILS PAGE WITH APP ASSIGNMENT
// ============================================
class EmployeeDetailsPage extends StatefulWidget {
  final EmployeeModel employee;
  final VoidCallback onRefresh;

  const EmployeeDetailsPage({
    super.key,
    required this.employee,
    required this.onRefresh,
  });

  @override
  State<EmployeeDetailsPage> createState() => _EmployeeDetailsPageState();
}

class _EmployeeDetailsPageState extends State<EmployeeDetailsPage> {
  final _employeeService = EmployeeService();
  List<EmployeeAppModel> _assignedApps = [];
  List<ApplicationModel> _availableApps = [];
  bool _isLoading = true;
  int? _selectedAppId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);

      final apps = await _employeeService.getEmployeeApps(widget.employee.id);
      final availableApps = await _getAvailableApps();

      setState(() {
        _assignedApps = apps;
        _availableApps = availableApps;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<List<ApplicationModel>> _getAvailableApps() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.from('applications').select();

      return (response as List)
          .map((item) => ApplicationModel(
        id: item['id'] as int,
        name: item['application_name'] as String,
      ))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> _assignApp(int appId, String appName) async {
    try {
      await _employeeService.assignAppToEmployee(
        employeeId: widget.employee.id,
        applicationId: appId,
        applicationName: appName,
      );

      await _loadData();
      widget.onRefresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('App assigned successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeApp(int employeeAppId) async {
    try {
      await _employeeService.removeAppFromEmployee(employeeAppId);
      await _loadData();
      widget.onRefresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('App removed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAssignAppDialog() {
    final unassignedApps = _availableApps
        .where((app) =>
    !_assignedApps.any((assigned) => assigned.applicationId == app.id))
        .toList();

    if (unassignedApps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All available apps are already assigned!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Assign Application',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close, color: Colors.black54),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                StatefulBuilder(
                  builder: (context, setState) => Column(
                    children: [
                      DropdownButtonFormField<int>(
                        decoration: InputDecoration(
                          labelText: 'Select Application',
                          labelStyle: const TextStyle(color: Colors.blue),
                          prefixIcon: const Icon(Icons.apps, color: Colors.blue),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.blue),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                        ),
                        initialValue: _selectedAppId,
                        isExpanded: true,
                        onChanged: (value) {
                          setState(() => _selectedAppId = value);
                        },
                        items: unassignedApps
                            .map((app) => DropdownMenuItem<int>(
                          value: app.id,
                          child: Text(
                            app.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                            .toList(),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey[300],
                                foregroundColor: Colors.black,
                                padding:
                                const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _selectedAppId != null
                                  ? () {
                                final selectedApp = _availableApps
                                    .firstWhere((app) =>
                                app.id == _selectedAppId);
                                _assignApp(_selectedAppId!,
                                    selectedApp.name);
                                Navigator.pop(context);
                              }
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding:
                                const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                disabledBackgroundColor: Colors.grey,
                              ),
                              child: const Text('Assign'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.blue,
        elevation: 0,
        title: Text('${widget.employee.name} Details'),
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Employee Info Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.person,
                              color: Colors.blue, size: 32),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.employee.name,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.employee.email,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    _infoRow('Contact', widget.employee.contact),
                    const SizedBox(height: 12),
                    _infoRow('Email', widget.employee.email),
                    const SizedBox(height: 12),
                    _infoRow(
                      'Joined',
                      DateFormat('MMM dd, yyyy')
                          .format(widget.employee.createdAt),
                    ),
                    const SizedBox(height: 12),
                    _infoRow(
                      'Status',
                      widget.employee.status.toUpperCase(),
                      statusColor: widget.employee.status == 'active'
                          ? Colors.green
                          : Colors.red,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Assigned Apps Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Assigned Applications',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _showAssignAppDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add App'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EmployeePerformancePage(employee: widget.employee),
                      ),
                    );
                  },
                  icon: const Icon(Icons.analytics),
                  label: const Text('Performance'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_assignedApps.isEmpty)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.apps,
                        size: 48, color: Colors.grey[300]),
                    const SizedBox(height: 12),
                    const Text(
                      'No apps assigned yet',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _assignedApps.length,
                itemBuilder: (context, index) {
                  final app = _assignedApps[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.blue[200]!),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.blue[50],
                                        borderRadius:
                                        BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.apps,
                                        color: Colors.blue,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        app.applicationName,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Assigned: ${DateFormat('MMM dd, yyyy').format(app.assignedDate)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Remove App'),
                                  content: const Text(
                                      'Are you sure you want to remove this app from this employee?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        _removeApp(app.id);
                                        Navigator.pop(context);
                                      },
                                      child: const Text(
                                        'Remove',
                                        style: TextStyle(
                                            color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                            icon: const Icon(Icons.delete,
                                color: Colors.red, size: 20),
                            tooltip: 'Remove app',
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color? statusColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: statusColor ?? Colors.black,
          ),
        ),
      ],
    );
  }
}

// Application Model
class ApplicationModel {
  final int id;
  final String name;

  ApplicationModel({required this.id, required this.name});
}

// ============================================
// EMPLOYEE CARD WIDGET
// ============================================
class _EmployeeCard extends StatefulWidget {
  final EmployeeModel employee;
  final bool isActive;
  final VoidCallback onDetails;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;

  const _EmployeeCard({
    required this.employee,
    required this.isActive,
    required this.onDetails,
    required this.onToggleStatus,
    required this.onDelete,
  });

  @override
  State<_EmployeeCard> createState() => _EmployeeCardState();
}

class _EmployeeCardState extends State<_EmployeeCard> {
  final _employeeService = EmployeeService();
  List<EmployeeAppModel> _assignedApps = [];
  bool _isLoadingApps = true;

  @override
  void initState() {
    super.initState();
    _loadAssignedApps();
  }

  Future<void> _loadAssignedApps() async {
    try {
      final apps = await _employeeService.getEmployeeApps(widget.employee.id);
      setState(() {
        _assignedApps = apps;
        _isLoadingApps = false;
      });
    } catch (e) {
      setState(() => _isLoadingApps = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border(
            left: BorderSide(
              color: widget.isActive ? Colors.green[700]! : Colors.red[700]!,
              width: 5,
            ),
          ),
          color: Colors.white,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Employee Basic Info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.employee.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.employee.email,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.employee.contact,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: widget.isActive
                          ? Colors.green[50]
                          : Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: widget.isActive
                            ? Colors.green[300]!
                            : Colors.red[300]!,
                      ),
                    ),
                    child: Text(
                      widget.employee.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: widget.isActive
                            ? Colors.green[700]
                            : Colors.red[700],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Assigned Apps Section
              Row(
                children: [
                  Icon(Icons.apps, size: 18, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Text(
                    'Assigned Apps',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _isLoadingApps ? '...' : _assignedApps.length.toString(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Apps List or Loading
              if (_isLoadingApps)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                    height: 20,
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      backgroundColor: Colors.grey[300],
                      valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.blue[400]!),
                    ),
                  ),
                )
              else if (_assignedApps.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No apps assigned',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _assignedApps.map((app) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.blue[300]!,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle,
                              size: 14, color: Colors.blue[600]),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              app.applicationName,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue[700],
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Joined',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('MMM dd, yyyy')
                              .format(widget.employee.createdAt),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.isActive)
                    ElevatedButton.icon(
                      onPressed: widget.onDetails,
                      icon: const Icon(Icons.info_outline, size: 18),
                      label: const Text('Details'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                    ),
                  const SizedBox(width: 8),
                  PopupMenuButton(
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        onTap: widget.onToggleStatus,
                        child: Row(
                          children: [
                            Icon(
                              widget.isActive
                                  ? Icons.block
                                  : Icons.check_circle,
                              color: widget.isActive
                                  ? Colors.red
                                  : Colors.green,
                            ),
                            const SizedBox(width: 8),
                            Text(
                                widget.isActive ? 'Deactivate' : 'Activate'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        onTap: widget.onDelete,
                        child: const Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}