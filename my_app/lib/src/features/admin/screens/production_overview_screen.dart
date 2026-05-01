import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../../../core/services/data_service.dart';
import '../../../core/models/stitch.dart';
import '../../../core/models/worker.dart';
import '../../../core/utils/export_helper.dart';
import 'gst_billing_screen.dart';

class ProductionOverviewScreen extends StatefulWidget {
  final DataService dataService;

  const ProductionOverviewScreen({super.key, required this.dataService});

  @override
  State<ProductionOverviewScreen> createState() => _ProductionOverviewScreenState();
}

class _ProductionOverviewScreenState extends State<ProductionOverviewScreen> {
  String _selectedPeriod = 'all';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try { await widget.dataService.fetchWorkers(); } catch (_) {}
    try { await widget.dataService.fetchWorkerCategories(); } catch (_) {}
    try { await widget.dataService.syncRatesFromServer(); } catch (_) {}
    try { await widget.dataService.fetchAllProduction(); } catch (_) {}
    try { await widget.dataService.fetchCompletedProduction(); } catch (_) {}
    try { await widget.dataService.fetchBrands(); } catch (_) {}
    try { await widget.dataService.fetchGstSettings(); } catch (_) {}
    if (!mounted) return;
    setState(() => _loading = false);
  }

  String _categoryDisplayName(String catId) {
    if (catId.contains('_')) {
      final parts = catId.split('_');
      final wcId = parts.first;
      final itemName = parts.sublist(1).join(' ');
      try {
        final wc = widget.dataService.workerCategories.firstWhere((c) => c.id == wcId);
        return '${_titleCase(itemName)} (${wc.name})';
      } catch (_) {}
      return _titleCase(itemName);
    }
    return _titleCase(catId.replaceAll('_', ' '));
  }

  String _titleCase(String s) {
    if (s.isEmpty) return s;
    return s.split(' ').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');
  }

  String _workerName(String workerId) {
    final w = widget.dataService.getWorkerById(workerId);
    return w?.name ?? 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text('Production Overview'),
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text('Production Overview'),
          elevation: 0,
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Worker Production'),
              Tab(text: 'Company Revenue'),
              Tab(icon: Icon(Icons.receipt_long, size: 18), text: 'GST & Billing'),
            ],
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
          ),
        ),
        body: TabBarView(
          children: [
            _buildWorkerProductionTab(),
            _buildCompanyRevenueTab(),
            GstBillingTab(dataService: widget.dataService),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkerProductionTab() {
    final entries = widget.dataService.stitchEntries;
    final filteredEntries = _filterEntriesByPeriod(entries);

    // Calculate statistics
    final totalProduction = filteredEntries.fold<int>(0, (sum, e) => sum + e.quantity);
    final uniqueWorkers = filteredEntries.map((e) => e.workerId).toSet().length;
    final totalValue = widget.dataService.calculateAmountForEntries(filteredEntries);

    // Group by category
    final categoryStats = <String, int>{};
    for (var entry in filteredEntries) {
      categoryStats[entry.categoryId] = ((categoryStats[entry.categoryId] ?? 0) + entry.quantity).toInt();
    }

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              // Period Filter
              Row(
                children: [
                  _buildPeriodChip('All Time', 'all'),
                  const SizedBox(width: 8),
                  _buildPeriodChip('This Week', 'week'),
                  const SizedBox(width: 8),
                  _buildPeriodChip('This Month', 'month'),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.file_download_outlined, color: Color(0xFF4A90E2)),
                    tooltip: 'Export Production',
                    onPressed: () => ExportHelper.exportToExcel(context, widget.dataService, 'production'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Summary Stats
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Total Production',
                      totalProduction.toString(),
                      Icons.production_quantity_limits,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      'Active Workers',
                      uniqueWorkers.toString(),
                      Icons.people,
                      Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildStatCard(
                'Total Value',
                '₹${totalValue.toStringAsFixed(0)}',
                Icons.currency_rupee,
                Colors.purple,
                fullWidth: true,
              ),
              const SizedBox(height: 32),

              // Category Breakdown
              Text(
                'Production by Category',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
              ),
              const SizedBox(height: 16),

              if (categoryStats.isEmpty)
                _buildEmptyState()
              else
                ...categoryStats.entries.map((entry) {
                  final categoryName = _categoryDisplayName(entry.key);
                  final percentage = totalProduction > 0
                      ? (entry.value / totalProduction * 100)
                      : 0.0;
                  return _buildCategoryCard(
                    categoryName,
                    entry.value,
                    percentage,
                  );
                }).toList(),

              const SizedBox(height: 32),

              // Weekly Trend Chart
              Text(
                'Weekly Trend',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
              ),
              const SizedBox(height: 16),
              _buildWeeklyChart(entries),

              const SizedBox(height: 32),

              // Recent Entries
              Text(
                'Recent Production Entries',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
              ),
              const SizedBox(height: 16),

              ...filteredEntries.take(10).map((entry) {
                final categoryName = _categoryDisplayName(entry.categoryId);
                return _buildEntryCard(entry, categoryName);
              }).toList(),
            ],
          ),
        ),
    );
  }

  Widget _buildWeeklyChart(List<StitchEntry> entries) {
    final now = DateTime.now();
    final List<DateTime> days = List.generate(7, (i) => DateTime(now.year, now.month, now.day - (6 - i)));
    
    final Map<DateTime, int> dailyCounts = { for (var d in days) d : 0 };
    for (var e in entries) {
      final eDay = DateTime(e.date.year, e.date.month, e.date.day);
      if (dailyCounts.containsKey(eDay)) {
        dailyCounts[eDay] = dailyCounts[eDay]! + e.quantity;
      }
    }
    
    int maxCount = dailyCounts.values.isEmpty ? 0 : dailyCounts.values.reduce(math.max);
    if (maxCount == 0) maxCount = 1; // avoid division by zero
    
    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Last 7 Days', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: days.map((day) {
                final count = dailyCounts[day]!;
                final heightFactor = count / maxCount;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(count > 0 ? count.toString() : '', style: const TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Container(
                      width: 24,
                      height: 100 * heightFactor, // base height is 100
                      decoration: BoxDecoration(
                        color: count > 0 ? Colors.blue.withOpacity(0.8) : Colors.grey.withOpacity(0.2),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(DateFormat('E').format(day), style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: day.day == now.day ? FontWeight.bold : FontWeight.normal)),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ========== COMPANY REVENUE TAB ==========

  void _showBrandsManagerDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        final nameController = TextEditingController();
        final rateController = TextEditingController();
        final costController = TextEditingController();
        String? editingBrandId;

        return StatefulBuilder(builder: (context, setStateDialog) {
          final brands = widget.dataService.brands;

          return AlertDialog(
            title: const Text('Manage Brands'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (brands.isNotEmpty) ...[
                    ListView.builder(
                      shrinkWrap: true,
                      itemCount: brands.length,
                      itemBuilder: (context, index) {
                        final b = brands[index];
                        return ListTile(
                          title: Text(b.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Sell: ₹${b.sellingRate} | Cost: ₹${b.costPerUnit}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () {
                                  setStateDialog(() {
                                    editingBrandId = b.id;
                                    nameController.text = b.name;
                                    rateController.text = b.sellingRate.toStringAsFixed(0);
                                    costController.text = b.costPerUnit.toStringAsFixed(0);
                                  });
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () async {
                                  final success = await widget.dataService.deleteBrand(b.id);
                                  if (success) {
                                    if (editingBrandId == b.id) {
                                      editingBrandId = null;
                                      nameController.clear();
                                      rateController.clear();
                                      costController.clear();
                                    }
                                    setStateDialog(() {});
                                    setState(() {});
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const Divider(),
                  ],
                  Text(editingBrandId == null ? 'Add New Brand' : 'Edit Brand', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Brand Name', isDense: true)),
                  const SizedBox(height: 8),
                  TextField(controller: rateController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Selling Rate (₹)', isDense: true)),
                  const SizedBox(height: 8),
                  TextField(controller: costController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Cost Per Unit (₹)', isDense: true)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (editingBrandId != null)
                        TextButton(
                          onPressed: () {
                            setStateDialog(() {
                              editingBrandId = null;
                              nameController.clear();
                              rateController.clear();
                              costController.clear();
                            });
                          },
                          child: const Text('Cancel'),
                        ),
                      ElevatedButton(
                        onPressed: () async {
                          if (nameController.text.isEmpty) return;
                          final sell = double.tryParse(rateController.text) ?? 0;
                          final cost = double.tryParse(costController.text) ?? 0;
                          if (editingBrandId == null) {
                            final res = await widget.dataService.addBrand(name: nameController.text, sellingRate: sell, costPerUnit: cost);
                            if (res != null) {
                              nameController.clear();
                              rateController.clear();
                              costController.clear();
                              setStateDialog(() {});
                              setState(() {});
                            }
                          } else {
                            final res = await widget.dataService.updateBrand(editingBrandId!, name: nameController.text, sellingRate: sell, costPerUnit: cost);
                            if (res != null) {
                              editingBrandId = null;
                              nameController.clear();
                              rateController.clear();
                              costController.clear();
                              setStateDialog(() {});
                              setState(() {});
                            }
                          }
                        },
                        child: Text(editingBrandId == null ? 'Add Brand' : 'Update Brand'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            ],
          );
        });
      },
    );
  }

  void _showAddCompletedProductDialog(double defaultCostPerUnit) {
    final qtyController = TextEditingController();
    final rateController = TextEditingController();
    final costController = TextEditingController(text: defaultCostPerUnit.toStringAsFixed(0));
    String? selectedBrandId;
    
    // Find the last used selling rate, or default to 0
    double lastRate = 0;
    if (widget.dataService.completedProducts.isNotEmpty) {
      lastRate = widget.dataService.completedProducts.first.sellingRate;
    }
    if (lastRate > 0) {
      rateController.text = lastRate.toStringAsFixed(0);
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Log Completed Products'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.dataService.brands.isNotEmpty)
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Select Brand (Optional)',
                          prefixIcon: Icon(Icons.branding_watermark),
                        ),
                        value: selectedBrandId,
                        items: [
                          const DropdownMenuItem(value: null, child: Text('No Brand')),
                          ...widget.dataService.brands.map((b) => DropdownMenuItem(
                            value: b.id,
                            child: Text(b.name),
                          )),
                        ],
                        onChanged: (val) {
                          setStateDialog(() {
                            selectedBrandId = val;
                            if (val != null) {
                              final b = widget.dataService.brands.firstWhere((br) => br.id == val);
                              rateController.text = b.sellingRate.toStringAsFixed(0);
                              costController.text = b.costPerUnit.toStringAsFixed(0);
                            }
                          });
                        },
                      ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: qtyController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Quantity Completed',
                        prefixIcon: Icon(Icons.inventory_2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: rateController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Selling Rate per Unit (₹)',
                        prefixIcon: Icon(Icons.currency_rupee),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: costController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Cost per Unit (₹)',
                        prefixIcon: Icon(Icons.build),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () async {
                    final qty = int.tryParse(qtyController.text);
                    final rate = double.tryParse(rateController.text);
                    final cost = double.tryParse(costController.text);
                    if (qty == null || qty <= 0 || rate == null || rate < 0 || cost == null || cost < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid input')));
                      return;
                    }
                    Navigator.pop(ctx);
                    
                    String brandName = '';
                    if (selectedBrandId != null) {
                      brandName = widget.dataService.brands.firstWhere((b) => b.id == selectedBrandId).name;
                    }
                    
                    final res = await widget.dataService.addCompletedProduction(
                      date: DateTime.now(),
                      quantity: qty,
                      sellingRate: rate,
                      costPerUnit: cost,
                      brandName: brandName,
                    );
                    
                    if (res != null) {
                      setState(() {}); // refresh tab
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logged successfully'), backgroundColor: Colors.green));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to log'), backgroundColor: Colors.red));
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  Widget _buildCompanyRevenueTab() {
    final completed = widget.dataService.completedProducts;
    final costPerUnit = widget.dataService.calculateCostPerUnit();
    
    int totalQty = 0;
    double totalRevenue = 0;
    double totalCost = 0;
    
    for (var cp in completed) {
      totalQty += cp.quantity;
      totalRevenue += cp.totalRevenue;
      totalCost += cp.totalCost;
    }
    
    final totalProfit = totalRevenue - totalCost;

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Company Revenue Overview',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.settings, color: Colors.grey),
                      tooltip: 'Manage Brands',
                      onPressed: _showBrandsManagerDialog,
                    ),
                    IconButton(
                      icon: const Icon(Icons.file_download_outlined, color: Color(0xFF4A90E2)),
                      tooltip: 'Export Revenue',
                      onPressed: () => ExportHelper.exportToExcel(context, widget.dataService, 'revenue'),
                    ),
                    FilledButton.icon(
                      onPressed: () => _showAddCompletedProductDialog(costPerUnit),
                      icon: const Icon(Icons.add),
                      label: const Text('Log'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Stats Grid
            Row(
              children: [
                Expanded(child: _buildStatCard('Total Products', totalQty.toString(), Icons.check_circle_outline, Colors.blue)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard('Total Cost', '₹${totalCost.toStringAsFixed(0)}', Icons.build, Colors.orange)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildStatCard('Total Revenue', '₹${totalRevenue.toStringAsFixed(0)}', Icons.arrow_upward, Colors.green)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard('Total Profit', '₹${totalProfit.toStringAsFixed(0)}', Icons.account_balance_wallet, Colors.purple)),
              ],
            ),
            
            const SizedBox(height: 32),
            Text(
              'Recent Completed Batches',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
            ),
            const SizedBox(height: 16),
            
            if (completed.isEmpty)
              _buildEmptyState()
            else
              ...completed.take(15).map((cp) {
                final dateFormat = DateFormat('MMM dd, yyyy HH:mm');
                final profit = cp.profit;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.inventory, color: Colors.green, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${cp.quantity} Units ${cp.brandName.isNotEmpty ? "(${cp.brandName})" : ""}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  Text(
                                    dateFormat.format(cp.date),
                                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Delete Entry?'),
                                  content: const Text('Are you sure you want to delete this completed batch?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                final res = await widget.dataService.deleteCompletedProduction(cp.id);
                                if (res) setState(() {});
                              }
                            },
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildMiniStat('Revenue', '₹${cp.totalRevenue.toStringAsFixed(0)}', Colors.green),
                          _buildMiniStat('Cost', '₹${cp.totalCost.toStringAsFixed(0)}', Colors.orange),
                          _buildMiniStat('Profit', '₹${profit.toStringAsFixed(0)}', Colors.purple),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  List<StitchEntry> _filterEntriesByPeriod(List<StitchEntry> entries) {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 'week':
        final weekAgo = now.subtract(const Duration(days: 7));
        return entries.where((e) => e.date.isAfter(weekAgo)).toList();
      case 'month':
        final monthAgo = DateTime(now.year, now.month - 1, now.day);
        return entries.where((e) => e.date.isAfter(monthAgo)).toList();
      default:
        return entries;
    }
  }

  Widget _buildPeriodChip(String label, String value) {
    final isSelected = _selectedPeriod == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedPeriod = value;
        });
      },
      backgroundColor: Colors.white,
      selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
      checkmarkColor: Theme.of(context).primaryColor,
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    bool fullWidth = false,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
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
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(String name, int quantity, double percentage) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                '$quantity units',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percentage / 100,
              minHeight: 8,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${percentage.toStringAsFixed(1)}% of total production',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryCard(StitchEntry entry, String categoryName) {
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.inventory_2, color: Colors.blue, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$categoryName × ${entry.quantity}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Worker: ${_workerName(entry.workerId)}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            dateFormat.format(entry.date),
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.production_quantity_limits, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No Production Data',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Production entries will appear here',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
