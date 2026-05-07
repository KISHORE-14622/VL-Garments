import 'package:flutter/material.dart';
import '../../../core/services/data_service.dart';
import '../../../core/widgets/vl_loading.dart';
import '../../../core/models/supplier.dart';
import '../../../core/models/inventory_type.dart';

class InventoryOptionsScreen extends StatefulWidget {
  final DataService dataService;

  const InventoryOptionsScreen({super.key, required this.dataService});

  @override
  State<InventoryOptionsScreen> createState() => _InventoryOptionsScreenState();
}

class _InventoryOptionsScreenState extends State<InventoryOptionsScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    await widget.dataService.fetchSuppliers();
    await widget.dataService.fetchInventoryTypes();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const VLLoadingIndicator(message: 'LOADING OPTIONS...');

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Manage Inventory Options'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Item Names'),
              Tab(text: 'Suppliers'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildItemNamesTab(),
            _buildSuppliersTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildItemNamesTab() {
    final items = widget.dataService.inventoryTypes;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: () => _showAddOptionDialog(isSupplier: false),
            icon: const Icon(Icons.add),
            label: const Text('Add New Item Name'),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                title: Text(item.name),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showEditOptionDialog(item.id, item.name, isSupplier: false),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _confirmDelete(item.id, item.name, isSupplier: false),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSuppliersTab() {
    final suppliers = widget.dataService.suppliers;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: () => _showAddOptionDialog(isSupplier: true),
            icon: const Icon(Icons.add),
            label: const Text('Add New Supplier'),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: suppliers.length,
            itemBuilder: (context, index) {
              final supplier = suppliers[index];
              return ListTile(
                title: Text(supplier.name),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showEditOptionDialog(supplier.id, supplier.name, isSupplier: true),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _confirmDelete(supplier.id, supplier.name, isSupplier: true),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAddOptionDialog({required bool isSupplier}) {
    final ctrl = TextEditingController();
    final title = isSupplier ? 'Add Supplier' : 'Add Item Name';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Name'),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(context);
              setState(() => _loading = true);
              if (isSupplier) {
                await widget.dataService.addSupplier(name);
              } else {
                await widget.dataService.addInventoryType(name);
              }
              await _loadData();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditOptionDialog(String id, String currentName, {required bool isSupplier}) {
    final ctrl = TextEditingController(text: currentName);
    final title = isSupplier ? 'Edit Supplier' : 'Edit Item Name';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Name'),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(context);
              setState(() => _loading = true);
              if (isSupplier) {
                await widget.dataService.updateSupplier(id, name);
              } else {
                await widget.dataService.updateInventoryType(id, name);
              }
              await _loadData();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(String id, String name, {required bool isSupplier}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Delete "$name"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _loading = true);
              if (isSupplier) {
                await widget.dataService.deleteSupplier(id);
              } else {
                await widget.dataService.deleteInventoryType(id);
              }
              await _loadData();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
