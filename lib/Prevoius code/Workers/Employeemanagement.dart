import 'package:flutter/material.dart';

import '../Login/authservice.dart';
import 'EmployeeAppAssignment.dart';
import 'Employeeservice.dart';
import 'employemodel.dart';


class EmployeeManagement extends StatefulWidget {
  const EmployeeManagement({super.key});

  @override
  State<EmployeeManagement> createState() => _EmployeeManagementState();
}

class _EmployeeManagementState extends State<EmployeeManagement> {
  final employeeService = EmployeeService();
  final authService = AuthService();
  List<Employee> employees = [];
  Map<int, List<EmployeeAppAssignment>> employeeApps = {};
  Map<int, int> appCounts = {};
  bool isLoading = true;
  int activeCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final employeesList = await employeeService.getAllEmployees();
      final active = await employeeService.getActiveEmployeeCount();

      Map<int, List<EmployeeAppAssignment>> appAssignments = {};
      Map<int, int> counts = {};

      for (var employee in employeesList) {
        final apps = await employeeService.getEmployeeAssignedApps(employee.id);
        appAssignments[employee.id] = apps;
        counts[employee.id] = apps.length;
      }

      setState(() {
        employees = employeesList;
        employeeApps = appAssignments;
        appCounts = counts;
        activeCount = active;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showRegisterDialog() {
    showDialog(context: context, builder: (_) => RegisterEmployeeDialog(employeeService: employeeService, onRegister: (employee) async {
      try {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registering employee...')));

        await employeeService.registerEmployee(
          email: employee['email'],
          password: employee['password'],
          name: employee['name'],
          contact: employee['contact'],
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Employee registered! Logging out...')));

          await Future.delayed(const Duration(seconds: 1));
          await employeeService.logoutEmployee();

          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logging in admin account...')));
          await Future.delayed(const Duration(milliseconds: 500));

          try {
            await authService.login('alibukhar786@gmail.com', '123456789');
            _loadData();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Admin logged in successfully')));
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error logging in admin: $e')));
            }
          }
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }));
  }

  void _showAppAssignmentDialog(Employee employee) {
    showDialog(context: context, builder: (_) => AppAssignmentDialog(
      employee: employee,
      employeeService: employeeService,
      currentApps: employeeApps[employee.id] ?? [],
      onAssign: (appId) async {
        try {
          final user = authService.getCurrentUser();
          await employeeService.assignAppToEmployee(
            employeeId: employee.id,
            appId: appId,
            assignedBy: user?.email ?? 'Unknown',
          );
          _loadData();
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('App assigned successfully')));
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      },
    ));
  }

  void _showEditDialog(Employee employee) {
    showDialog(context: context, builder: (_) => EditEmployeeDialog(employee: employee, onUpdate: (updated) async {
      try {
        await employeeService.updateEmployee(id: employee.id, name: updated['name'], contact: updated['contact']);
        _loadData();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Employee updated successfully')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }));
  }

  void _removeAppAssignment(Employee employee, EmployeeAppAssignment app) async {
    try {
      await employeeService.removeAppFromEmployee(
        employeeId: employee.id,
        appId: app.appId,
      );
      _loadData();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('App assignment removed')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _toggleEmployeeStatus(Employee employee) async {
    try {
      if (employee.isActive) {
        await employeeService.deactivateEmployee(employee.id);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Employee deactivated')));
      } else {
        await employeeService.activateEmployee(employee.id);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Employee activated')));
      }
      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Employees', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  ElevatedButton.icon(onPressed: _showRegisterDialog, icon: const Icon(Icons.add, size: 18), label: const Text('Register Employee'), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[600], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8))),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(child: _buildSummaryCard(title: 'Total Employees', value: employees.length.toString(), icon: Icons.people, color: Colors.blue)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildSummaryCard(title: 'Active Employees', value: activeCount.toString(), icon: Icons.check_circle, color: Colors.green)),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Employees Table', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  employees.isEmpty
                      ? Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 40), child: Text('No employees yet', style: TextStyle(fontSize: 16, color: Colors.grey[600]))))
                      : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                        boxShadow: [BoxShadow(color: Colors.grey[200]!, blurRadius: 4, offset: const Offset(0, 2))],
                      ),
                      child: DataTable(
                        headingRowColor: MaterialStateColor.resolveWith((_) => Colors.blue[100]!),
                        dataRowHeight: 70,
                        columns: const [
                          DataColumn(label: SizedBox(width: 140, child: Text('Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
                          DataColumn(label: SizedBox(width: 160, child: Text('Email', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
                          DataColumn(label: SizedBox(width: 120, child: Text('Contact', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
                          DataColumn(label: SizedBox(width: 100, child: Text('Apps', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center))),
                          DataColumn(label: SizedBox(width: 110, child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center))),
                          DataColumn(label: SizedBox(width: 140, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center))),
                        ],
                        rows: employees.map((employee) {
                          final appCount = appCounts[employee.id] ?? 0;
                          return DataRow(cells: [
                            DataCell(SizedBox(width: 140, child: Text(employee.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis))),
                            DataCell(SizedBox(width: 160, child: Text(employee.email, style: TextStyle(fontSize: 11, color: Colors.grey[700]), overflow: TextOverflow.ellipsis))),
                            DataCell(SizedBox(width: 120, child: Text(employee.contact, style: TextStyle(fontSize: 11, color: Colors.grey[700])))),
                            DataCell(SizedBox(width: 100, child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: appCount > 0 ? Colors.purple[100] : Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                appCount.toString(),
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: appCount > 0 ? Colors.purple[700] : Colors.grey[600]),
                                textAlign: TextAlign.center,
                              ),
                            ))),
                            DataCell(SizedBox(width: 110, child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: employee.isActive ? Colors.green[100] : Colors.red[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                employee.isActive ? 'Active' : 'Inactive',
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: employee.isActive ? Colors.green[700] : Colors.red[700]),
                                textAlign: TextAlign.center,
                              ),
                            ))),
                            DataCell(SizedBox(width: 140, child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                              IconButton(icon: Icon(Icons.edit, color: Colors.orange[600], size: 18), onPressed: () => _showEditDialog(employee), tooltip: 'Edit'),
                              IconButton(icon: Icon(Icons.apps, color: Colors.purple[600], size: 18), onPressed: () => _showAppAssignmentDialog(employee), tooltip: 'Assign Apps'),
                              PopupMenuButton(icon: Icon(Icons.more_vert, color: Colors.blue[600], size: 18), itemBuilder: (context) => [
                                PopupMenuItem(
                                  child: Row(children: [
                                    Icon(employee.isActive ? Icons.block : Icons.check_circle, size: 18, color: employee.isActive ? Colors.red[600] : Colors.green[600]),
                                    const SizedBox(width: 8),
                                    Text(employee.isActive ? 'Deactivate' : 'Activate', style: TextStyle(color: employee.isActive ? Colors.red[600] : Colors.green[600])),
                                  ]),
                                  onTap: () => _toggleEmployeeStatus(employee),
                                ),
                                PopupMenuItem(child: const Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))]), onTap: () async {
                                  if (await _confirmDelete()) {
                                    try {
                                      await employeeService.deleteEmployee(employee.id);
                                      _loadData();
                                    } catch (e) {
                                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                                    }
                                  }
                                }),
                              ]),
                            ]))),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // App Assignments Table
            if (employees.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('App Assignments', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                          boxShadow: [BoxShadow(color: Colors.grey[200]!, blurRadius: 4, offset: const Offset(0, 2))],
                        ),
                        child: DataTable(
                          headingRowColor: MaterialStateColor.resolveWith((_) => Colors.purple[100]!),
                          dataRowHeight: 65,
                          columns: const [
                            DataColumn(label: SizedBox(width: 140, child: Text('Employee', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
                            DataColumn(label: SizedBox(width: 150, child: Text('App Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
                            DataColumn(label: SizedBox(width: 130, child: Text('Assigned Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center))),
                            DataColumn(label: SizedBox(width: 140, child: Text('Assigned By', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
                            DataColumn(label: SizedBox(width: 100, child: Text('Action', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center))),
                          ],
                          rows: _buildAppAssignmentRows(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  List<DataRow> _buildAppAssignmentRows() {
    List<DataRow> rows = [];
    for (var employee in employees) {
      final apps = employeeApps[employee.id] ?? [];
      for (var app in apps) {
        rows.add(
          DataRow(cells: [
            DataCell(SizedBox(width: 140, child: Text(employee.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), overflow: TextOverflow.ellipsis))),
            DataCell(SizedBox(width: 150, child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.purple[50], borderRadius: BorderRadius.circular(4)), child: Text(app.appName ?? 'Unknown', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Colors.purple[700]), overflow: TextOverflow.ellipsis)))),
            DataCell(SizedBox(width: 130, child: Text(app.assignedDate.toString().split(' ')[0], style: TextStyle(fontSize: 10, color: Colors.grey[600]), textAlign: TextAlign.center))),
            DataCell(SizedBox(width: 140, child: Text(app.assignedBy ?? 'Unknown', style: TextStyle(fontSize: 10, color: Colors.grey[600]), overflow: TextOverflow.ellipsis))),
            DataCell(SizedBox(width: 100, child: IconButton(icon: Icon(Icons.delete, color: Colors.red[600], size: 18), onPressed: () => _removeAppAssignment(employee, app), tooltip: 'Remove Assignment'))),
          ]),
        );
      }
    }
    return rows;
  }

  Widget _buildSummaryCard({required String title, required String value, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.grey[300]!, blurRadius: 8, offset: const Offset(0, 2))], border: Border(left: BorderSide(color: color, width: 4))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, color: color, size: 24), const SizedBox(width: 8), Expanded(child: Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)))]),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Future<bool> _confirmDelete() async {
    final result = await showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Delete Employee'), content: const Text('Are you sure?'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red)))]));
    return result ?? false;
  }
}

// REGISTER EMPLOYEE DIALOG
class RegisterEmployeeDialog extends StatefulWidget {
  final EmployeeService employeeService;
  final Function(Map<String, dynamic>) onRegister;
  const RegisterEmployeeDialog({super.key, required this.employeeService, required this.onRegister});
  @override
  State<RegisterEmployeeDialog> createState() => _RegisterEmployeeDialogState();
}

class _RegisterEmployeeDialogState extends State<RegisterEmployeeDialog> {
  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final nameController = TextEditingController();
  final contactController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    emailController.dispose();
    nameController.dispose();
    contactController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Register New Employee'),
      content: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: nameController, decoration: InputDecoration(labelText: 'Full Name', prefixIcon: const Icon(Icons.person, color: Colors.blue), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), validator: (v) => v?.isEmpty ?? true ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(controller: emailController, decoration: InputDecoration(labelText: 'Email', prefixIcon: const Icon(Icons.email, color: Colors.blue), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), keyboardType: TextInputType.emailAddress, validator: (v) { if (v?.isEmpty ?? true) return 'Required'; if (!v!.contains('@')) return 'Invalid email'; return null; }),
              const SizedBox(height: 12),
              TextFormField(controller: contactController, decoration: InputDecoration(labelText: 'Contact Number', prefixIcon: const Icon(Icons.phone, color: Colors.blue), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), keyboardType: TextInputType.phone, validator: (v) => v?.isEmpty ?? true ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(controller: passwordController, decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock, color: Colors.blue), suffixIcon: IconButton(icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _obscurePassword = !_obscurePassword)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), obscureText: _obscurePassword, validator: (v) { if (v?.isEmpty ?? true) return 'Required'; if ((v?.length ?? 0) < 6) return 'Min 6 characters'; return null; }),
              const SizedBox(height: 12),
              TextFormField(controller: confirmPasswordController, decoration: InputDecoration(labelText: 'Confirm Password', prefixIcon: const Icon(Icons.lock, color: Colors.blue), suffixIcon: IconButton(icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), obscureText: _obscureConfirm, validator: (v) { if (v?.isEmpty ?? true) return 'Required'; if (v != passwordController.text) return 'Passwords do not match'; return null; }),
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), ElevatedButton(onPressed: () { if (formKey.currentState!.validate()) { widget.onRegister({'email': emailController.text, 'name': nameController.text, 'contact': contactController.text, 'password': passwordController.text}); Navigator.pop(context); } }, style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[600]), child: const Text('Register', style: TextStyle(color: Colors.white)))],
    );
  }
}

// EDIT EMPLOYEE DIALOG
class EditEmployeeDialog extends StatefulWidget {
  final Employee employee;
  final Function(Map<String, dynamic>) onUpdate;
  const EditEmployeeDialog({super.key, required this.employee, required this.onUpdate});
  @override
  State<EditEmployeeDialog> createState() => _EditEmployeeDialogState();
}

class _EditEmployeeDialogState extends State<EditEmployeeDialog> {
  final formKey = GlobalKey<FormState>();
  late TextEditingController nameController;
  late TextEditingController contactController;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.employee.name);
    contactController = TextEditingController(text: widget.employee.contact);
  }

  @override
  void dispose() {
    nameController.dispose();
    contactController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Employee'),
      content: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: nameController, decoration: InputDecoration(labelText: 'Full Name', prefixIcon: const Icon(Icons.person, color: Colors.blue), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), validator: (v) => v?.isEmpty ?? true ? 'Required' : null),
              const SizedBox(height: 12),
              Text('Email: ${widget.employee.email}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 12),
              TextFormField(controller: contactController, decoration: InputDecoration(labelText: 'Contact Number', prefixIcon: const Icon(Icons.phone, color: Colors.blue), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), keyboardType: TextInputType.phone, validator: (v) => v?.isEmpty ?? true ? 'Required' : null),
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), ElevatedButton(onPressed: () { if (formKey.currentState!.validate()) { widget.onUpdate({'name': nameController.text, 'contact': contactController.text}); Navigator.pop(context); } }, style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[600]), child: const Text('Update', style: TextStyle(color: Colors.white)))],
    );
  }
}

// APP ASSIGNMENT DIALOG
class AppAssignmentDialog extends StatefulWidget {
  final Employee employee;
  final EmployeeService employeeService;
  final List<EmployeeAppAssignment> currentApps;
  final Function(int) onAssign;
  const AppAssignmentDialog({super.key, required this.employee, required this.employeeService, required this.currentApps, required this.onAssign});
  @override
  State<AppAssignmentDialog> createState() => _AppAssignmentDialogState();
}

class _AppAssignmentDialogState extends State<AppAssignmentDialog> {
  int? selectedAppId;
  List<Map<String, dynamic>> unassignedApps = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUnassignedApps();
  }

  Future<void> _loadUnassignedApps() async {
    try {
      final apps = await widget.employeeService.getUnassignedAppsForEmployee(widget.employee.id);
      setState(() {
        unassignedApps = apps;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Assign Apps to Employee'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Employee: ${widget.employee.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 16),
            const Text('Currently Assigned Apps:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 8),
            if (widget.currentApps.isEmpty)
              Text('No apps assigned', style: TextStyle(fontSize: 11, color: Colors.grey[600]))
            else
              Wrap(spacing: 8, runSpacing: 8, children: widget.currentApps.map((app) {
                return Chip(
                  label: Text(app.appName ?? 'App ${app.appId}', style: const TextStyle(fontSize: 11)),
                  backgroundColor: Colors.blue[100],
                  labelStyle: TextStyle(color: Colors.blue[700]),
                );
              }).toList()),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            const Text('Assign New App:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 12),
            if (isLoading)
              const CircularProgressIndicator()
            else if (unassignedApps.isEmpty)
              Text('All apps already assigned', style: TextStyle(fontSize: 11, color: Colors.grey[600]))
            else
              DropdownButtonFormField<int>(
                value: selectedAppId,
                decoration: InputDecoration(
                  labelText: 'Select App',
                  prefixIcon: const Icon(Icons.apps, color: Colors.blue),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: unassignedApps.map((app) => DropdownMenuItem(
                  value: app['id'] as int,
                  child: Text(app['app_name'] as String),
                )).toList(),
                onChanged: (value) => setState(() => selectedAppId = value),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: unassignedApps.isEmpty || selectedAppId == null
              ? null
              : () {
            widget.onAssign(selectedAppId!);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.purple[600]),
          child: const Text('Assign', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}