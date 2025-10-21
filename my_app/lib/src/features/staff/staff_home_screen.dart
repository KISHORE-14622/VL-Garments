import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/stitch.dart';
import '../../core/models/user.dart';
import '../../core/models/worker.dart';
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
  bool _isLoadingWorkers = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStaffData();
  }

  Future<void> _loadStaffData() async {
    setState(() => _isLoadingWorkers = true);
    await Future.wait([
      widget.dataService.fetchRates(), // Load rates and categories
      widget.dataService.fetchWorkers(),
    ]);
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

  List<StitchEntry> _getFilteredEntries() {
    if (_selectedWorkerId == null) return [];
    
    print('🔍 Filtering entries:');
    print('Selected worker ID: $_selectedWorkerId');
    print('Total entries in service: ${widget.dataService.stitchEntries.length}');
    
    final myEntries = widget.dataService.stitchEntries.where((e) {
      print('Entry workerId: ${e.workerId}, matches: ${e.workerId == _selectedWorkerId}');
      return e.workerId == _selectedWorkerId;
    }).toList();
    
    print('Entries for this worker: ${myEntries.length}');
    
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
    
    // Show worker selector if no worker is selected
    if (_selectedWorkerId == null) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text('Select Worker'),
          elevation: 0,
          actions: [
            IconButton(
              onPressed: () => widget.authService.signOut(),
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
            ),
          ],
        ),
        body: activeWorkers.isEmpty
            ? _buildNoWorkersState()
            : _buildWorkerSelector(activeWorkers),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showAddWorkerDialog,
          icon: const Icon(Icons.add),
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
        actions: [
          IconButton(
            onPressed: () => widget.authService.signOut(),
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.add_circle), text: 'Add Entry'),
            Tab(icon: Icon(Icons.analytics), text: 'Statistics'),
          ],
        ),
      ),
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
                colors: [Theme.of(context).primaryColor, Theme.of(context).primaryColor.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).primaryColor.withOpacity(0.3),
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
                
                // Category Selection
                const Text(
                  'Select Category',
                  style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: widget.dataService.categories.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: Text(
                            'Loading categories...',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : DropdownButton<String>(
                          value: _selectedCategory,
                          isExpanded: true,
                          underline: const SizedBox(),
                          items: widget.dataService.categories
                              .map((c) => DropdownMenuItem(
                                    value: c.id,
                                    child: Row(
                                      children: [
                                        Icon(Icons.category, color: Theme.of(context).primaryColor, size: 20),
                                        const SizedBox(width: 12),
                                        Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() => _selectedCategory = v ?? _selectedCategory),
                        ),
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
              final categoryName = widget.dataService.categories
                  .firstWhere((c) => c.id == entry.categoryId, orElse: () => widget.dataService.categories.first)
                  .name;
              return _buildEntryCard(entry, categoryName);
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
              final categoryName = widget.dataService.categories
                  .firstWhere((c) => c.id == entry.key, orElse: () => widget.dataService.categories.first)
                  .name;
              final percentage = totalProduction > 0 ? (entry.value / totalProduction * 100) : 0.0;
              final rate = widget.dataService.ratePerCategory[entry.key] ?? 0;
              final earnings = rate * entry.value;
              
              return _buildCategoryCard(categoryName, entry.value, percentage, earnings);
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
      selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
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
              color: Colors.blue.withOpacity(0.1),
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

  Widget _buildWorkerSelector(List<Worker> workerList) {
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
                  Theme.of(context).primaryColor.withOpacity(0.7),
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
          Text(
            'Workers',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
          ),
          const SizedBox(height: 16),
          ...workerList.map((worker) {
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
                      color: Colors.black.withOpacity(0.05),
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
                            Theme.of(context).primaryColor.withOpacity(0.7),
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
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.blue),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
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
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAddWorkerDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Worker'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
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

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Worker'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Worker Name *',
                  hintText: 'e.g., Ravi Kumar',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number *',
                  hintText: 'e.g., 9876543210',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: 'Address (Optional)',
                  hintText: 'e.g., Chennai',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final phone = phoneController.text.trim();
              final address = addressController.text.trim();

              if (name.isEmpty || phone.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill in name and phone number'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.pop(context);

              // Show loading
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Adding worker...'),
                  duration: Duration(seconds: 1),
                ),
              );

              final worker = Worker(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: name,
                phoneNumber: phone,
                address: address,
                joinedDate: DateTime.now(),
                isActive: true,
              );

              final added = await widget.dataService.addWorker(worker);

              if (added != null) {
                await _loadStaffData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Worker "$name" added successfully!'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to add worker'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
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

  void _addEntry() async {
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
    
    // Show loading
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Saving entry...'),
        duration: Duration(seconds: 1),
      ),
    );
    
    // Create entry
    final entry = StitchEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      workerId: _selectedWorkerId!,
      categoryId: _selectedCategory,
      quantity: qty,
      date: DateTime.now(),
    );
    
    // Save to backend
    final savedEntry = await widget.dataService.addStitchEntry(entry);
    
    if (savedEntry != null) {
      final worker = widget.dataService.getWorkerById(_selectedWorkerId!);
      final categoryName = widget.dataService.categories
          .firstWhere((c) => c.id == _selectedCategory, orElse: () => widget.dataService.categories.first)
          .name;
      final rate = widget.dataService.ratePerCategory[_selectedCategory] ?? 0;
      final earnings = qty * rate;
      
      // Update UI - reset quantity and refresh entries list
      if (mounted) {
        setState(() {
          _qtyController.text = '1';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${worker?.name ?? "Worker"}: Added $qty $categoryName(s) - ₹${earnings.toStringAsFixed(0)} earned!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save entry. Please try again.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}


