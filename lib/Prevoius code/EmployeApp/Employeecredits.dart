import 'package:flutter/material.dart';

import '../Workers/employemodel.dart';


class EmployeeCreditsPage extends StatefulWidget {
  final Employee employee;
  const EmployeeCreditsPage({super.key, required this.employee});

  @override
  State<EmployeeCreditsPage> createState() => _EmployeeCreditsPageState();
}

class _EmployeeCreditsPageState extends State<EmployeeCreditsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Credits'),
        backgroundColor: Colors.blue[600],
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.credit_card_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Credits',
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