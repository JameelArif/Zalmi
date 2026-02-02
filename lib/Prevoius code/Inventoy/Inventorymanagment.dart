import 'package:flutter/material.dart';

import '../Login/authservice.dart';
import 'Inventorymodel.dart';
import 'Inventoryservice.dart';


class InventoryManagement extends StatefulWidget {
  const InventoryManagement({super.key});

  @override
  State<InventoryManagement> createState() => _InventoryManagementState();
}

class _InventoryManagementState extends State<InventoryManagement> {
  final inventoryService = InventoryService();
  final authService = AuthService();
  List<InventoryApp> apps = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  Future<void> _loadApps() async {
    try {
      final data = await inventoryService.getAllApps();
      setState(() {
        apps = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  double _getTotalCoinsWorth() {
    return apps.fold(0.0, (sum, app) => sum + (app.overallCoins * app.coinSellingPrice));
  }

  double _getTotalAppCoins() {
    return apps.fold(0.0, (sum, app) => sum + app.overallCoins);
  }

  double _getTotalCredit() {
    return apps.fold(0.0, (sum, app) => sum + app.totalCredit);
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (_) => AddAppDialog(
        onAdd: (app) async {
          try {
            final user = authService.getCurrentUser();
            await inventoryService.createApp(
              appName: app['appName'],
              details: app['details'],
              openingCoins: app['openingCoins'],
              totalCredit: app['totalCredit'],
              coinSellingPrice: app['coinSellingPrice'],
              coinBuyingPrice: app['coinBuyingPrice'],
              wholesalePrice: app['wholesalePrice'],
              changedBy: user?.email ?? 'Unknown',
            );
            _loadApps();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('App added successfully')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text('Error: $e')));
            }
          }
        },
      ),
    );
  }

