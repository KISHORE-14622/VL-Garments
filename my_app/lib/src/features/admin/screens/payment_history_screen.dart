import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/data_service.dart';

class PaymentHistoryScreen extends StatefulWidget {
  final DataService dataService;

  const PaymentHistoryScreen({super.key, required this.dataService});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> {
  String _filterStatus = 'all';

  String _getWorkerName(String staffId) {
    try {
      final worker = widget.dataService.workers.firstWhere(
        (w) => w.id == staffId,
      );
      return worker.name;
    } catch (e) {
      return 'Unknown';
    }
  }

  Future<void> _exportToCSV() async {
    try {
      // Create CSV content
      final buffer = StringBuffer();
      buffer.writeln('Worker Name,Period Start,Period End,Amount,Status,Payment Method');
      
      for (final payment in widget.dataService.payments) {
        final workerName = _getWorkerName(payment.staffId);
        final dateFormat = DateFormat('yyyy-MM-dd');
        final startDate = dateFormat.format(payment.periodStart);
        final endDate = dateFormat.format(payment.periodEnd);
        final status = payment.status.toString().split('.').last;
        final method = payment.paymentMethod ?? 'N/A';
        
        buffer.writeln('$workerName,$startDate,$endDate,${payment.amount},$status,$method');
      }

      // Show dialog with CSV content
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Export CSV'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('CSV data generated successfully!'),
                const SizedBox(height: 16),
                const Text('Copy the data below:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: SelectableText(
                    buffer.toString(),
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Total records: ${widget.dataService.payments.length}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting CSV: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final payments = widget.dataService.payments;
    final filteredPayments = _filterStatus == 'all'
        ? payments
        : payments.where((p) => p.status.toString().contains(_filterStatus)).toList();

    final totalPaid = payments
        .where((p) => p.status.toString().contains('paid'))
        .fold<double>(0, (sum, p) => sum + p.amount);
    
    // Calculate total pending (unpaid work) for all workers
    double totalPending = 0;
    for (var worker in widget.dataService.workers) {
      final workerEntries = widget.dataService.stitchEntries
          .where((entry) => entry.workerId == worker.id)
          .toList();
      if (workerEntries.isEmpty) continue;
      
      final totalEarned = widget.dataService.calculateAmountForEntries(workerEntries);
      final paidPayments = payments
          .where((p) => p.staffId == worker.id && p.status.toString().contains('paid'))
          .toList();
      final totalPaidForWorker = paidPayments.fold<double>(0, (sum, p) => sum + p.amount);
      final pendingAmount = totalEarned - totalPaidForWorker;
      if (pendingAmount > 0) {
        totalPending += pendingAmount;
      }
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Payment History'),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: payments.isEmpty ? null : _exportToCSV,
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Export CSV',
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary Cards
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Total Paid',
                    '₹${totalPaid.toStringAsFixed(0)}',
                    Colors.green,
                    Icons.check_circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    'Pending',
                    '₹${totalPending.toStringAsFixed(0)}',
                    Colors.orange,
                    Icons.pending,
                  ),
                ),
              ],
            ),
          ),

          // Filter Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFilterChip('All', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Paid', 'paid'),
                const SizedBox(width: 8),
                _buildFilterChip('Pending', 'pending'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Payment List
          Expanded(
            child: filteredPayments.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredPayments.length,
                    itemBuilder: (context, index) {
                      final payment = filteredPayments[index];
                      return _buildPaymentCard(payment);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddPaymentDialog(),
        icon: const Icon(Icons.add),
        label: const Text('New Payment'),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterStatus == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterStatus = value;
        });
      },
      backgroundColor: Colors.white,
      selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
      checkmarkColor: Theme.of(context).primaryColor,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.payment, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Payments Found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Payment records will appear here',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(payment) {
    final isPaid = payment.status.toString().contains('paid');
    final dateFormat = DateFormat('MMM dd, yyyy');
    final workerName = _getWorkerName(payment.staffId);

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
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isPaid ? Colors.green : Colors.orange).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isPaid ? Icons.check_circle : Icons.pending,
                  color: isPaid ? Colors.green : Colors.orange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${dateFormat.format(payment.periodStart)} - ${dateFormat.format(payment.periodEnd)}',
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
                    '₹${payment.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isPaid ? Colors.green : Colors.orange).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isPaid ? 'Paid' : 'Pending',
                      style: TextStyle(
                        color: isPaid ? Colors.green : Colors.orange,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddPaymentDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Payment'),
        content: const Text(
          'Payment creation feature will be implemented with staff selection, '
          'date range picker, and automatic amount calculation based on production entries.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
