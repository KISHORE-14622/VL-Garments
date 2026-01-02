import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/stitch.dart';
import '../../core/models/user.dart';
import '../../core/models/worker.dart';
import '../../core/models/worker_category.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/data_service.dart';

class StaffHomeScreen extends StatefulWidget {
  final AuthService authService;
  final DataService dataService;
  final AppUser user;

  const StaffHomeScreen({super.key, required this.authService, required this.dataService, required this.user});

  @override
  State<StaffHomeScreen> createState() => _StaffHomeScreenState();
}

class _StaffHomeScreenState extends State<StaffHomeScreen> with SingleTickerProviderStateMixin {
  String _selectedCategory = 'shirt';
  final TextEditingController _qtyController = TextEditingController(text: '1');
  String _selectedPeriod = 'today';
  late TabController _tabController;
  String? _selectedWorkerId;
  String? _selectedCategoryId;
  bool _isLoadingWorkers = true;
  String _workerQuery = '';
  String _categoryQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStaffData();
  }

  Future<void> _loadStaffData() async {
    setState(() => _isLoadingWorkers = true);
    await widget.dataService.fetchWorkers();
    await widget.dataService.fetchWorkerCategories();
    try {
      await widget.dataService.syncRatesFromServer();
    } catch (_) {}
    try {
      await widget.dataService.fetchMyProduction();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _isLoadingWorkers = false;
        // Set default category after rates are loaded
        if (widget.dataService.categories.isNotEmpty) {
          _selectedCategory = widget.dataService.categories.first.id;
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  void _showAccountDetails() {
    final u = widget.user;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('My Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [const Icon(Icons.badge), const SizedBox(width: 8), Expanded(child: Text(u.name))]),
            const SizedBox(height: 8),
            Row(children: [const Icon(Icons.email), const SizedBox(width: 8), Expanded(child: Text(u.email))]),
            const SizedBox(height: 8),
            Row(children: [const Icon(Icons.verified_user), const SizedBox(width: 8), Expanded(child: Text(_roleText(u.role)))]),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  String _roleText(UserRole role) {
    final parts = role.toString().split('.');
    return parts.isNotEmpty ? parts.last : role.toString();
  }

  List<StitchEntry> _getFilteredEntries() {
    if (_selectedWorkerId == null) return [];
    
    // debug: filtering entries (removed prints for production)
    
    final myEntries = widget.dataService.stitchEntries.where((e) => e.workerId == _selectedWorkerId).toList();
    
    // debug: entries count removed
    
    final now = DateTime.now();
    
    switch (_selectedPeriod) {
      case 'today':
        final today = DateTime(now.year, now.month, now.day);
        final filtered = myEntries.where((e) => e.date.isAfter(today)).toList();
        print('Today filter: ${filtered.length} entries');
        return filtered;
      case 'week':
        final weekAgo = now.subtract(const Duration(days: 7));
        return myEntries.where((e) => e.date.isAfter(weekAgo)).toList();
      case 'month':
        final monthAgo = DateTime(now.year, now.month - 1, now.day);
        return myEntries.where((e) => e.date.isAfter(monthAgo)).toList();
      default:
        return myEntries;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while fetching workers data
    if (_isLoadingWorkers) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text('Loading...'),
          elevation: 0,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final activeWorkers = widget.dataService.getActiveWorkers();
    final activeCategories = widget.dataService.workerCategories.where((c) => c.isActive).toList();
    
    // Show category selector if no category is selected
    if (_selectedCategoryId == null) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text('Select Category'),
          elevation: 0,
          actions: [
            IconButton(
              onPressed: _showAccountDetails,
              icon: const Icon(Icons.account_circle),
              tooltip: 'My Account',
            ),
          ],
        ),
        drawer: _buildStaffDrawer(),
        body: activeCategories.isEmpty
            ? _buildNoCategoriesState()
            : _buildCategorySelector(activeCategories),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showAddWorkerDialog,
          icon: const Icon(Icons.person_add),
          label: const Text('Add Worker'),
        ),
      );
    }
    
    // Show worker selector if category is selected but no worker is selected
    if (_selectedWorkerId == null) {
      final categoryWorkers = activeWorkers.where((w) => w.category?.id == _selectedCategoryId).toList();
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              setState(() {
                _selectedCategoryId = null;
              });
            },
          ),
          title: Text(_getCategoryName(_selectedCategoryId!)),
          elevation: 0,
          actions: [
            IconButton(
              onPressed: _showAccountDetails,
              icon: const Icon(Icons.account_circle),
              tooltip: 'My Account',
            ),
          ],
        ),
        drawer: _buildStaffDrawer(),
        body: categoryWorkers.isEmpty
            ? _buildNoWorkersInCategoryState()
            : _buildWorkerSelector(categoryWorkers),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showAddWorkerDialog,
          icon: const Icon(Icons.person_add),
          label: const Text('Add Worker'),
        ),
      );
    }
    
    final filteredEntries = _getFilteredEntries();
    final totalAmount = widget.dataService.calculateAmountForEntries(filteredEntries);
    final totalProduction = filteredEntries.fold<int>(0, (sum, e) => sum + e.quantity);

    // Category breakdown
    final categoryStats = <String, int>{};
    for (var entry in filteredEntries) {
      categoryStats[entry.categoryId] = ((categoryStats[entry.categoryId] ?? 0) + entry.quantity).toInt();
    }
    
    final selectedWorker = widget.dataService.getWorkerById(_selectedWorkerId!);
    final workerName = selectedWorker?.name ?? 'Worker';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              _selectedWorkerId = null;
              _selectedCategoryId = null;
            });
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Production Entry', style: TextStyle(fontSize: 20)),
            Text(
              workerName,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.add_circle), text: 'Add Entry'),
            Tab(icon: Icon(Icons.analytics), text: 'Statistics'),
          ],
        ),
      ),
      drawer: _buildStaffDrawer(),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAddEntryTab(filteredEntries),
          _buildStatisticsTab(totalProduction, totalAmount, categoryStats, filteredEntries),
        ],
      ),
    );
  }

  Widget _buildAddEntryTab(List<StitchEntry> entries) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick Add Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Theme.of(context).primaryColor, Theme.of(context).primaryColor.withValues(alpha: 0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.add_task, color: Colors.white, size: 28),
                    SizedBox(width: 12),
                    Text(
                      'Add Production Entry',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Category Selection (Item Selection)
                Builder(
                  builder: (context) {
                    final workerItems = _getWorkerItemCategories();
                    
                    // Set initial value if not set or invalid
                    if (workerItems.isNotEmpty && 
                        !workerItems.any((item) => item['id'] == _selectedCategory)) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        setState(() {
                          _selectedCategory = workerItems.first['id']!;
                        });
                      });
                    }
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select Item',
                          style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: workerItems.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(12.0),
                                  child: Text(
                                    'No items configured for this category',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                )
                              : DropdownButtonFormField<String>(
                                  value: workerItems.any((item) => item['id'] == _selectedCategory) 
                                      ? _selectedCategory 
                                      : workerItems.first['id'],
                                  isExpanded: true,
                                  items: workerItems
                                      .map((item) => DropdownMenuItem(
                                            value: item['id'],
                                            child: Row(
                                              children: [
                                                Icon(Icons.checkroom, color: Theme.of(context).primaryColor, size: 20),
                                                const SizedBox(width: 12),
                                                Text(item['name']!, style: const TextStyle(fontWeight: FontWeight.w600)),
                                              ],
                                            ),
                                          ))
                                      .toList(),
                                  onChanged: (v) => setState(() => _selectedCategory = v ?? _selectedCategory),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                  ),
                                ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                
                // Quantity Input
                const Text(
                  'Quantity',
                  style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        final current = int.tryParse(_qtyController.text) ?? 1;
                        if (current > 1) {
                          _qtyController.text = (current - 1).toString();
                        }
                      },
                      icon: const Icon(Icons.remove_circle, color: Colors.white),
                      iconSize: 32,
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: _qtyController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: '0',
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        final current = int.tryParse(_qtyController.text) ?? 0;
                        _qtyController.text = (current + 1).toString();
                      },
                      icon: const Icon(Icons.add_circle, color: Colors.white),
                      iconSize: 32,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _addEntry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Theme.of(context).primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Add Entry',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Recent Entries
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Entries',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
              ),
              DropdownButton<String>(
                value: _selectedPeriod,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'today', child: Text('Today')),
                  DropdownMenuItem(value: 'week', child: Text('This Week')),
                  DropdownMenuItem(value: 'month', child: Text('This Month')),
                  DropdownMenuItem(value: 'all', child: Text('All Time')),
                ],
                onChanged: (v) => setState(() => _selectedPeriod = v ?? _selectedPeriod),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          if (entries.isEmpty)
            _buildEmptyState()
          else
            ...entries.reversed.take(20).map((entry) {
              final itemName = _getItemName(entry.categoryId);
              return _buildEntryCard(entry, itemName);
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildStatisticsTab(int totalProduction, double totalAmount, Map<String, int> categoryStats, List<StitchEntry> entries) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period Filter
          Row(
            children: [
              _buildPeriodChip('Today', 'today'),
              const SizedBox(width: 8),
              _buildPeriodChip('Week', 'week'),
              const SizedBox(width: 8),
              _buildPeriodChip('Month', 'month'),
              const SizedBox(width: 8),
              _buildPeriodChip('All', 'all'),
            ],
          ),
          const SizedBox(height: 24),
          
          // Summary Cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Production',
                  totalProduction.toString(),
                  Icons.inventory_2,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Total Earnings',
                  '₹${totalAmount.toStringAsFixed(0)}',
                  Icons.currency_rupee,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStatCard(
            'Total Entries',
            entries.length.toString(),
            Icons.receipt_long,
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
              final itemName = _getItemName(entry.key);
              final percentage = totalProduction > 0 ? (entry.value / totalProduction * 100) : 0.0;
              final rate = widget.dataService.ratePerCategory[entry.key] ?? 0;
              final earnings = rate * entry.value;
              
              return _buildCategoryCard(itemName, entry.value, percentage, earnings);
            }).toList(),
        ],
      ),
    );
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
      selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
      checkmarkColor: Theme.of(context).primaryColor,
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, {bool fullWidth = false}) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(String name, int quantity, double percentage, double earnings) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
              Row(
                children: [
                  Icon(Icons.category, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 12),
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              Text(
                '$quantity units',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
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
              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${percentage.toStringAsFixed(1)}% of total',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              Text(
                '₹${earnings.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Colors.green,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEntryCard(StitchEntry entry, String categoryName) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('HH:mm');
    final rate = widget.dataService.ratePerCategory[entry.categoryId] ?? 0;
    final amount = rate * entry.quantity;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.inventory_2, color: Colors.blue, size: 24),
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
                Row(
                  children: [
                    Icon(Icons.production_quantity_limits, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '${entry.quantity} units',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      timeFormat.format(entry.date),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${amount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.green,
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
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No Entries Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start adding production entries to see your statistics',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  String _getCategoryName(String categoryId) {
    final category = widget.dataService.workerCategories.firstWhere(
      (c) => c.id == categoryId,
      orElse: () => widget.dataService.workerCategories.first,
    );
    return category.name;
  }

  // Get filtered item categories for the selected worker
  List<Map<String, String>> _getWorkerItemCategories() {
    if (_selectedWorkerId == null || _selectedCategoryId == null) {
      return [];
    }

    final items = <Map<String, String>>[];
    
    // Filter rates that belong to this worker category
    // Format: workerCategoryId_itemName
    widget.dataService.ratePerCategory.forEach((key, rate) {
      if (key.startsWith('$_selectedCategoryId\_')) {
        // Extract item name from the composite key
        final itemName = key.substring(_selectedCategoryId!.length + 1);
        items.add({
          'id': key,
          'name': itemName,
        });
      }
    });

    return items;
  }

  // Extract item name from composite key (workerCategoryId_itemName)
  String _getItemName(String categoryId) {
    if (categoryId.contains('_')) {
      final parts = categoryId.split('_');
      if (parts.length > 1) {
        return parts.sublist(1).join('_'); // Join in case item name has underscores
      }
    }
    // Fallback to old category system
    try {
      final category = widget.dataService.categories.firstWhere(
        (c) => c.id == categoryId,
      );
      return category.name;
    } catch (e) {
      return categoryId; // Return the ID itself if not found
    }
  }

  Widget _buildCategorySelector(List<WorkerCategory> categoryList) {
    final filtered = _categoryQuery.trim().isEmpty
        ? categoryList
        : categoryList.where((c) {
            final q = _categoryQuery.toLowerCase();
            return c.name.toLowerCase().contains(q);
          }).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).primaryColor,
                  Theme.of(context).primaryColor.withValues(alpha: 0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Icon(Icons.category, color: Colors.white, size: 32),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Category',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Choose a category to view workers',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Search categories
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search categories',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => _categoryQuery = v),
          ),
          const SizedBox(height: 16),
          Text(
            'Categories',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
          ),
          const SizedBox(height: 16),
          if (filtered.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text('No categories found', style: TextStyle(color: Colors.grey[600])),
              ),
            )
          else
            ...filtered.map((category) {
              final workersInCategory = widget.dataService.getActiveWorkers()
                  .where((w) => w.category?.id == category.id)
                  .length;
              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedCategoryId = category.id;
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context).primaryColor,
                              Theme.of(context).primaryColor.withValues(alpha: 0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.category, color: Colors.white, size: 28),
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
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.people, size: 14, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                  '$workersInCategory worker${workersInCategory != 1 ? 's' : ''}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.blue),
                    ],
                  ),
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildWorkerSelector(List<Worker> workerList) {
    final filtered = _workerQuery.trim().isEmpty
        ? workerList
        : workerList.where((w) {
            final q = _workerQuery.toLowerCase();
            return w.name.toLowerCase().contains(q) || w.phoneNumber.toLowerCase().contains(q);
          }).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).primaryColor,
                  Theme.of(context).primaryColor.withValues(alpha: 0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Icon(Icons.people, color: Colors.white, size: 32),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Worker',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Choose a worker to add production entries',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Search workers
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search workers by name or phone',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => _workerQuery = v),
          ),
          const SizedBox(height: 16),
          Text(
            'Workers',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
          ),
          const SizedBox(height: 16),
          if (filtered.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text('No workers found', style: TextStyle(color: Colors.grey[600])),
              ),
            )
          else
            ...filtered.map((worker) {
              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedWorkerId = worker.id;
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).primaryColor,
                            Theme.of(context).primaryColor.withValues(alpha: 0.7),
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white,
                        child: Text(
                          worker.name.substring(0, 1).toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            worker.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                worker.phoneNumber,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.blue),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildNoCategoriesState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No Categories',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add workers with categories to start tracking production',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _showAddWorkerDialog,
              icon: const Icon(Icons.person_add),
              label: const Text('Add Worker'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoWorkersInCategoryState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No Workers in this Category',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add workers to this category to start tracking production',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _showAddWorkerDialog,
              icon: const Icon(Icons.person_add),
              label: const Text('Add Worker'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoWorkersState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No Workers',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add workers to start tracking production',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _showAddWorkerDialog,
              icon: const Icon(Icons.person_add),
              label: const Text('Add Worker'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddWorkerDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    bool isLoading = false;
    String? selectedCategoryId = widget.dataService.workerCategories.isNotEmpty
        ? widget.dataService.workerCategories.first.id
        : null;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Worker'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Worker Name *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: 'Address (Optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.home),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Category', style: Theme.of(context).textTheme.bodySmall),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedCategoryId,
                        items: widget.dataService.workerCategories
                            .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                            .toList(),
                        onChanged: (v) => setDialogState(() => selectedCategoryId = v),
                        decoration: const InputDecoration(border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Add Category',
                      onPressed: () async {
                        final ctrl = TextEditingController();
                        final created = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('New Category'),
                            content: TextField(
                              controller: ctrl,
                              decoration: const InputDecoration(
                                labelText: 'Category name e.g. Tailors, Helpers',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
                            ],
                          ),
                        );
                        if (created == true) {
                          final name = ctrl.text.trim();
                          if (name.isNotEmpty) {
                            final cat = await widget.dataService.createWorkerCategory(name);
                            if (cat != null) {
                              setDialogState(() => selectedCategoryId = cat.id);
                            }
                          }
                        }
                      },
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                final name = nameController.text.trim();
                final phone = phoneController.text.trim();
                final address = addressController.text.trim();
                
                if (name.isEmpty || phone.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill required fields'), backgroundColor: Colors.red),
                  );
                  return;
                }
                
                setDialogState(() => isLoading = true);
                
                try {
                  final worker = Worker(
                    id: '',
                    name: name,
                    phoneNumber: phone,
                    address: address.isEmpty ? null : address,
                    joinedDate: DateTime.now(),
                  );
                  
                  final createdWorker = await widget.dataService.addWorker(worker, categoryId: selectedCategoryId);
                  
                  if (mounted) {
                    Navigator.pop(context);
                    setState(() {});
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(createdWorker != null 
                            ? 'Worker added successfully!' 
                            : 'Failed to add worker'),
                        backgroundColor: createdWorker != null ? Colors.green : Colors.red,
                      ),
                    );
                  }
                } catch (e) {
                  setDialogState(() => isLoading = false);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                    )
                  : const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addEntry() async {
    if (_selectedWorkerId == null) return;
    
    final qty = int.tryParse(_qtyController.text) ?? 0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid quantity'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    try {
      final created = await widget.dataService.addProductionEntry(
        categoryId: _selectedCategory,
        quantity: qty,
        workerIdForUI: _selectedWorkerId,
      );
      if (created != null) {
        await widget.dataService.fetchMyProduction();
        if (!mounted) return;
        setState(() {
          _qtyController.text = '1';
        });
        final worker = widget.dataService.getWorkerById(_selectedWorkerId!);
        final categoryName = widget.dataService.categories
            .firstWhere((c) => c.id == _selectedCategory, orElse: () => widget.dataService.categories.first)
            .name;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${worker?.name ?? "Worker"}: Added $qty $categoryName(s) successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add entry'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to add entry'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildStaffDrawer() {
    return Drawer(
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            // Profile Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).primaryColor,
                    Theme.of(context).primaryColor.withOpacity(0.8),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: CircleAvatar(
                      radius: 35,
                      backgroundColor: Colors.white,
                      child: Text(
                        widget.user.name.substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.user.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.user.email,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Staff Member',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Navigation Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildStaffDrawerItem(
                    icon: Icons.dashboard_rounded,
                    title: 'Dashboard',
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _selectedWorkerId = null;
                        _selectedCategoryId = null;
                      });
                    },
                  ),
                  _buildStaffDrawerItem(
                    icon: Icons.account_circle_rounded,
                    title: 'My Profile',
                    onTap: () {
                      Navigator.pop(context);
                      _showAccountDetails();
                    },
                  ),
                  const Divider(height: 32),
                  _buildStaffDrawerItem(
                    icon: Icons.settings_rounded,
                    title: 'Settings',
                    onTap: () {
                      Navigator.pop(context);
                      // TODO: Navigate to settings screen
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Settings screen coming soon')),
                      );
                    },
                  ),
                  _buildStaffDrawerItem(
                    icon: Icons.logout_rounded,
                    title: 'Logout',
                    textColor: Colors.red,
                    onTap: () {
                      Navigator.pop(context);
                      widget.authService.signOut();
                    },
                  ),
                ],
              ),
            ),

            // App Version
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Version 1.0.0',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: textColor ?? Colors.black87, size: 24),
      title: Text(
        title,
        style: TextStyle(
          color: textColor ?? Colors.black87,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
