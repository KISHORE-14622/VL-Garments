import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/data_service.dart';
import '../../../core/services/razorpay_service.dart';
import '../../../core/models/worker.dart';

class PaymentsScreen extends StatefulWidget {
  final DataService dataService;

  const PaymentsScreen({super.key, required this.dataService});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  bool _loading = false;
  Map<String, Map<String, dynamic>> _workerPaymentData = {};
  late RazorpayService _razorpayService;
  String? _selectedCategoryFilter; // null means "All"
  
  // Store current payment context for Razorpay callback
  Worker? _currentPaymentWorker;
  double? _currentPaymentAmount;
  DateTime? _currentPeriodStart;
  DateTime? _currentPeriodEnd;

  @override
  void initState() {
    super.initState();
    _razorpayService = RazorpayService(authService: widget.dataService.auth);
    _razorpayService.onSuccess = _handleRazorpaySuccess;
    _razorpayService.onError = _handleRazorpayError;
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
      await widget.dataService.fetchAllAttendance();
    } catch (e) {
      print('Error loading data: $e');
    }
    _calculatePendingPayments();
  }

  @override
  void dispose() {
    _razorpayService.dispose();
    super.dispose();
  }

  void _calculatePendingPayments() {
    setState(() => _loading = true);

    final workerPaymentData = <String, Map<String, dynamic>>{};

    // ── 1. Stitch-entry (piece-rate) workers ──────────────────────────────
    for (var worker in widget.dataService.workers) {
      if ((worker.dailyWage) > 0) continue; // daily-wage workers handled separately

      final workerEntries = widget.dataService.stitchEntries
          .where((entry) => entry.workerId == worker.id)
          .toList();

      if (workerEntries.isEmpty) continue;

      final totalEarned = widget.dataService.calculateAmountForEntries(workerEntries);

      final paidPayments = widget.dataService.payments
          .where((p) => p.workerId == worker.id && p.status.toString().contains('paid'))
          .toList();
      final totalPaid = paidPayments.fold<double>(0, (sum, p) => sum + p.amount);

      final pendingAmount = totalEarned - totalPaid;
      if (pendingAmount <= 0) continue;

      final pendingEntries = workerEntries.where((entry) {
        if (paidPayments.isEmpty) return true;
        final lastPaymentDate = paidPayments
            .map((p) => p.periodEnd)
            .reduce((a, b) => a.isAfter(b) ? a : b);
        return entry.date.isAfter(lastPaymentDate);
      }).toList();

      DateTime? periodStart;
      DateTime? periodEnd;
      if (pendingEntries.isNotEmpty) {
        periodStart = pendingEntries.map((e) => e.date).reduce((a, b) => a.isBefore(b) ? a : b);
        periodEnd   = pendingEntries.map((e) => e.date).reduce((a, b) => a.isAfter(b) ? a : b);
      } else if (workerEntries.isNotEmpty) {
        periodStart = workerEntries.map((e) => e.date).reduce((a, b) => a.isBefore(b) ? a : b);
        periodEnd   = workerEntries.map((e) => e.date).reduce((a, b) => a.isAfter(b) ? a : b);
      }

      final itemBreakdown = <String, Map<String, dynamic>>{};
      for (var entry in pendingEntries) {
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

      workerPaymentData[worker.id] = {
        'worker': worker,
        'pendingAmount': pendingAmount,
        'totalEarned': totalEarned,
        'totalPaid': totalPaid,
        'periodStart': periodStart ?? DateTime.now(),
        'periodEnd': periodEnd ?? DateTime.now(),
        'workDays': pendingEntries.map((e) => e.date).toSet().length,
        'itemBreakdown': itemBreakdown,
        'payType': 'stitch',
      };
    }

    // ── 2. Daily-wage workers (attendance-based) ──────────────────────────
    final dailyWagePending = widget.dataService.calculateDailyWagePending();
    workerPaymentData.addAll(dailyWagePending);

    setState(() {
      _workerPaymentData = workerPaymentData;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Get filtered payment data based on selected category
    final filteredPaymentData = _selectedCategoryFilter == null
        ? _workerPaymentData
        : Map.fromEntries(
            _workerPaymentData.entries.where((entry) {
              final worker = entry.value['worker'] as Worker;
              return worker.category?.id == _selectedCategoryFilter;
            }),
          );
    
    final totalPending = filteredPaymentData.values
        .fold<double>(0, (sum, data) => sum + (data['pendingAmount'] as double));
    final workerCount = filteredPaymentData.length;
    
    final categories = widget.dataService.workerCategories;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Pending Payments'),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Summary Cards
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          'Total Pending',
                          '₹${totalPending.toStringAsFixed(0)}',
                          Colors.orange,
                          Icons.pending_actions,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSummaryCard(
                          'Workers',
                          workerCount.toString(),
                          Colors.blue,
                          Icons.people,
                        ),
                      ),
                    ],
                  ),
                ),

                // Category Filter Chips
                if (categories.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    height: 50,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: const Text('All'),
                            selected: _selectedCategoryFilter == null,
                            onSelected: (selected) {
                              setState(() {
                                _selectedCategoryFilter = null;
                              });
                            },
                            selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
                            checkmarkColor: Theme.of(context).primaryColor,
                          ),
                        ),
                        ...categories.map((category) {
                          final count = _workerPaymentData.values
                              .where((data) => (data['worker'] as Worker).category?.id == category.id)
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

                // Payment List
                Expanded(
                  child: filteredPaymentData.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: filteredPaymentData.length,
                          itemBuilder: (context, index) {
                            final workerId = filteredPaymentData.keys.elementAt(index);
                            final data = filteredPaymentData[workerId]!;
                            return _buildPaymentCard(data);
                          },
                        ),
                ),
              ],
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Pending Payments',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'All worker payments are up to date',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> data) {
    final worker = data['worker'] as Worker;
    final pendingAmount = data['pendingAmount'] as double;
    final totalEarned = data['totalEarned'] as double;
    final totalPaid = data['totalPaid'] as double;
    final periodStart = data['periodStart'] as DateTime;
    final periodEnd = data['periodEnd'] as DateTime;
    final payType = data['payType'] as String? ?? 'stitch';
    final dateFormat = DateFormat('MMM dd, yyyy');
    final isDailyWage = payType == 'daily_wage';

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isDailyWage ? Icons.schedule_rounded : Icons.person,
                    color: Colors.orange,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        worker.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDailyWage
                                  ? Colors.blue.withOpacity(0.2)
                                  : Colors.purple.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isDailyWage
                                  ? '₹${worker.dailyWage.toStringAsFixed(0)}/day'
                                  : (worker.category?.name ?? 'Piece Rate'),
                              style: TextStyle(
                                color: isDailyWage ? Colors.blue : Colors.purple,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              worker.phoneNumber,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
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
                      '₹${pendingAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Colors.orange,
                      ),
                    ),
                    Text(
                      'Pending',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildDetailItem(
                        'Period',
                        '${dateFormat.format(periodStart)} - ${dateFormat.format(periodEnd)}',
                        Icons.calendar_today,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildDetailItem(
                        isDailyWage ? 'Present Days' : 'Work Days',
                        isDailyWage
                            ? '${data['presentDays']} full + ${data['halfDays']} half'
                            : (data['workDays'] as int).toString(),
                        Icons.work_outline,
                      ),
                    ),
                    Expanded(
                      child: _buildDetailItem(
                        'Total Earned',
                        '₹${totalEarned.toStringAsFixed(0)}',
                        Icons.currency_rupee,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildDetailItem(
                        'Already Paid',
                        '₹${totalPaid.toStringAsFixed(0)}',
                        Icons.check_circle_outline,
                      ),
                    ),
                    Expanded(
                      child: _buildDetailItem(
                        'Pending Amount',
                        '₹${pendingAmount.toStringAsFixed(0)}',
                        Icons.pending_actions,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Breakdown
                if (isDailyWage) ...[
                  // Daily wage breakdown
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.schedule_rounded, size: 16, color: Colors.blue[700]),
                            const SizedBox(width: 6),
                            Text(
                              'Daily Wage Breakdown',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.blue[800],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _wageRow('Full Day', '${data['presentDays']}',
                            '× ₹${worker.dailyWage.toStringAsFixed(0)}',
                            '₹${((data['presentDays'] as int) * worker.dailyWage).toStringAsFixed(0)}',
                            const Color(0xFF50C878)),
                        const SizedBox(height: 6),
                        _wageRow('Half Day', '${data['halfDays']}',
                            '× ₹${(worker.dailyWage * 0.5).toStringAsFixed(0)}',
                            '₹${((data['halfDays'] as int) * worker.dailyWage * 0.5).toStringAsFixed(0)}',
                            const Color(0xFFFF9500)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else if (data['itemBreakdown'] != null && (data['itemBreakdown'] as Map).isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.list_alt, size: 16, color: Colors.grey[700]),
                            const SizedBox(width: 6),
                            Text(
                              'Work Items Breakdown',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...(data['itemBreakdown'] as Map<String, Map<String, dynamic>>).entries.map((entry) {
                          final itemKey = entry.key;
                          final itemData = entry.value;
                          final quantity = itemData['quantity'] as int;
                          final rate = itemData['rate'] as double;
                          final amount = itemData['amount'] as double;
                          String itemName = itemKey;
                          if (itemKey.contains('_')) {
                            final parts = itemKey.split('_');
                            if (parts.length > 1) itemName = parts.sublist(1).join('_');
                          }
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Container(width: 6, height: 6,
                                  decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle)),
                                const SizedBox(width: 8),
                                Expanded(child: Text(itemName,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                                Text('$quantity × ₹${rate.toStringAsFixed(0)}',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                const SizedBox(width: 8),
                                Text('₹${amount.toStringAsFixed(0)}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Payment Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showRazorpayPayment(worker, pendingAmount, periodStart, periodEnd),
                        icon: const Icon(Icons.payment),
                        label: const Text('Pay via Razorpay'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showCashPaymentDialog(worker, pendingAmount, periodStart, periodEnd),
                        icon: const Icon(Icons.money),
                        label: const Text('Cash Payment'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _wageRow(String label, String count, String rate, String total, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
        Text('$count $rate', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        const SizedBox(width: 8),
        Text(total, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildDetailItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 11,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showRazorpayPayment(Worker worker, double amount, DateTime periodStart, DateTime periodEnd) {
    // This will be implemented with Razorpay integration
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Razorpay Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Worker: ${worker.name}'),
            const SizedBox(height: 8),
            Text('Amount: ₹${amount.toStringAsFixed(2)}'),
            const SizedBox(height: 16),
            const Text(
              'Razorpay integration will be implemented to process this payment.',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _processRazorpayPayment(worker, amount, periodStart, periodEnd);
            },
            child: const Text('Proceed'),
          ),
        ],
      ),
    );
  }

  void _showCashPaymentDialog(Worker worker, double pendingAmount, DateTime periodStart, DateTime periodEnd) {
    final amountController = TextEditingController(text: pendingAmount.toStringAsFixed(2));
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cash Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Worker: ${worker.name}'),
            const SizedBox(height: 8),
            Text('Pending Amount: ₹${pendingAmount.toStringAsFixed(2)}'),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount Paid',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Enter the amount paid in cash and confirm.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              final paidAmount = double.tryParse(amountController.text);
              if (paidAmount != null && paidAmount > 0) {
                Navigator.pop(context);
                _processCashPayment(worker, paidAmount, periodStart, periodEnd);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid amount')),
                );
              }
            },
            icon: const Icon(Icons.check),
            label: const Text('Confirm Payment'),
          ),
        ],
      ),
    );
  }

  Future<void> _processRazorpayPayment(Worker worker, double amount, DateTime periodStart, DateTime periodEnd) async {
    try {
      setState(() => _loading = true);
      
      // Store payment context for callback
      _currentPaymentWorker = worker;
      _currentPaymentAmount = amount;
      _currentPeriodStart = periodStart;
      _currentPeriodEnd = periodEnd;
      
      // Create Razorpay order
      final orderData = await _razorpayService.createOrder(amount: amount);
      
      if (orderData == null) {
        throw Exception('Failed to create payment order');
      }
      
      setState(() => _loading = false);
      
      // Open Razorpay checkout
      _razorpayService.openCheckout(
        orderId: orderData['orderId'],
        amount: amount,
        name: worker.name,
        description: 'Payment for work period',
        email: worker.email,
        contact: worker.phoneNumber,
      );
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error initiating payment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _handleRazorpaySuccess(String orderId, String paymentId, String signature) async {
    try {
      setState(() => _loading = true);
      
      // Verify payment
      final verified = await _razorpayService.verifyPayment(
        orderId: orderId,
        paymentId: paymentId,
        signature: signature,
      );
      
      if (!verified) {
        throw Exception('Payment verification failed');
      }
      
      // Create payment record
      if (_currentPaymentWorker != null && _currentPaymentAmount != null) {
        await widget.dataService.createPayment(
          workerId: _currentPaymentWorker!.id,
          amount: _currentPaymentAmount!,
          periodStart: _currentPeriodStart!,
          periodEnd: _currentPeriodEnd!,
          status: 'paid',
          paymentMethod: 'razorpay',
          razorpayPaymentId: paymentId,
          razorpayOrderId: orderId,
        );
        
        // Refresh data
        await _loadData();
        
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment of ₹${_currentPaymentAmount!.toStringAsFixed(2)} successful'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing payment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      // Clear payment context
      _currentPaymentWorker = null;
      _currentPaymentAmount = null;
      _currentPeriodStart = null;
      _currentPeriodEnd = null;
      
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }
  
  void _handleRazorpayError(String error) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment failed: $error'),
        backgroundColor: Colors.red,
      ),
    );
    
    // Clear payment context
    _currentPaymentWorker = null;
    _currentPaymentAmount = null;
    _currentPeriodStart = null;
    _currentPeriodEnd = null;
  }

  Future<void> _processCashPayment(Worker worker, double amount, DateTime periodStart, DateTime periodEnd) async {
    try {
      setState(() => _loading = true);

      // Create payment record
      await widget.dataService.createPayment(
        workerId: worker.id,
        amount: amount,
        periodStart: periodStart,
        periodEnd: periodEnd,
        status: 'paid',
        paymentMethod: 'cash',
      );

      // Refresh all data (including attendance for daily-wage recalc)
      await widget.dataService.fetchPayments();
      await widget.dataService.fetchAllProduction();
      await widget.dataService.fetchWorkers();
      await widget.dataService.fetchAllAttendance();

      // Recalculate pending payments
      _calculatePendingPayments();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment of ₹${amount.toStringAsFixed(2)} recorded successfully'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing payment: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }
}
