import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../core/models/inventory.dart';
import '../../../core/services/data_service.dart';
import '../../../core/utils/export_helper.dart';

class InventoryScreen extends StatefulWidget {
  final DataService dataService;

  const InventoryScreen({super.key, required this.dataService});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  bool _loading = true;
  final _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    setState(() => _loading = true);
    try { await widget.dataService.fetchInventory(); } catch (_) {}
    try { await widget.dataService.fetchGstSettings(); } catch (_) {}
    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final inventory = widget.dataService.inventory;
    final totalValue = inventory.fold<double>(0, (sum, item) => sum + item.totalCost);
    final totalGst = inventory.fold<double>(0, (sum, item) => sum + item.totalGst);
    final totalWithGst = inventory.fold<double>(0, (sum, item) => sum + item.grandTotal);
    final totalItems = inventory.fold<int>(0, (sum, item) => sum + item.quantity);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Inventory Management'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined, color: Color(0xFF4A90E2)),
            tooltip: 'Export to Excel',
            onPressed: () => ExportHelper.exportToExcel(context, widget.dataService, 'inventory'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadInventory,
              child: Column(
                children: [
                  // Summary Cards
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: _buildSummaryCard('Total Items', totalItems.toString(), Colors.blue, Icons.inventory_2)),
                            const SizedBox(width: 10),
                            Expanded(child: _buildSummaryCard('Base Value', '₹${totalValue.toStringAsFixed(0)}', Colors.teal, Icons.currency_rupee)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: _buildSummaryCard('Total GST', '₹${totalGst.toStringAsFixed(0)}', const Color(0xFFFF9500), Icons.account_balance)),
                            const SizedBox(width: 10),
                            Expanded(child: _buildSummaryCard('Grand Total', '₹${totalWithGst.toStringAsFixed(0)}', const Color(0xFF50C878), Icons.receipt)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Inventory List
                  Expanded(
                    child: inventory.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: inventory.length,
                            itemBuilder: (context, index) => _buildInventoryCard(inventory[index]),
                          ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddItemDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color))),
          Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('No Inventory Items', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[700])),
          const SizedBox(height: 8),
          Text('Add items to track your inventory', style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildInventoryCard(InventoryItem item) {
    final isLowStock = item.quantity < 10;
    final hasGst = item.cgstPercent > 0 || item.sgstPercent > 0;
    final itemDate = item.date != null ? _dateFormat.format(item.date!) : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (isLowStock ? Colors.orange : Colors.teal).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.inventory_2, color: isLowStock ? Colors.orange : Colors.teal, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 2),
                    Row(children: [
                      if (isLowStock)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                          child: const Text('Low Stock', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      if (item.supplier.isNotEmpty)
                        Text(item.supplier, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      if (itemDate.isNotEmpty)
                        Text('${item.supplier.isNotEmpty ? "  •  " : ""}$itemDate', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ]),
                  ],
                ),
              ),
              PopupMenuButton(
                icon: const Icon(Icons.more_vert),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 20), SizedBox(width: 12), Text('Edit')])),
                  const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 20, color: Colors.red), SizedBox(width: 12), Text('Delete', style: TextStyle(color: Colors.red))])),
                ],
                onSelected: (value) {
                  if (value == 'delete') _confirmDelete(item);
                  else if (value == 'edit') _showEditItemDialog(item);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Stats row
          Row(
            children: [
              Expanded(child: _buildItemStat('Quantity', item.quantity.toString(), Icons.inventory)),
              Container(width: 1, height: 40, color: Colors.grey[300]),
              Expanded(child: _buildItemStat('Unit Cost', '₹${item.unitCost.toStringAsFixed(2)}', Icons.currency_rupee)),
              Container(width: 1, height: 40, color: Colors.grey[300]),
              Expanded(child: _buildItemStat('Base Total', '₹${item.totalCost.toStringAsFixed(0)}', Icons.calculate)),
            ],
          ),

          // GST breakdown (if applicable)
          if (hasGst) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF4A90E2).withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(children: [
                _gstRow('CGST @ ${item.cgstPercent}%', '₹${item.cgstAmount.toStringAsFixed(2)}'),
                _gstRow('SGST @ ${item.sgstPercent}%', '₹${item.sgstAmount.toStringAsFixed(2)}'),
                const Divider(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Total with GST', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('₹${item.grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF50C878))),
                ]),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _gstRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4A90E2))),
      ]),
    );
  }

  Widget _buildItemStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
      ],
    );
  }

  void _showAddItemDialog() {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final cgstCtrl = TextEditingController(text: '${widget.dataService.gstSetting?.cgstPercent ?? 0}');
    final sgstCtrl = TextEditingController(text: '${widget.dataService.gstSetting?.sgstPercent ?? 0}');
    final supplierCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.add_shopping_cart, color: Colors.teal),
          ),
          const SizedBox(width: 12),
          const Text('Add Material'),
        ]),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: InputDecoration(labelText: 'Item Name', prefixIcon: const Icon(Icons.label), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            const SizedBox(height: 12),
            TextField(controller: supplierCtrl, decoration: InputDecoration(labelText: 'Supplier (optional)', prefixIcon: const Icon(Icons.store), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: qtyCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: InputDecoration(labelText: 'Quantity', prefixIcon: const Icon(Icons.inventory), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: costCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))], decoration: InputDecoration(labelText: 'Unit Cost ₹', prefixIcon: const Icon(Icons.currency_rupee), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
            ]),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 4),
            const Text('GST on Purchase', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: cgstCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'CGST %', prefixIcon: const Icon(Icons.percent), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: sgstCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'SGST %', prefixIcon: const Icon(Icons.percent), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
            ]),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add'),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final quantity = int.tryParse(qtyCtrl.text);
              final cost = double.tryParse(costCtrl.text);

              if (name.isNotEmpty && quantity != null && quantity > 0 && cost != null && cost > 0) {
                Navigator.pop(context);
                final result = await widget.dataService.addInventoryItem(
                  name: name,
                  quantity: quantity,
                  unitCost: cost,
                  cgstPercent: double.tryParse(cgstCtrl.text) ?? 0,
                  sgstPercent: double.tryParse(sgstCtrl.text) ?? 0,
                  supplier: supplierCtrl.text.trim(),
                );
                if (result != null && mounted) {
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name added to inventory'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _showEditItemDialog(InventoryItem item) {
    final nameCtrl = TextEditingController(text: item.name);
    final qtyCtrl = TextEditingController(text: item.quantity.toString());
    final costCtrl = TextEditingController(text: item.unitCost.toStringAsFixed(2));
    final cgstCtrl = TextEditingController(text: item.cgstPercent.toString());
    final sgstCtrl = TextEditingController(text: item.sgstPercent.toString());
    final supplierCtrl = TextEditingController(text: item.supplier);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.edit, color: Colors.blue),
          ),
          const SizedBox(width: 12),
          const Text('Edit Material'),
        ]),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: InputDecoration(labelText: 'Item Name', prefixIcon: const Icon(Icons.label), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            const SizedBox(height: 12),
            TextField(controller: supplierCtrl, decoration: InputDecoration(labelText: 'Supplier', prefixIcon: const Icon(Icons.store), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: qtyCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: InputDecoration(labelText: 'Quantity', prefixIcon: const Icon(Icons.inventory), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: costCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))], decoration: InputDecoration(labelText: 'Unit Cost ₹', prefixIcon: const Icon(Icons.currency_rupee), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
            ]),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 4),
            const Text('GST on Purchase', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: cgstCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'CGST %', prefixIcon: const Icon(Icons.percent), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: sgstCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'SGST %', prefixIcon: const Icon(Icons.percent), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
            ]),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Save'),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final quantity = int.tryParse(qtyCtrl.text);
              final cost = double.tryParse(costCtrl.text);

              if (name.isNotEmpty && quantity != null && quantity > 0 && cost != null && cost > 0) {
                Navigator.pop(context);
                final ok = await widget.dataService.updateInventoryItem(
                  item.id,
                  name: name,
                  quantity: quantity,
                  unitCost: cost,
                  cgstPercent: double.tryParse(cgstCtrl.text) ?? 0,
                  sgstPercent: double.tryParse(sgstCtrl.text) ?? 0,
                  supplier: supplierCtrl.text.trim(),
                );
                if (ok && mounted) {
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item updated'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _confirmDelete(InventoryItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to delete "${item.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final ok = await widget.dataService.deleteInventoryItem(item.id);
              if (ok && mounted) {
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${item.name} deleted'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
