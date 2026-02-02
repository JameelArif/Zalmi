import 'package:flutter/material.dart';

import '../Workers/employemodel.dart';


class EmployeeMySalesPage extends StatefulWidget {
  final Employee employee;
  const EmployeeMySalesPage({super.key, required this.employee});

  @override
  State<EmployeeMySalesPage> createState() => _EmployeeMySalesPageState();
}

class _EmployeeMySalesPageState extends State<EmployeeMySalesPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('My Sales'),
        backgroundColor: Colors.blue[600],
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'My Sales',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Coming Soon',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}