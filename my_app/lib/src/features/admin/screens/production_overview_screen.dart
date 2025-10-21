import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/data_service.dart';
import '../../../core/models/stitch.dart';

class ProductionOverviewScreen extends StatefulWidget {
  final DataService dataService;

  const ProductionOverviewScreen({super.key, required this.dataService});

  @override
  State<ProductionOverviewScreen> createState() => _ProductionOverviewScreenState();
}

class _ProductionOverviewScreenState extends State<ProductionOverviewScreen> {
  String _selectedPeriod = 'all';

  @override
  Widget build(BuildContext context) {
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

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Production Overview'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
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
                    'Active Staff',
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
                final categoryName = widget.dataService.categories
                    .firstWhere(
                      (c) => c.id == entry.key,
                      orElse: () => widget.dataService.categories.first,
                    )
                    .name;
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
              final categoryName = widget.dataService.categories
                  .firstWhere(
                    (c) => c.id == entry.categoryId,
                    orElse: () => widget.dataService.categories.first,
                  )
                  .name;
              return _buildEntryCard(entry, categoryName);
            }).toList(),
          ],
        ),
      ),
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
                  'Worker: ${entry.workerId}',
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
