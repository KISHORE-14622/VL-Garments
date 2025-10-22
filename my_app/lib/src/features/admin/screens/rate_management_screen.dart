import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/data_service.dart';
import '../../../core/models/product.dart';

class RateManagementScreen extends StatefulWidget {
  final DataService dataService;

  const RateManagementScreen({super.key, required this.dataService});

  @override
  State<RateManagementScreen> createState() => _RateManagementScreenState();
}

class _RateManagementScreenState extends State<RateManagementScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRates();
  }

  Future<void> _loadRates() async {
    try {
      final rates = await widget.dataService.fetchRates();
      // rates: List of { category, amount }
      final cats = <ProductCategory>[];
      final seen = <String>{};
      widget.dataService.ratePerCategory.clear();
      for (final r in rates) {
        final category = (r['category'] ?? '').toString();
        final amount = (r['amount'] is num) ? (r['amount'] as num).toDouble() : double.tryParse(r['amount']?.toString() ?? '0') ?? 0.0;
        if (category.isEmpty) continue;
        widget.dataService.ratePerCategory[category] = amount;
        if (!seen.contains(category)) {
          seen.add(category);
          cats.add(ProductCategory(id: category, name: _titleCase(category.replaceAll('_', ' '))));
        }
      }
      setState(() {
        widget.dataService.categories
          ..clear()
          ..addAll(cats);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      // Keep existing defaults if fetch fails
    }
  }

  String _titleCase(String input) {
    if (input.isEmpty) return input;
    return input.split(' ').map((w) => w.isEmpty ? w : (w[0].toUpperCase() + w.substring(1))).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Rate Management'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Info Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Set rates for each product category. These rates will be used to calculate staff earnings.',
                    style: TextStyle(color: Colors.blue[900], fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Category Rates
          ...widget.dataService.categories.map((category) {
            final currentRate = widget.dataService.ratePerCategory[category.id] ?? 0.0;
            return _buildRateCard(
              context,
              categoryId: category.id,
              categoryName: category.name,
              currentRate: currentRate,
            );
          }).toList(),

          const SizedBox(height: 16),

          // Add Category Button
          OutlinedButton.icon(
            onPressed: () => _showAddCategoryDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Add New Category'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRateCard(
    BuildContext context, {
    required String categoryId,
    required String categoryName,
    required double currentRate,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.category, color: Colors.green, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  categoryName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Current Rate',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${currentRate.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'per unit',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => _showEditRateDialog(categoryId, categoryName, currentRate),
            icon: const Icon(Icons.edit),
            style: IconButton.styleFrom(
              backgroundColor: Colors.grey[100],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditRateDialog(String categoryId, String categoryName, double currentRate) {
    final controller = TextEditingController(text: currentRate.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Rate for $categoryName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the new rate per unit:',
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              decoration: InputDecoration(
                labelText: 'Rate (₹)',
                prefixIcon: const Icon(Icons.currency_rupee),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newRate = double.tryParse(controller.text);
              if (newRate == null || newRate <= 0) return;
              try {
                await widget.dataService.upsertRate(category: categoryId, amount: newRate);
                setState(() {
                  widget.dataService.ratePerCategory[categoryId] = newRate;
                });
                if (mounted) Navigator.pop(context);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Updating rate...'),
                    duration: Duration(seconds: 1),
                  ),
                );
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to update rate'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddCategoryDialog() {
    final nameController = TextEditingController();
    final rateController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Category Name',
                prefixIcon: const Icon(Icons.category),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: rateController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              decoration: InputDecoration(
                labelText: 'Rate (₹)',
                prefixIcon: const Icon(Icons.currency_rupee),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final rate = double.tryParse(rateController.text);
              if (name.isEmpty || rate == null || rate <= 0) return;
              final categoryId = name.toLowerCase().replaceAll(' ', '_');
              try {
                await widget.dataService.upsertRate(category: categoryId, amount: rate);
                setState(() {
                  // add to local lists
                  if (!widget.dataService.categories.any((c) => c.id == categoryId)) {
                    widget.dataService.categories.add(ProductCategory(id: categoryId, name: name));
                  }
                  widget.dataService.ratePerCategory[categoryId] = rate;
                });
                if (mounted) Navigator.pop(context);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Category "$name" added/updated'),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to save category'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