  void _showEditDialog(InventoryApp app) {
    showDialog(
      context: context,
      builder: (_) => EditAppDialog(
        app: app,
        onUpdate: (updated) async {
          try {
            final user = authService.getCurrentUser();
            await inventoryService.updateApp(
              id: app.id,
              appName: updated['appName'],
              details: updated['details'],
              openingCoins: updated['openingCoins'],
              overallCoins: updated['overallCoins'],
              totalCredit: updated['totalCredit'],
              coinSellingPrice: updated['coinSellingPrice'],
              coinBuyingPrice: updated['coinBuyingPrice'],
              changedBy: user?.email ?? 'Unknown',
            );
            _loadApps();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('App updated successfully')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text('Error: $e')));
            }
          }
        },
      ),
    );
  }

  void _showLogs(int appId) {
    showDialog(
      context: context,
      builder: (_) => LogsDialog(appId: appId),
    );
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
            // Header with Add Button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Inventory',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _showAddDialog,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add App'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),

            // Summary Cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          title: 'Total Coins Worth',
                          value: '${_getTotalCoinsWorth().toStringAsFixed(2)} PKR',
                          icon: Icons.monetization_on,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSummaryCard(
                          title: 'Total App Coins',
                          value: _getTotalAppCoins().toStringAsFixed(2),
                          icon: Icons.inventory_2,
                          color: Colors.lightBlue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildSummaryCard(
                    title: 'Total Credit In Market',
                    value: '${_getTotalCredit().toStringAsFixed(2)} Coins',
                    icon: Icons.trending_up,
                    color: Colors.cyan,
                    fullWidth: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Horizontally Scrollable Table
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: apps.isEmpty
                  ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Text(
                    'No apps added yet',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              )
                  : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey[200]!,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: DataTable(
                    headingRowColor: MaterialStateColor.resolveWith((_) => Colors.blue[100]!),
                    dataRowHeight: 60,
                    columns: const [
                      DataColumn(label: SizedBox(width: 150, child: Text('App Name', style: TextStyle(fontWeight: FontWeight.bold)))),
                      DataColumn(label: SizedBox(width: 100, child: Text('Details', style: TextStyle(fontWeight: FontWeight.bold)))),
                      DataColumn(label: SizedBox(width: 130, child: Text('Overall Coins', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center))),
                      DataColumn(label: SizedBox(width: 120, child: Text('Worth (PKR)', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center))),
                      DataColumn(label: SizedBox(width: 100, child: Text('Credit\n(Coins)', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center))),
                      DataColumn(label: SizedBox(width: 140, child: Text('Sell Price/Coin\n(PKR)', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center))),
                      DataColumn(label: SizedBox(width: 140, child: Text('Buy Price/Coin\n(PKR)', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center))),
                      DataColumn(label: SizedBox(width: 140, child: Text('Wholesale Price/Coin\n(PKR)', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center))),
                      DataColumn(label: SizedBox(width: 80, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center))),
                    ],
                    rows: apps.map((app) {
                      final coinsWorth = app.overallCoins * app.coinSellingPrice;
                      return DataRow(
                        cells: [
                          DataCell(
                            SizedBox(
                              width: 150,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    app.appName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    app.details.length > 15 ? '${app.details.substring(0, 15)}...' : app.details,
                                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 100,
                              child: Text(
                                app.details.length > 12 ? '${app.details.substring(0, 12)}...' : app.details,
                                style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 130,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  app.overallCoins.toStringAsFixed(2),
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.blue[700]),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 120,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  coinsWorth.toStringAsFixed(2),
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.green[700]),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 100,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.cyan[50],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  app.totalCredit.toStringAsFixed(0),
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.cyan[700]),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 140,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.orange[50],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  app.coinSellingPrice.toStringAsFixed(2),
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Colors.orange[700]),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 140,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.purple[50],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  app.coinBuyingPrice.toStringAsFixed(2),
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Colors.purple[700]),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 140,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.red[50],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  app.wholesalePrice.toStringAsFixed(2),
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Colors.red[700]),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 80,
                              child: PopupMenuButton(
                                icon: Icon(Icons.more_vert, color: Colors.blue[600], size: 20),
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    child: const Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Edit')]),
                                    onTap: () => _showEditDialog(app),
                                  ),
                                  PopupMenuItem(
                                    child: const Row(children: [Icon(Icons.history, size: 18), SizedBox(width: 8), Text('Logs')]),
                                    onTap: () => _showLogs(app.id),
                                  ),
                                  PopupMenuItem(
                                    child: const Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))]),
                                    onTap: () async {
                                      if (await _confirmDelete()) {
                                        try {
                                          await inventoryService.deleteApp(app.id);
                                          _loadApps();
                                        } catch (e) {
                                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard({required String title, required String value, required IconData icon, required Color color, bool fullWidth = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.grey[300]!, blurRadius: 8, offset: const Offset(0, 2))],
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, color: color, size: 24), const SizedBox(width: 8), Expanded(child: Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)))]),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Future<bool> _confirmDelete() async {
    final result = await showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Delete App'), content: const Text('Are you sure you want to delete this app?'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red)))]));
    return result ?? false;
  }
}

// ADD APP DIALOG
class AddAppDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onAdd;
  const AddAppDialog({super.key, required this.onAdd});
  @override
  State<AddAppDialog> createState() => _AddAppDialogState();
}

class _AddAppDialogState extends State<AddAppDialog> {
  final formKey = GlobalKey<FormState>();
  final appNameController = TextEditingController();
  final detailsController = TextEditingController();
  final openingCoinsController = TextEditingController();
  final totalCreditController = TextEditingController();
  final coinSellingPriceController = TextEditingController();
  final coinBuyingPriceController = TextEditingController();
  final wholesalePriceController = TextEditingController();

