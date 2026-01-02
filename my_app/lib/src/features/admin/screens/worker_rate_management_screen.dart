import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/data_service.dart';
import '../../../core/models/worker_category.dart';
import '../../../core/models/product.dart';

class WorkerRateManagementScreen extends StatefulWidget {
  final DataService dataService;

  const WorkerRateManagementScreen({super.key, required this.dataService});

  @override
  State<WorkerRateManagementScreen> createState() => _WorkerRateManagementScreenState();
}

class _WorkerRateManagementScreenState extends State<WorkerRateManagementScreen> {
  bool _loading = true;
  Map<String, Map<String, double>> _categoryItemRates = {}; // category -> {item -> rate}

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      await widget.dataService.fetchWorkerCategories();
      await widget.dataService.syncRatesFromServer();
      
      // Load rates - organize by worker category
      final rates = await widget.dataService.fetchRates();
      final rateMap = <String, Map<String, double>>{};
      
      for (final r in rates) {
        final category = (r['category'] ?? '').toString();
        final amount = (r['amount'] is num) 
            ? (r['amount'] as num).toDouble() 
            : double.tryParse(r['amount']?.toString() ?? '0') ?? 0.0;
        
        if (category.isNotEmpty) {
          // For now, we'll use the product categories as items
          // You can modify this to use custom item names
          if (!rateMap.containsKey(category)) {
            rateMap[category] = {};
          }
          rateMap[category]![category] = amount;
        }
      }
      
