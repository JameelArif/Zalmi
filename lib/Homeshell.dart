import 'package:flutter/material.dart';
import 'package:zalmiwholeseller/EXPENSIS/expenses_management_ui.dart';
import 'package:zalmiwholeseller/dashboard.dart';

import 'BankAccounts/Bankaccountmanagementui.dart';
import 'Customers/Customermanagementfrontend.dart';
import 'Employess/Employeemanagementui.dart';
import 'Inventory/Inventorymanagementfrontend.dart';

// ✅ Approvals screen
import 'Approvals/admin_sales_approval_screen.dart';

// ✅ Sales page
import 'Purchases/purchases.dart';
import 'Sales/admin_sales_page.dart';

// ✅ Purchases page (NEW)

import 'Prevoius code/Login/authservice.dart';
import 'Prevoius code/Login/loginscreen.dart';
import 'cutsomer_addition.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final _authService = AuthService();
  int _selectedIndex = 0;

  final List<String> _menuItems = [
    'Dashboard',
    'Inventory',
    'Profile',
    'Sales',
    'Approvals',
    'Employee',
    'Bank Accounts',
    'Expenses',
    'Profits',
    'Customers',
    'Purchases',
    'Gifting & Rewards',
  ];

  final List<IconData> _menuIcons = [
    Icons.dashboard,
    Icons.inventory_2,
    Icons.person,
    Icons.shopping_cart,
    Icons.verified_user,
    Icons.people,
    Icons.account_balance,
    Icons.money_off,
    Icons.calculate,
    Icons.groups,
    Icons.shopping_bag,
    Icons.card_giftcard,
  ];

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
                  await _authService.logout();
                  if (mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginPage()),
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

  @override
  Widget build(BuildContext context) {
    final currentUser = _authService.getCurrentUser();

    return Scaffold(
      appBar: AppBar(
        title: const Center(child: Text('Zalmi Reseller')),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.deepPurple),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.admin_panel_settings, size: 48, color: Colors.white),
                  const SizedBox(height: 8),
                  Text(
                    currentUser?.email ?? 'Admin',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
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
                    color: isSelected ? Colors.grey[300] : Colors.transparent,
                    child: ListTile(
                      leading: Icon(_menuIcons[index], color: Colors.blue[700]),
                      title: Text(
                        _menuItems[index],
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w500,
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
              leading: Icon(Icons.logout, color: Colors.blue[700]),
              title: const Text(
                'Logout',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
              ),
              onTap: () {
                Navigator.pop(context);
                _handleLogout();
              },
            ),
          ],
        ),
      ),

      // Build only the selected screen to avoid "too much load on main thread".
      // IndexedStack used to build all 12 screens at once, causing heavy main-thread work.
      body: _buildBody(),
    );
  }

  /// Returns only the currently selected screen to reduce main-thread load.
  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return const AdminDashboardPage();
      case 1:
        return const InventoryManagement();
      case 2:
        return const BulkCustomerImportPage();
      case 3:
        return const AdminSalesPage();
      case 4:
        return const AdminSalesApprovalScreen();
      case 5:
        return const EmployeeManagement();
      case 6:
        return const BankAccountManagement();
      case 7:
        return const ExpensesManagement();
      case 8:
        return _buildPlaceholder(_menuItems[8], _menuIcons[8]);
      case 9:
        return const CustomerManagement();
      case 10:
        return const AdminPurchasesPage();
      case 11:
        return _buildPlaceholder(_menuItems[11], _menuIcons[11]);
      default:
        return const AdminDashboardPage();
    }
  }

  Widget _buildPlaceholder(String title, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.deepPurple[200]),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Content coming soon', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        ],
      ),
    );
  }
}
