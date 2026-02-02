import 'package:flutter/material.dart';

import '../Workers/employemodel.dart';


class EmployeeCustomersPage extends StatefulWidget {
  final Employee employee;
  const EmployeeCustomersPage({super.key, required this.employee});

  @override
  State<EmployeeCustomersPage> createState() => _EmployeeCustomersPageState();
}

class _EmployeeCustomersPageState extends State<EmployeeCustomersPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('My Customers'),
        backgroundColor: Colors.blue[600],
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'My Customers',
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