      setState(() {
        _categoryItemRates = rateMap;
        _loading = false;
      });
    } catch (e) {
      print('Error loading worker rates: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final workerCategories = widget.dataService.workerCategories;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Worker Rate Management'),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
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
                    'Tap on a worker category to set rates for different items (shirt, pant, etc.)',
                    style: TextStyle(color: Colors.blue[900], fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Worker Category Cards
          if (workerCategories.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    Icon(Icons.category_outlined, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No Worker Categories',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add worker categories in Staff Management first',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            )
          else
            ...workerCategories.map((category) {
              final itemRates = _categoryItemRates[category.id] ?? {};
              final itemCount = itemRates.length;
              return _buildCategoryCard(
                context,
                category: category,
                itemCount: itemCount,
              );
            }).toList(),

          const SizedBox(height: 16),

          // Add Category Button
          OutlinedButton.icon(
            onPressed: () => _showAddCategoryDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Add New Worker Category'),
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

  Widget _buildCategoryCard(
    BuildContext context, {
    required WorkerCategory category,
    required int itemCount,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToItemRates(category),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.people, color: Colors.purple, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        itemCount == 0 
                            ? 'No items configured'
                            : '$itemCount item${itemCount == 1 ? '' : 's'} configured',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _showDeleteCategoryDialog(category),
                  icon: const Icon(Icons.delete_outline),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.red[50],
                    foregroundColor: Colors.red,
                  ),
                  tooltip: 'Delete Category',
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToItemRates(WorkerCategory category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryItemRatesScreen(
          dataService: widget.dataService,
          category: category,
          onRatesUpdated: _loadData,
        ),
      ),
    );
  }

  void _showAddCategoryDialog() {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Worker Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Category Name',
                hintText: 'e.g., Ironers, Helpers, Tailour',
                prefixIcon: const Icon(Icons.people),
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
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a category name')),
                );
                return;
              }
              try {
                final category = await widget.dataService.createWorkerCategory(name);
                if (category != null) {
                  await _loadData();
                  if (mounted) Navigator.pop(context);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Category "$name" added successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to add category: $e'),
                      backgroundColor: Colors.red,
                    ),
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

  void _showDeleteCategoryDialog(WorkerCategory category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Worker Category'),
        content: Text(
          'Are you sure you want to delete "${category.name}"?\n\n'
          'This will also remove all item rates associated with this category.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await widget.dataService.deleteWorkerCategory(category.id);
                await _loadData();
                if (mounted) Navigator.pop(context);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Category "${category.name}" deleted successfully'),
                    backgroundColor: Colors.orange,
                  ),
                );
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete category: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// New screen to show items within a category
class CategoryItemRatesScreen extends StatefulWidget {
  final DataService dataService;
  final WorkerCategory category;
  final VoidCallback onRatesUpdated;

  const CategoryItemRatesScreen({
    super.key,
    required this.dataService,
    required this.category,
    required this.onRatesUpdated,
  });

  @override
  State<CategoryItemRatesScreen> createState() => _CategoryItemRatesScreenState();
}

class _CategoryItemRatesScreenState extends State<CategoryItemRatesScreen> {
  bool _loading = true;
  Map<String, double> _itemRates = {}; // item -> rate

  @override
  void initState() {
    super.initState();
    _loadItemRates();
  }

  Future<void> _loadItemRates() async {
    setState(() => _loading = true);
    try {
      final rates = await widget.dataService.fetchRates();
      final rateMap = <String, double>{};
      
      // Load only rates that belong to this worker category
      // Format: workerCategoryId_itemName
      for (final r in rates) {
        final category = (r['category'] ?? '').toString();
        if (category.startsWith('${widget.category.id}_')) {
          // Extract item name from the key
          final itemName = category.substring(widget.category.id.length + 1);
          final amount = (r['amount'] is num) 
              ? (r['amount'] as num).toDouble() 
              : double.tryParse(r['amount']?.toString() ?? '0') ?? 0.0;
          rateMap[itemName] = amount;
        }
      }
      
      setState(() {
        _itemRates = rateMap;
        _loading = false;
      });
    } catch (e) {
      print('Error loading item rates: $e');
      setState(() => _loading = false);
    }
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
        title: Text('${widget.category.name} - Item Rates'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Info Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.purple.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.purple[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Add items and set rates for ${widget.category.name}',
                    style: TextStyle(color: Colors.purple[900], fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Item Rate Cards
          if (_itemRates.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No Items Added',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Click "Add Item" below to add items for ${widget.category.name}',
                      style: TextStyle(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            ..._itemRates.entries.map((entry) {
              return _buildItemRateCard(
                context,
                itemName: entry.key,
                currentRate: entry.value,
              );
            }).toList(),

          const SizedBox(height: 16),

          // Add Item Button
          OutlinedButton.icon(
            onPressed: () => _showAddItemDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Add Item'),
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

  Widget _buildItemRateCard(
    BuildContext context, {
    required String itemName,
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
            child: const Icon(Icons.checkroom, color: Colors.green, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  itemName,
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
            onPressed: () => _showEditRateDialog(itemName, currentRate),
            icon: const Icon(Icons.edit),
            style: IconButton.styleFrom(
              backgroundColor: Colors.grey[100],
            ),
          ),
          IconButton(
            onPressed: () => _showDeleteItemDialog(itemName),
            icon: const Icon(Icons.delete_outline),
            style: IconButton.styleFrom(
              backgroundColor: Colors.red[50],
              foregroundColor: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddItemDialog() {
    final nameController = TextEditingController();
    final rateController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Item for ${widget.category.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Item Name',
                hintText: 'e.g., Shirt, Pant, Bedsheet',
                prefixIcon: const Icon(Icons.checkroom),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              textCapitalization: TextCapitalization.words,
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
                hintText: 'Rate per unit',
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
              final itemName = nameController.text.trim();
              final rate = double.tryParse(rateController.text);
              
              if (itemName.isEmpty || rate == null || rate < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill all fields correctly')),
                );
                return;
              }

              // Check if item already exists
              if (_itemRates.containsKey(itemName)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Item already exists')),
                );
                return;
              }

              try {
                // Use composite key: workerCategoryId_itemName
                final key = '${widget.category.id}_$itemName';
                await widget.dataService.upsertRate(
                  category: key,
                  amount: rate,
                );
                setState(() {
                  _itemRates[itemName] = rate;
                });
                widget.onRatesUpdated();
                if (mounted) Navigator.pop(context);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Item "$itemName" added successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to add item: $e'),
                      backgroundColor: Colors.red,
                    ),
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

  void _showEditRateDialog(String itemName, double currentRate) {
    final controller = TextEditingController(text: currentRate.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Rate for $itemName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set rate for ${widget.category.name} working on $itemName:',
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
              autofocus: true,
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
              if (newRate == null || newRate < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid rate')),
                );
                return;
              }
              try {
                // Use composite key: workerCategoryId_itemName
                final key = '${widget.category.id}_$itemName';
                await widget.dataService.upsertRate(
                  category: key,
                  amount: newRate,
                );
                setState(() {
                  _itemRates[itemName] = newRate;
                });
                widget.onRatesUpdated();
                if (mounted) Navigator.pop(context);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Rate updated for $itemName'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to update rate: $e'),
                      backgroundColor: Colors.red,
                    ),
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

  void _showDeleteItemDialog(String itemName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to delete "$itemName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                // Note: You may need to add a delete endpoint in the backend
                // For now, we'll just set the rate to 0 or remove from local state
                setState(() {
                  _itemRates.remove(itemName);
                });
                widget.onRatesUpdated();
                if (mounted) Navigator.pop(context);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Item "$itemName" deleted'),
                    backgroundColor: Colors.orange,
                  ),
                );
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete item: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
