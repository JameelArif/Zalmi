import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../Prevoius code/Login/authservice.dart';
import '../Prevoius code/Login/loginscreen.dart';

class AdminProfilePage extends StatefulWidget {
  const AdminProfilePage({super.key});

  @override
  State<AdminProfilePage> createState() => _AdminProfilePageState();
}

class _AdminProfilePageState extends State<AdminProfilePage> {
  final SupabaseClient _sb = Supabase.instance.client;
  final AuthService _authService = AuthService();

  bool _loading = true;
  bool _saving = false;

  int? _adminId;
  String _adminName = '';
  String _adminEmail = '';
  String _adminContact = '';
  DateTime? _createdAt;
  DateTime? _updatedAt;

  bool _statsLoading = false;
  bool _statsLoaded = false;

  double _inventoryStandardValue = 0.0;
  double _inventoryWholesaleValue = 0.0;
  double _totalCustomerCredit = 0.0;
  double _approvedSalesTotal = 0.0;
  double _approvedSalesCashIn = 0.0;
  double _approvedSalesDue = 0.0;
  double _recoveriesTotal = 0.0;

  @override
  void initState() {
    super.initState();
    _loadAdminProfile();
  }

  Future<void> _loadAdminProfile() async {
    setState(() => _loading = true);
    try {
      final user = _sb.auth.currentUser;
      if (user == null) {
        _toast('Not logged in');
        return;
      }

      _adminEmail = user.email ?? '';

      final row = await _sb
          .from('admin')
          .select('id, name, email, contact, created_at, updated_at')
          .eq('auth_id', user.id)
          .maybeSingle();

      if (row == null) {
        setState(() {
          _adminId = null;
          _adminName = '';
          _adminContact = '';
          _createdAt = null;
          _updatedAt = null;
        });
      } else {
        setState(() {
          _adminId = (row['id'] as num).toInt();
          _adminName = (row['name'] ?? '').toString();
          _adminEmail = (row['email'] ?? _adminEmail).toString();
          _adminContact = (row['contact'] ?? '').toString();
          _createdAt = DateTime.tryParse((row['created_at'] ?? '').toString());
          _updatedAt = DateTime.tryParse((row['updated_at'] ?? '').toString());
        });
      }
    } catch (e) {
      _toast('Profile load error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createAdminRow() async {
    final user = _sb.auth.currentUser;
    if (user == null) return;

    final nameCtrl = TextEditingController(text: '');
    final contactCtrl = TextEditingController(text: '');

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Create Admin Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contactCtrl,
              decoration: const InputDecoration(
                labelText: 'Contact',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Email will be: ${user.email ?? ''}',
                style: TextStyle(color: Colors.grey[700], fontSize: 12),
              ),
            )
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) {
                _toast('Name required');
                return;
              }
              Navigator.pop(context);
              setState(() => _saving = true);
              try {
                await _sb.from('admin').insert({
                  'auth_id': user.id,
                  'name': name,
                  'email': user.email,
                  'contact': contactCtrl.text.trim(),
                });
                _toast('Admin profile created ✅');
                await _loadAdminProfile();
              } catch (e) {
                _toast('Create failed: $e');
              } finally {
                if (mounted) setState(() => _saving = false);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _editProfile() async {
    if (_adminId == null) {
      _toast('Admin row not found. Create profile first.');
      return;
    }

    final nameCtrl = TextEditingController(text: _adminName);
    final contactCtrl = TextEditingController(text: _adminContact);

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contactCtrl,
              decoration: const InputDecoration(
                labelText: 'Contact',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: _saving
                ? null
                : () async {
              final newName = nameCtrl.text.trim();
              if (newName.isEmpty) {
                _toast('Name required');
                return;
              }

              Navigator.pop(context);
              setState(() => _saving = true);
              try {
                await _sb.from('admin').update({
                  'name': newName,
                  'contact': contactCtrl.text.trim(),
                }).eq('id', _adminId!);

                _toast('Profile updated ✅');
                await _loadAdminProfile();
              } catch (e) {
                _toast('Update failed: $e');
              } finally {
                if (mounted) setState(() => _saving = false);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadStats() async {
    if (_adminId == null) {
      _toast('Create profile first (admin row missing).');
      return;
    }

    setState(() {
      _statsLoading = true;
      _statsLoaded = true;
      _inventoryStandardValue = 0.0;
      _inventoryWholesaleValue = 0.0;
      _totalCustomerCredit = 0.0;
      _approvedSalesTotal = 0.0;
      _approvedSalesCashIn = 0.0;
      _approvedSalesDue = 0.0;
      _recoveriesTotal = 0.0;
    });

    try {
      // 1) Inventory value
      final apps = await _sb
          .from('applications')
          .select('total_coins, per_coin_rate, wholesale_rate');

      for (final r in (apps as List)) {
        final coins = _toDouble(r['total_coins']);
        final rate = _toDouble(r['per_coin_rate']);
        final wh = _toDouble(r['wholesale_rate']);
        _inventoryStandardValue += coins * rate;
        _inventoryWholesaleValue += coins * wh;
      }

      // 2) Get customer IDs for this admin
      final custRows = await _sb
          .from('customers')
          .select('id')
          .eq('admin_id', _adminId!);

      final customerIds = (custRows as List).map((e) => (e['id'] as num).toInt()).toList();

      if (customerIds.isNotEmpty) {
        // 3) Total customer credit - ✅ FIXED: Use bracket notation [column]
        final creditRows = await _sb
            .from('customer_applications')
            .select('total_credit, customer_id')
            .filter('customer_id', 'in', '(${customerIds.join(',')})');

        for (final r in (creditRows as List)) {
          _totalCustomerCredit += _toDouble(r['total_credit']);
        }

        // 4) Approved sales totals - ✅ FIXED: Use bracket notation
        var salesQuery = _sb
            .from('sales')
            .select('status, over_rate, amount_received, used_credit, customer_id')
            .filter('customer_id', 'in', '(${customerIds.join(',')})');

        final salesRows = await salesQuery.neq('status', 'pending').limit(5000);

        for (final r in (salesRows as List)) {
          _approvedSalesTotal += _toDouble(r['over_rate']);
          _approvedSalesCashIn += _toDouble(r['amount_received']);
          _approvedSalesDue += _toDouble(r['used_credit']);
        }

        // 5) Recoveries total - ✅ FIXED: Use bracket notation
        try {
          final recRows = await _sb
              .from('customer_recoveries')
              .select('amount, customer_id')
              .filter('customer_id', 'in', '(${customerIds.join(',')})');

          for (final r in (recRows as List)) {
            _recoveriesTotal += _toDouble(r['amount']);
          }
        } catch (e) {
          _toast('Recoveries table error: $e');
        }
      }
    } catch (e) {
      _toast('Stats load error: $e');
    } finally {
      if (mounted) {
        setState(() => _statsLoading = false);
      }
    }
  }

  Future<void> _handleLogout() async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
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
                _toast('Logout failed: $e');
              }
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _sb.auth.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _headerCard(user?.email ?? _adminEmail),
          const SizedBox(height: 14),
          _profileCard(),
          const SizedBox(height: 14),
          _actionsCard(),
          const SizedBox(height: 14),
          _statsCard(),
        ],
      ),
    );
  }

  Widget _headerCard(String email) {
    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.92,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: Colors.white.withOpacity(0.2),
              child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _adminName.isEmpty ? 'Admin Profile' : _adminName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    email,
                    style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: Colors.white),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Profile Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (_adminId == null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Admin profile row not found in "admin" table.',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Click "Create Profile" to insert admin row using your auth_id.',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: _saving ? null : _createAdminRow,
                      icon: const Icon(Icons.person_add),
                      label: const Text('Create Profile'),
                    ),
                  ],
                ),
              )
            else ...[
              _kv('Admin ID', _adminId.toString()),
              _kv('Name', _adminName),
              _kv('Email', _adminEmail),
              _kv('Contact', _adminContact.isEmpty ? '-' : _adminContact),
              _kv('Created', _createdAt == null ? '-' : _fmtDate(_createdAt!)),
              _kv('Updated', _updatedAt == null ? '-' : _fmtDate(_updatedAt!)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _actionsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: Colors.white),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton.icon(
                  onPressed: (_adminId == null || _saving) ? null : _editProfile,
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit Profile'),
                ),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _loadAdminProfile,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
                OutlinedButton.icon(
                  onPressed: _handleLogout,
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text('Logout', style: TextStyle(color: Colors.red)),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _statsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: Colors.white),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Business Snapshot', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (_statsLoading || _adminId == null) ? null : _loadStats,
                    icon: _statsLoading
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                        : const Icon(Icons.analytics),
                    label: Text(_statsLoaded ? 'Reload Stats' : 'Load Stats'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!_statsLoaded)
              Text(
                'Stats will show after you press "Load Stats".',
                style: TextStyle(color: Colors.grey[700]),
              ),
            if (_statsLoaded) ...[
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _pill('Inv Std', _inventoryStandardValue.toStringAsFixed(2), Colors.teal),
                  _pill('Inv Wholesale', _inventoryWholesaleValue.toStringAsFixed(2), Colors.indigo),
                  _pill('Cust Credit', _totalCustomerCredit.toStringAsFixed(2), Colors.red),
                  _pill('Sales Total', _approvedSalesTotal.toStringAsFixed(2), Colors.blue),
                  _pill('Cash In', _approvedSalesCashIn.toStringAsFixed(2), Colors.green),
                  _pill('Sales Due', _approvedSalesDue.toStringAsFixed(2), Colors.orange),
                  _pill('Recoveries', _recoveriesTotal.toStringAsFixed(2), Colors.purple),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Note: Sales includes status != pending. Recoveries reads from customer_recoveries table.',
                style: TextStyle(color: Colors.grey[700], fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: TextStyle(color: Colors.grey[700])),
          Flexible(
            child: Text(
              v,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String k, String v, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withOpacity(0.25)),
      ),
      child: Text('$k: $v', style: TextStyle(fontWeight: FontWeight.w900, color: c)),
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  String _fmtDate(DateTime d) {
    String two(int x) => x < 10 ? '0$x' : '$x';
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }
}