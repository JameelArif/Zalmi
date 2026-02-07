import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BulkCustomerImportPage extends StatefulWidget {
  const BulkCustomerImportPage({super.key});

  @override
  State<BulkCustomerImportPage> createState() => _BulkCustomerImportPageState();
}

class _BulkCustomerImportPageState extends State<BulkCustomerImportPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _importing = false;
  bool _deleting = false;

  // ✅ NEW Customer data (from latest photos)
  final List<Map<String, String>> _customers = [
    // --- Photo 1 (UMB list) ---
    {'name': 'RDX', 'phone': '03394851858'},
    {'name': 'SHADI', 'phone': '306931951335'},
    {'name': 'ZINDAAGI', 'phone': '923089122896'},
    {'name': 'SAIM', 'phone': '393509883898'},
    {'name': 'LAHGUMLIHAS', 'phone': '923294371600'},
    // "BABOR" had no clear number in photo, so not added
    {'name': 'ARMAN AHMAD', 'phone': '923069842871'},
    {'name': 'MR KAMAL', 'phone': '923424546008'},
    {'name': 'JL', 'phone': '923038028610'},
    {'name': 'MUDASIR', 'phone': '923096883632'},
    {'name': 'DARKCOINSALLOR', 'phone': '923045867385'},
    {'name': 'IMRAN', 'phone': '923025849961'},
    {'name': 'RAJPUT', 'phone': '923097736292'},

    // --- Photo 2 (UME list) ---
    {'name': 'ZEE', 'phone': '96891807936'},
    {'name': 'DARK', 'phone': '447549254784'},
    {'name': 'SALMAN', 'phone': '923049433737'},
    {'name': 'SHERA JUTT', 'phone': '923254097898'},
    {'name': 'SLIENT', 'phone': '923492229760'},
    {'name': 'GUJJAR', 'phone': '9647725853031'},
    {'name': 'ZARA', 'phone': '923196838321'},
    {'name': 'SARDAAR', 'phone': '03155335829'},
    {'name': 'KASHI', 'phone': '923277899068'},
    {'name': 'KHAN', 'phone': '923000083625'},
    {'name': 'MALIK', 'phone': '923409860882'},
    {'name': 'AHMAD', 'phone': '923084840243'},
    {'name': 'BABAR', 'phone': '923056492137'},
    {'name': 'ZEESHAN', 'phone': '27745312313'},
    {'name': 'MAILK', 'phone': '923336497652'},
    {'name': 'RAJHABI', 'phone': '9239018028'}, // ⚠️ unclear in photo
    {'name': 'SALAM', 'phone': '97338064235'},
    {'name': 'EMOTION', 'phone': '923259316216'},
    {'name': 'NOOR HAZR', 'phone': '03113809379'},
    {'name': 'LADALA', 'phone': '923403663225'},
    {'name': 'ASEER', 'phone': '923252534911'},
    {'name': 'UMAR', 'phone': '923088111870'},
    {'name': 'ZALMIRESELLERJAMAL', 'phone': '923088111870'},
  ];
  // ✅ NEW Customer data: 16 customers (IDs 30-45)


  List<String> _results = [];
  int _successCount = 0;
  int _failCount = 0;

  Future<int> _getAdminId() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      // For employee
      final empRow = await _supabase
          .from('employees')
          .select('admin_id')
          .eq('auth_id', user.id)
          .maybeSingle();

      if (empRow != null) {
        return (empRow['admin_id'] as num).toInt();
      }

      // For admin
      final adminRow = await _supabase
          .from('admin')
          .select('id')
          .eq('auth_id', user.id)
          .single();

      return (adminRow['id'] as num).toInt();
    } catch (e) {
      throw Exception('Error getting admin ID: $e');
    }
  }

  Future<void> _deleteAllCustomers() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ Delete All Customers'),
        content: const Text(
          'This will DELETE ALL CUSTOMERS.\n\n'
              'This action CANNOT be undone!\n\n'
              'Are you absolutely sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('DELETE ALL'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _deleting = true;
      _results = [];
      _results.add('🗑️ Starting deletion...');
    });

    try {
      final adminId = await _getAdminId();

      setState(() => _results.add('Deleting all customers...'));

      // ✅ SIMPLE: Just delete from customers table
      await _supabase
          .from('customers')
          .delete()
          .eq('admin_id', adminId);

      setState(() => _results.add('✅ ALL CUSTOMERS DELETED!'));
      _toast('All customers deleted ✅');

    } catch (e) {
      setState(() => _results.add('❌ Error: $e'));
      _toast('Delete failed: $e');
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _startImport() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Import'),
        content: Text(
          'Import ${_customers.length} customers?\n\n'
              'Only name and contact will be added.\n'
              'No apps or credit will be assigned.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _importing = true;
      _results = [];
      _successCount = 0;
      _failCount = 0;
    });

    try {
      final adminId = await _getAdminId();

      for (int i = 0; i < _customers.length; i++) {
        final c = _customers[i];
        final name = c['name']!;
        final phone = c['phone']!;

        try {
          await _supabase.from('customers').insert({
            'admin_id': adminId,
            'customer_name': name.trim(),
            'customer_contact': phone.trim(),
          });

          setState(() {
            _successCount++;
            _results.add('✅ ${i + 1}. $name - $phone');
          });
        } catch (e) {
          setState(() {
            _failCount++;
            final errorMsg = e.toString().replaceAll('Exception: ', '');
            _results.add('❌ ${i + 1}. $name - $phone: $errorMsg');
          });
        }

        // Small delay to avoid overwhelming the database
        await Future.delayed(const Duration(milliseconds: 100));
      }
    } catch (e) {
      _toast('Error: $e');
    } finally {
      if (mounted) setState(() => _importing = false);
      _showCompletionDialog();
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('✅ Import Complete'),
        content: Text(
          'Import finished!\n\n'
              '✅ Success: $_successCount\n'
              '❌ Failed: $_failCount\n\n'
              'Go back to Customer Management and click "All Customers" to see the imported customers.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isProcessing = _importing || _deleting;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Bulk Customer Import'),
        backgroundColor: Colors.green[700],
        actions: [
          IconButton(
            onPressed: isProcessing ? null : _deleteAllCustomers,
            icon: const Icon(Icons.delete_forever),
            tooltip: 'Delete All Customers',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Summary Card
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
                    const Text(
                      'Import Summary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _statRow('Total Customers', _customers.length.toString()),
                    if (_importing || _results.isNotEmpty) ...[
                      const Divider(height: 20),
                      _statRow('Success', _successCount.toString(), Colors.green),
                      _statRow('Failed', _failCount.toString(), Colors.red),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isProcessing ? null : _startImport,
                    icon: _importing
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Icon(Icons.upload),
                    label: Text(_importing ? 'Importing...' : 'Import Customers'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      disabledBackgroundColor: Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isProcessing ? null : _deleteAllCustomers,
                    icon: _deleting
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Icon(Icons.delete_forever),
                    label: Text(_deleting ? 'Deleting...' : 'Delete All'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      disabledBackgroundColor: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Info Card
            Card(
              elevation: 2,
              color: Colors.blue[50],
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
                        Icon(Icons.info_outline, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        const Text(
                          'Information',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '📥 Import: Adds 16 new customers (IDs 30-45)\n'
                          '🗑️ Delete: Removes ALL customers\n'
                          '⚠️ Both actions affect only YOUR admin account',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Results List
            if (_results.isNotEmpty) ...[
              const Text(
                'Process Log:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final result = _results[index];
                      final isSuccess = result.startsWith('✅');
                      final isError = result.startsWith('❌');
                      Color textColor = Colors.grey[700]!;
                      if (isSuccess) textColor = Colors.green[700]!;
                      if (isError) textColor = Colors.red[700]!;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          result,
                          style: TextStyle(
                            fontSize: 12,
                            color: textColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statRow(String label, String value, [Color? color]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }
}