  @override
  void dispose() {
    appNameController.dispose();
    detailsController.dispose();
    openingCoinsController.dispose();
    totalCreditController.dispose();
    coinSellingPriceController.dispose();
    coinBuyingPriceController.dispose();
    wholesalePriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Application'),
      content: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: appNameController, decoration: InputDecoration(labelText: 'App Name', prefixIcon: const Icon(Icons.apps, color: Colors.blue), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), validator: (v) => v?.isEmpty ?? true ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(controller: detailsController, decoration: InputDecoration(labelText: 'Details', prefixIcon: const Icon(Icons.description, color: Colors.blue), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), maxLines: 3, validator: (v) => v?.isEmpty ?? true ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(controller: openingCoinsController, decoration: InputDecoration(labelText: 'Opening Coins', prefixIcon: const Icon(Icons.monetization_on, color: Colors.blue), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), keyboardType: TextInputType.number, validator: (v) => v?.isEmpty ?? true ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(controller: totalCreditController, decoration: InputDecoration(labelText: 'Total Credit (Coins)', prefixIcon: const Icon(Icons.trending_up, color: Colors.blue), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), keyboardType: TextInputType.number, validator: (v) => v?.isEmpty ?? true ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(controller: coinSellingPriceController, decoration: InputDecoration(labelText: 'Selling Price Per Coin (PKR)', prefixIcon: const Icon(Icons.sell, color: Colors.blue), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (v) => v?.isEmpty ?? true ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(controller: coinBuyingPriceController, decoration: InputDecoration(labelText: 'Buying Price Per Coin (PKR)', prefixIcon: const Icon(Icons.shopping_cart, color: Colors.blue), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (v) => v?.isEmpty ?? true ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(controller: wholesalePriceController, decoration: InputDecoration(labelText: 'Wholesale Price Per Coin (PKR)', prefixIcon: const Icon(Icons.local_offer, color: Colors.green), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (v) => v?.isEmpty ?? true ? 'Required' : null),
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), ElevatedButton(onPressed: () { if (formKey.currentState!.validate()) { widget.onAdd({'appName': appNameController.text, 'details': detailsController.text, 'openingCoins': double.parse(openingCoinsController.text), 'totalCredit': double.parse(totalCreditController.text), 'coinSellingPrice': double.parse(coinSellingPriceController.text), 'coinBuyingPrice': double.parse(coinBuyingPriceController.text), 'wholesalePrice': double.parse(wholesalePriceController.text)}); Navigator.pop(context); } }, style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[600]), child: const Text('Add', style: TextStyle(color: Colors.white)))],
    );
  }
}

// EDIT APP DIALOG
class EditAppDialog extends StatefulWidget {
  final InventoryApp app;
  final Function(Map<String, dynamic>) onUpdate;
  const EditAppDialog({super.key, required this.app, required this.onUpdate});
  @override
  State<EditAppDialog> createState() => _EditAppDialogState();
}

class _EditAppDialogState extends State<EditAppDialog> {
  final formKey = GlobalKey<FormState>();
  late TextEditingController appNameController, detailsController, openingCoinsController, overallCoinsController, totalCreditController, coinSellingPriceController, coinBuyingPriceController;

  @override
  void initState() {
    super.initState();
    appNameController = TextEditingController(text: widget.app.appName);
    detailsController = TextEditingController(text: widget.app.details);
    openingCoinsController = TextEditingController(text: widget.app.openingCoins.toString());
    overallCoinsController = TextEditingController(text: widget.app.overallCoins.toString());
    totalCreditController = TextEditingController(text: widget.app.totalCredit.toString());
    coinSellingPriceController = TextEditingController(text: widget.app.coinSellingPrice.toStringAsFixed(2));
    coinBuyingPriceController = TextEditingController(text: widget.app.coinBuyingPrice.toStringAsFixed(2));
  }

  @override
  void dispose() {
    appNameController.dispose();
    detailsController.dispose();
    openingCoinsController.dispose();
    overallCoinsController.dispose();
    totalCreditController.dispose();
    coinSellingPriceController.dispose();
    coinBuyingPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Application'),
      content: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: appNameController, decoration: InputDecoration(labelText: 'App Name', prefixIcon: const Icon(Icons.apps, color: Colors.blue), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), validator: (v) => v?.isEmpty ?? true ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(controller: detailsController, decoration: InputDecoration(labelText: 'Details', prefixIcon: const Icon(Icons.description, color: Colors.blue), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), maxLines: 3, validator: (v) => v?.isEmpty ?? true ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(controller: openingCoinsController, decoration: InputDecoration(labelText: 'Opening Coins', prefixIcon: const Icon(Icons.monetization_on, color: Colors.blue), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), keyboardType: TextInputType.number, validator: (v) => v?.isEmpty ?? true ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(controller: overallCoinsController, decoration: InputDecoration(labelText: 'Overall Coins', prefixIcon: const Icon(Icons.inventory_2, color: Colors.blue), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), keyboardType: TextInputType.number, validator: (v) => v?.isEmpty ?? true ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(controller: totalCreditController, decoration: InputDecoration(labelText: 'Total Credit (Coins)', prefixIcon: const Icon(Icons.trending_up, color: Colors.blue), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), keyboardType: TextInputType.number, validator: (v) => v?.isEmpty ?? true ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(controller: coinSellingPriceController, decoration: InputDecoration(labelText: 'Selling Price Per Coin (PKR)', prefixIcon: const Icon(Icons.sell, color: Colors.blue), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (v) => v?.isEmpty ?? true ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(controller: coinBuyingPriceController, decoration: InputDecoration(labelText: 'Buying Price Per Coin (PKR)', prefixIcon: const Icon(Icons.shopping_cart, color: Colors.blue), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (v) => v?.isEmpty ?? true ? 'Required' : null),
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), ElevatedButton(onPressed: () { if (formKey.currentState!.validate()) { widget.onUpdate({'appName': appNameController.text, 'details': detailsController.text, 'openingCoins': double.parse(openingCoinsController.text), 'overallCoins': double.parse(overallCoinsController.text), 'totalCredit': double.parse(totalCreditController.text), 'coinSellingPrice': double.parse(coinSellingPriceController.text), 'coinBuyingPrice': double.parse(coinBuyingPriceController.text)}); Navigator.pop(context); } }, style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[600]), child: const Text('Update', style: TextStyle(color: Colors.white)))],
    );
  }
}

// LOGS DIALOG WITH PASSWORD PROTECTION (PASSWORD HIDDEN)
class LogsDialog extends StatefulWidget {
  final int appId;
  const LogsDialog({super.key, required this.appId});
  @override
  State<LogsDialog> createState() => _LogsDialogState();
}

class _LogsDialogState extends State<LogsDialog> {
  final inventoryService = InventoryService();
  late Future<List<InventoryLog>> logsFuture;

  @override
  void initState() {
    super.initState();
    logsFuture = inventoryService.getAppLogs(widget.appId);
  }

  Future<void> _deleteLogWithPassword(InventoryLog log) async {
    final passwordController = TextEditingController();
    final result = await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter security code to delete this log entry:'),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'Security Code',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.lock, color: Colors.blue),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (passwordController.text == '0909') {
                Navigator.pop(context, true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid code')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[600]),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await inventoryService.deleteLog(log.id);
        setState(() {
          logsFuture = inventoryService.getAppLogs(widget.appId);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Log deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Activity Logs'),
      content: SizedBox(
        width: double.maxFinite,
        child: FutureBuilder<List<InventoryLog>>(
          future: logsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
            final logs = snapshot.data ?? [];
            if (logs.isEmpty) return const Center(child: Text('No changes recorded'));
            return ListView.builder(
              itemCount: logs.length,
              itemBuilder: (context, index) {
                final log = logs[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Icon(Icons.edit, color: Colors.blue[600]),
                    title: Text(log.fieldName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${log.oldValue} → ${log.newValue}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.black87),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'By: ${log.changedBy} | ${log.changedAt.toString().split('.')[0]}',
                          style: const TextStyle(fontSize: 9, color: Colors.grey),
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                      onPressed: () => _deleteLogWithPassword(log),
                      tooltip: 'Delete Log',
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    );
  }
}