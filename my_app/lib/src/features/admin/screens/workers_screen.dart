import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/models/worker.dart';
import '../../../core/models/stitch.dart';
import '../../../core/models/payment.dart';
import '../../../core/services/data_service.dart';

class WorkersScreen extends StatefulWidget {
  final DataService dataService;

  const WorkersScreen({super.key, required this.dataService});

  @override
  State<WorkersScreen> createState() => _WorkersScreenState();
}

class _WorkersScreenState extends State<WorkersScreen> {
  bool _loading = true;
  String _searchQuery = '';
  String? _selectedCategoryFilter;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      await widget.dataService.fetchWorkers();
      await widget.dataService.fetchWorkerCategories();
      await widget.dataService.fetchAllProduction();
      await widget.dataService.fetchPayments();
      await widget.dataService.syncRatesFromServer();
    } catch (e) {
      print('Error loading data: $e');
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Map<String, dynamic> _calculateWorkerStats(Worker worker) {
    // Get all production entries for this worker
    final workerEntries = widget.dataService.stitchEntries
        .where((entry) => entry.workerId == worker.id)
        .toList();

    // Calculate total earned
    final totalEarned = widget.dataService.calculateAmountForEntries(workerEntries);

    // Calculate total paid
    final paidPayments = widget.dataService.payments
        .where((p) => p.workerId == worker.id && p.status.toString().contains('paid'))
        .toList();
    final totalPaid = paidPayments.fold<double>(0, (sum, p) => sum + p.amount);

    // Calculate pending
    final pendingAmount = totalEarned - totalPaid;

    // Get work days
    final workDays = workerEntries.map((e) => e.date).toSet().length;

    // Get total production
    final totalProduction = workerEntries.fold<int>(0, (sum, e) => sum + e.quantity);

    return {
      'totalEarned': totalEarned,
      'totalPaid': totalPaid,
      'pendingAmount': pendingAmount,
      'workDays': workDays,
      'totalProduction': totalProduction,
      'entries': workerEntries,
      'payments': paidPayments,
    };
  }

  List<Worker> _getFilteredWorkers() {
    var workers = widget.dataService.workers;

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      workers = workers.where((w) {
        return w.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            w.phoneNumber.contains(_searchQuery);
      }).toList();
    }

    // Filter by category
    if (_selectedCategoryFilter != null) {
      workers = workers.where((w) => w.category?.id == _selectedCategoryFilter).toList();
    }

    return workers;
  }

  void _showAddWorkerDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final addressController = TextEditingController();
    final notesController = TextEditingController();
    final wageController = TextEditingController();
    String? selectedCategoryId;
    final cats = widget.dataService.workerCategories;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDlg) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.person_add, color: Theme.of(context).primaryColor),
                ),
                const SizedBox(width: 12),
                const Text('Add Worker'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Name *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.phone),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.email),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (cats.isNotEmpty)
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.category),
                      ),
                      value: selectedCategoryId,
                      items: cats.map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name),
                      )).toList(),
                      onChanged: (v) => setDlg(() => selectedCategoryId = v),
                    ),
                  if (cats.isNotEmpty) const SizedBox(height: 14),
                  TextField(
                    controller: wageController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Daily Wage (₹)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.currency_rupee),
                      hintText: 'e.g. 300',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: addressController,
                    decoration: InputDecoration(
                      labelText: 'Address',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.location_on),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: notesController,
                    decoration: InputDecoration(
                      labelText: 'Notes',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.note),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: () async {
                  final name = nameController.text.trim();
                  final phone = phoneController.text.trim();
                  if (name.isEmpty || phone.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Name and phone are required')),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  setState(() => _loading = true);

                  final worker = Worker(
                    id: '',
                    name: name,
                    phoneNumber: phone,
                    email: emailController.text.trim().isEmpty ? null : emailController.text.trim(),
                    address: addressController.text.trim().isEmpty ? null : addressController.text.trim(),
                    notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                    dailyWage: double.tryParse(wageController.text.trim()) ?? 0,
                    joinedDate: DateTime.now(),
                  );

                  final result = await widget.dataService.addWorker(worker, categoryId: selectedCategoryId);
                  if (result != null) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Worker "${result.name}" added successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Failed to add worker'), backgroundColor: Colors.red),
                      );
                    }
                  }
                  await _loadData();
                },
                icon: const Icon(Icons.check),
                label: const Text('Add'),
              ),
            ],
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredWorkers = _getFilteredWorkers();
    final categories = widget.dataService.workerCategories;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black54),
        title: const Text(
          'Workers',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddWorkerDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Worker'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search and Filter Section
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Search Bar
                      TextField(
                        onChanged: (value) => setState(() => _searchQuery = value),
                        decoration: InputDecoration(
                          hintText: 'Search by name or phone...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Category Filter Chips
                      if (categories.isNotEmpty)
                        SizedBox(
                          height: 40,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: FilterChip(
                                  label: const Text('All'),
                                  selected: _selectedCategoryFilter == null,
                                  onSelected: (selected) {
                                    setState(() => _selectedCategoryFilter = null);
                                  },
                                  selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
                                  checkmarkColor: Theme.of(context).primaryColor,
                                ),
                              ),
                              ...categories.map((category) {
                                final count = widget.dataService.workers
                                    .where((w) => w.category?.id == category.id)
                                    .length;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: FilterChip(
                                    label: Text('${category.name} ($count)'),
                                    selected: _selectedCategoryFilter == category.id,
                                    onSelected: (selected) {
                                      setState(() {
                                        _selectedCategoryFilter = selected ? category.id : null;
                                      });
                                    },
                                    selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
                                    checkmarkColor: Theme.of(context).primaryColor,
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // Workers List
                Expanded(
                  child: filteredWorkers.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredWorkers.length,
                          itemBuilder: (context, index) {
                            final worker = filteredWorkers[index];
                            final stats = _calculateWorkerStats(worker);
                            return _buildWorkerCard(worker, stats);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Workers Found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or filters',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkerCard(Worker worker, Map<String, dynamic> stats) {
    final pendingAmount = stats['pendingAmount'] as double;
    final totalEarned = stats['totalEarned'] as double;
    final totalPaid = stats['totalPaid'] as double;
    final workDays = stats['workDays'] as int;
    final totalProduction = stats['totalProduction'] as int;

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
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showWorkerDetails(worker, stats),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: pendingAmount > 0 ? Colors.orange : Colors.green,
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                    child: Text(
                      worker.name.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Worker Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        worker.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (worker.category != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.purple.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                worker.category!.name,
                                style: const TextStyle(
                                  color: Colors.purple,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                worker.phoneNumber,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          if (worker.dailyWage > 0)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.currency_rupee, size: 13, color: Colors.teal[600]),
                                Text(
                                  '${worker.dailyWage.toStringAsFixed(0)}/day',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.teal[600],
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildQuickStat(
                            Icons.work_outline,
                            '$workDays days',
                            Colors.blue,
                          ),
                          const SizedBox(width: 12),
                          _buildQuickStat(
                            Icons.inventory_2_outlined,
                            '$totalProduction units',
                            Colors.green,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Pending Amount Badge
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (pendingAmount > 0) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '₹${pendingAmount.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                            const Text(
                              'Pending',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.green,
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Paid',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStat(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  void _showWorkerDetails(Worker worker, Map<String, dynamic> stats) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkerDetailsScreen(
          worker: worker,
          stats: stats,
          dataService: widget.dataService,
        ),
      ),
    );
  }
}

// Worker Details Screen
class WorkerDetailsScreen extends StatefulWidget {
  final Worker worker;
  final Map<String, dynamic> stats;
  final DataService dataService;

  const WorkerDetailsScreen({
    super.key,
    required this.worker,
    required this.stats,
    required this.dataService,
  });

  @override
  State<WorkerDetailsScreen> createState() => _WorkerDetailsScreenState();
}

class _WorkerDetailsScreenState extends State<WorkerDetailsScreen> {
  late Worker _worker;
  late Map<String, dynamic> _stats;

  @override
  void initState() {
    super.initState();
    _worker = widget.worker;
    _stats = widget.stats;
  }

  String _getItemName(String categoryId) {
    if (categoryId.contains('_')) {
      final parts = categoryId.split('_');
      if (parts.length > 1) {
        return parts.sublist(1).join('_');
      }
    }
    return categoryId;
  }

  void _showSetWageDialog() {
    final wageController = TextEditingController(
      text: _worker.dailyWage > 0 ? _worker.dailyWage.toStringAsFixed(0) : '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.currency_rupee, color: Colors.teal),
            ),
            const SizedBox(width: 12),
            const Text('Set Daily Wage'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Worker: ${_worker.name}', style: TextStyle(color: Colors.grey[700], fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: wageController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Daily Wage (₹)',
                prefixIcon: const Icon(Icons.currency_rupee),
                hintText: 'e.g. 500',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Full day = full wage. Half day = 50%. Absent = ₹0.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton.icon(
            onPressed: () async {
              final wage = double.tryParse(wageController.text.trim());
              if (wage == null || wage < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid amount')),
                );
                return;
              }
              Navigator.pop(ctx);
              final updated = await widget.dataService.updateWorker(_worker.id, {'dailyWage': wage});
              if (updated != null && mounted) {
                setState(() => _worker = updated);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Daily wage updated to ₹${wage.toStringAsFixed(0)}/day'),
                    backgroundColor: Colors.teal,
                  ),
                );
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to update wage'), backgroundColor: Colors.red),
                );
              }
            },
            icon: const Icon(Icons.check),
            label: const Text('Save'),
            style: FilledButton.styleFrom(backgroundColor: Colors.teal),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingAmount = _stats['pendingAmount'] as double;
    final totalEarned = _stats['totalEarned'] as double;
    final totalPaid = _stats['totalPaid'] as double;
    final workDays = _stats['workDays'] as int;
    final totalProduction = _stats['totalProduction'] as int;
    final entries = _stats['entries'] as List<StitchEntry>;
    final payments = _stats['payments'] as List<WorkerPayment>;
    final dateFormat = DateFormat('MMM dd, yyyy');

    // Calculate item breakdown
    final itemBreakdown = <String, Map<String, dynamic>>{};
    for (var entry in entries) {
      final itemKey = entry.categoryId;
      if (!itemBreakdown.containsKey(itemKey)) {
        itemBreakdown[itemKey] = {
          'quantity': 0,
          'rate': widget.dataService.ratePerCategory[itemKey] ?? 0.0,
          'amount': 0.0,
        };
      }
      final rate = widget.dataService.ratePerCategory[itemKey] ?? 0.0;
      itemBreakdown[itemKey]!['quantity'] = (itemBreakdown[itemKey]!['quantity'] as int) + entry.quantity;
      itemBreakdown[itemKey]!['amount'] = (itemBreakdown[itemKey]!['amount'] as double) + (rate * entry.quantity);
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black54),
        title: Text(
          _worker.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _showSetWageDialog,
            icon: const Icon(Icons.currency_rupee_rounded, color: Colors.teal),
            tooltip: 'Set Daily Wage',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Card
          Container(
            padding: const EdgeInsets.all(20),
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
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).primaryColor,
                      width: 3,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                    child: Text(
                      _worker.name.substring(0, 1).toUpperCase(),
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
                  _worker.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                // Daily wage badge
                if (_worker.dailyWage > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.schedule_rounded, size: 14, color: Colors.teal),
                        const SizedBox(width: 4),
                        Text(
                          '₹${_worker.dailyWage.toStringAsFixed(0)}/day',
                          style: const TextStyle(
                            color: Colors.teal,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  GestureDetector(
                    onTap: _showSetWageDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_circle_outline, size: 14, color: Colors.orange),
                          SizedBox(width: 4),
                          Text(
                            'Tap to set daily wage',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_worker.category != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _worker.category!.name,
                      style: const TextStyle(
                        color: Colors.purple,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                _buildInfoRow(Icons.phone, 'Phone', _worker.phoneNumber),
                const SizedBox(height: 12),
                _buildInfoRow(Icons.email, 'Email', _worker.email ?? 'N/A'),
                const SizedBox(height: 12),
                _buildInfoRow(
                  Icons.calendar_today,
                  'Work Days',
                  '$workDays days',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Financial Summary
          Container(
            padding: const EdgeInsets.all(20),
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
                const Row(
                  children: [
                    Icon(Icons.account_balance_wallet, color: Colors.black87),
                    SizedBox(width: 12),
                    Text(
                      'Financial Summary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildFinancialCard(
                        'Total Earned',
                        '₹${totalEarned.toStringAsFixed(0)}',
                        Colors.blue,
                        Icons.trending_up,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildFinancialCard(
                        'Total Paid',
                        '₹${totalPaid.toStringAsFixed(0)}',
                        Colors.green,
                        Icons.check_circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildFinancialCard(
                        'Pending',
                        '₹${pendingAmount.toStringAsFixed(0)}',
                        Colors.orange,
                        Icons.pending_actions,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildFinancialCard(
                        'Production',
                        '$totalProduction units',
                        Colors.purple,
                        Icons.inventory_2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Work Items Breakdown
          if (itemBreakdown.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(20),
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
                  const Row(
                    children: [
                      Icon(Icons.list_alt, color: Colors.black87),
                      SizedBox(width: 12),
                      Text(
                        'Work Items Breakdown',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...itemBreakdown.entries.map((entry) {
                    final itemKey = entry.key;
                    final itemData = entry.value;
                    final quantity = itemData['quantity'] as int;
                    final rate = itemData['rate'] as double;
                    final amount = itemData['amount'] as double;
                    final itemName = _getItemName(itemKey);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    itemName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$quantity × ₹${rate.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '₹${amount.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Payment History
          if (payments.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(20),
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
                  const Row(
                    children: [
                      Icon(Icons.history, color: Colors.black87),
                      SizedBox(width: 12),
                      Text(
                        'Payment History',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...payments.map((payment) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.green,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '₹${payment.amount.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${dateFormat.format(payment.periodStart)} - ${dateFormat.format(payment.periodEnd)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: (payment.paymentMethod ?? 'cash') == 'cash'
                                    ? Colors.orange.withOpacity(0.1)
                                    : Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                (payment.paymentMethod ?? 'CASH').toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: (payment.paymentMethod ?? 'cash') == 'cash'
                                      ? Colors.orange
                                      : Colors.blue,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}
