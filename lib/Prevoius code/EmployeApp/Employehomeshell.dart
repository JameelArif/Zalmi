import 'package:flutter/material.dart';

import '../Workers/Employeeservice.dart';
import '../Workers/employemodel.dart';
import 'Employeebonuses.dart';
import 'Employeecredits.dart';
import 'Employeecustomers.dart';
import 'Employeemysales.dart';
import 'Employeequicksales.dart';
import 'Employelogin.dart';


class EmployeeHomeShell extends StatefulWidget {
  final Employee employee;
  const EmployeeHomeShell({super.key, required this.employee});

  @override
  State<EmployeeHomeShell> createState() => _EmployeeHomeShellState();
}

class _EmployeeHomeShellState extends State<EmployeeHomeShell> {
  final _employeeService = EmployeeService();
  late Employee currentEmployee;
  int _selectedIndex = 0;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    currentEmployee = widget.employee;
  }

  Future<void> _handleLogout() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await _employeeService.logoutEmployee();
                  if (mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const EmployeeLoginPage()),
                          (route) => false,
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Logout failed: $e')),
                    );
                  }
                }
              },
              child: const Text('Logout', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _showProfileDialog() {
    showDialog(
      context: context,
      builder: (_) => EmployeeProfileDialog(employee: currentEmployee),
    );
  }

  final List<String> _menuItems = [
    'Dashboard',
    'Customers',
    'My Sales',
    'Credits',
    'Bonuses',
    'Quick Sales',
  ];

  final List<IconData> _menuIcons = [
    Icons.dashboard,
    Icons.people,
    Icons.shopping_cart,
    Icons.credit_card,
    Icons.card_giftcard,
    Icons.flash_on,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(child: Text('Employee Portal')),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: _showProfileDialog,
            tooltip: 'Profile',
          ),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (BuildContext context) => [
              PopupMenuItem(
                child: const Row(
                  children: [
                    Icon(Icons.person, size: 20, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Profile'),
                  ],
                ),
                onTap: () {
                  Future.delayed(const Duration(milliseconds: 100), _showProfileDialog);
                },
              ),
              PopupMenuItem(
                onTap: _handleLogout,
                child: const Row(
                  children: [
                    Icon(Icons.logout, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Logout', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue[600],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.white,
                    child: Text(
                      currentEmployee.name[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[600],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    currentEmployee.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    currentEmployee.email,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _menuItems.length,
                itemBuilder: (context, index) {
                  final isSelected = _selectedIndex == index;
                  return Container(
                    color: isSelected ? Colors.blue[100] : Colors.transparent,
                    child: ListTile(
                      leading: Icon(
                        _menuIcons[index],
                        color: isSelected ? Colors.blue[600] : Colors.grey[600],
                      ),
                      title: Text(
                        _menuItems[index],
                        style: TextStyle(
                          color: isSelected ? Colors.blue[600] : Colors.black87,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                      onTap: () {
                        setState(() => _selectedIndex = index);
                        Navigator.pop(context);
                      },
                    ),
                  );
                },
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Logout',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
              onTap: () {
                Navigator.pop(context);
                _handleLogout();
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
      body: _buildPage(_selectedIndex),
    );
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return _buildDashboardScaffold();
      case 1:
        return EmployeeCustomersPage(employee: currentEmployee);
      case 2:
        return EmployeeMySalesPage(employee: currentEmployee);
      case 3:
        return EmployeeCreditsPage(employee: currentEmployee);
      case 4:
        return EmployeeBonusesPage(employee: currentEmployee);
      case 5:
        return EmployeeQuickSalesPage(employee: currentEmployee);
      default:
        return _buildDashboardScaffold();
    }
  }

  Widget _buildDashboardScaffold() {
    return Scaffold(
      backgroundColor: Colors.blue[600],
      body: _buildDashboard(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          setState(() => _selectedIndex = 5);
        },
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue[600],
        icon: const Icon(Icons.flash_on, size: 24),
        label: const Text('Quick Sales'),
      ),
    );
  }

  Widget _buildDashboard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[600],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome, ${currentEmployee.name}!',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            currentEmployee.email,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

// EMPLOYEE PROFILE DIALOG
class EmployeeProfileDialog extends StatelessWidget {
  final Employee employee;
  const EmployeeProfileDialog({super.key, required this.employee});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Employee Profile'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CircleAvatar(
                radius: 48,
                backgroundColor: Colors.blue[100],
                child: Text(
                  employee.name[0].toUpperCase(),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[600],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildProfileItem('Name', employee.name, Icons.person),
            _buildProfileItem('Email', employee.email, Icons.email),
            _buildProfileItem('Contact', employee.contact, Icons.phone),
            _buildProfileItem(
              'Status',
              employee.isActive ? 'Active' : 'Inactive',
              Icons.check_circle,
              statusColor: employee.isActive ? Colors.green : Colors.red,
            ),
            _buildProfileItem(
              'Joined',
              employee.hiredDate.toString().split(' ')[0],
              Icons.calendar_today,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildProfileItem(
      String label,
      String value,
      IconData icon, {
        Color? statusColor,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: statusColor ?? Colors.blue,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}