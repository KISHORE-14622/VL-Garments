import 'package:flutter/material.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/data_service.dart';
import 'screens/inventory_screen.dart';
import 'screens/payments_screen.dart';
import 'screens/payment_history_screen.dart';
import 'screens/production_overview_screen.dart';
import 'screens/worker_rate_management_screen.dart';
import 'screens/staff_management_screen.dart';
import 'screens/admin_settings_screen.dart';
import 'screens/workers_screen.dart';
import '../shop/shop_home_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  final AuthService authService;
  final DataService dataService;

  const AdminHomeScreen({super.key, required this.authService, required this.dataService});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      await widget.dataService.fetchStaff();
    } catch (_) {}
    try {
      await widget.dataService.syncRatesFromServer();
    } catch (_) {}
    try {
      await widget.dataService.fetchAllProduction();
    } catch (_) {}
    try {
      await widget.dataService.fetchPayments();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _loading = false);
  }

  int _calculatePendingWorkers() {
    int workersWithPendingPayments = 0;
    
    print('=== Calculating Pending Workers ===');
    print('Total staff: ${widget.dataService.staffMembers.length}');
    print('Total entries: ${widget.dataService.stitchEntries.length}');
    print('Total payments: ${widget.dataService.payments.length}');
    
    for (final worker in widget.dataService.staffMembers) {
      // Get all stitch entries for this worker
      final workerEntries = widget.dataService.stitchEntries
          .where((entry) => entry.workerId == worker.id)
          .toList();
      
      if (workerEntries.isEmpty) {
        print('Worker ${worker.name}: No entries');
        continue;
      }
      
      // Calculate total earned
      final totalEarned = widget.dataService.calculateAmountForEntries(workerEntries);
      
      // Calculate total paid
      final workerPayments = widget.dataService.payments
          .where((p) => p.staffId == worker.id)
          .toList();
      final totalPaid = workerPayments.fold<double>(0, (sum, p) => sum + p.amount);
      
      print('Worker ${worker.name}: Earned=₹$totalEarned, Paid=₹$totalPaid');
      
      // If worker has unpaid earnings, count them
      if (totalEarned > totalPaid) {
        workersWithPendingPayments++;
        print('  -> HAS PENDING');
      }
    }
    
    print('Total workers with pending: $workersWithPendingPayments');
    return workersWithPendingPayments;
  }

  @override
  Widget build(BuildContext context) {
    final totalWorkers = widget.dataService.staffMembers.length;
    final totalProduction = widget.dataService.stitchEntries.fold<int>(0, (sum, e) => sum + e.quantity);
    final totalRevenue = widget.dataService.calculateAmountForEntries(widget.dataService.stitchEntries);
    final pendingPayments = _calculatePendingWorkers();

    if (_loading) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          elevation: 0,
          title: const Text('Admin Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              onPressed: _loadAll,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black54),
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loadAll,
            icon: const Icon(Icons.refresh_rounded, color: Colors.black54),
            tooltip: 'Refresh',
          ),
        ],
      ),
      drawer: _buildAdminDrawer(),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Welcome Section - Compact
                  const Text(
                    'Welcome Back!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Here\'s your business overview',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Stats Row - Compact, No Scrolling
                  Row(
                    children: [
                      Expanded(
                        child: _buildCompactStatCard(
                          icon: Icons.people_rounded,
                          value: totalWorkers.toString(),
                          label: 'Staff',
                          color: const Color(0xFF4A90E2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildCompactStatCard(
                          icon: Icons.inventory_2_rounded,
                          value: totalProduction.toString(),
                          label: 'Production',
                          color: const Color(0xFF50C878),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildCompactStatCard(
                          icon: Icons.currency_rupee_rounded,
                          value: '₹${(totalRevenue / 1000).toStringAsFixed(1)}K',
                          label: 'Revenue',
                          color: const Color(0xFF9B59B6),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildCompactStatCard(
                          icon: Icons.pending_actions_rounded,
                          value: pendingPayments.toString(),
                          label: 'Pending',
                          color: const Color(0xFFFF9500),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Analytics & Insights Header
                  const Text(
                    'Analytics & Insights',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Recent Activity Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4A90E2).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.trending_up_rounded,
                                color: Color(0xFF4A90E2),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Production Trends',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTrendItem(
                                'Today',
                                widget.dataService.stitchEntries
                                    .where((e) => e.date.isAfter(DateTime.now().subtract(const Duration(days: 1))))
                                    .fold<int>(0, (sum, e) => sum + e.quantity)
                                    .toString(),
                                Icons.today,
                                const Color(0xFF50C878),
                              ),
                            ),
                            Expanded(
                              child: _buildTrendItem(
                                'This Week',
                                widget.dataService.stitchEntries
                                    .where((e) => e.date.isAfter(DateTime.now().subtract(const Duration(days: 7))))
                                    .fold<int>(0, (sum, e) => sum + e.quantity)
                                    .toString(),
                                Icons.date_range,
                                const Color(0xFF4A90E2),
                              ),
                            ),
                            Expanded(
                              child: _buildTrendItem(
                                'This Month',
                                widget.dataService.stitchEntries
                                    .where((e) => e.date.isAfter(DateTime.now().subtract(const Duration(days: 30))))
                                    .fold<int>(0, (sum, e) => sum + e.quantity)
                                    .toString(),
                                Icons.calendar_today,
                                const Color(0xFF9B59B6),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Payment Status Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF9500).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.account_balance_wallet_rounded,
                                color: Color(0xFFFF9500),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Payment Overview',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total Paid',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '₹${widget.dataService.payments.fold<double>(0, (sum, p) => sum + p.amount).toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF50C878),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: Colors.grey[300],
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Pending',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$pendingPayments Workers',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFFF9500),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Quick Stats Grid
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF9B59B6).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.insights_rounded,
                                color: Color(0xFF9B59B6),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Quick Insights',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildInsightRow(
                          'Active Staff Members',
                          totalWorkers.toString(),
                          Icons.people_rounded,
                        ),
                        const Divider(height: 24),
                        _buildInsightRow(
                          'Total Production Units',
                          totalProduction.toString(),
                          Icons.inventory_2_rounded,
                        ),
                        const Divider(height: 24),
                        _buildInsightRow(
                          'Average per Worker',
                          totalWorkers > 0 ? (totalProduction / totalWorkers).toStringAsFixed(0) : '0',
                          Icons.analytics_rounded,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  Widget _buildCompactStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildInsightRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildAdminDrawer() {
    final user = widget.authService.currentUser;
    
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
                        user?.name.substring(0, 1).toUpperCase() ?? 'A',
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
                    user?.name ?? 'Admin',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? '',
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
                      'Administrator',
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
                  _buildDrawerItem(
                    icon: Icons.dashboard_rounded,
                    title: 'Dashboard',
                    onTap: () => Navigator.pop(context),
                  ),
                  _buildDrawerItem(
                    icon: Icons.badge_rounded,
                    title: 'Workers',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WorkersScreen(dataService: widget.dataService),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.people_rounded,
                    title: 'Staff Management',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StaffManagementScreen(
                            dataService: widget.dataService,
                            authService: widget.authService,
                          ),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.attach_money_rounded,
                    title: 'Rate Management',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WorkerRateManagementScreen(dataService: widget.dataService),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.payments_rounded,
                    title: 'Payments',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PaymentsScreen(dataService: widget.dataService),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.history_rounded,
                    title: 'Payment History',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PaymentHistoryScreen(dataService: widget.dataService),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.assessment_rounded,
                    title: 'Production Overview',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProductionOverviewScreen(dataService: widget.dataService),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.inventory_2_rounded,
                    title: 'Inventory',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => InventoryScreen(dataService: widget.dataService),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.storefront_rounded,
                    title: 'Wardrobe / Shop',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ShopHomeScreen(dataService: widget.dataService),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 32),
                  _buildDrawerItem(
                    icon: Icons.settings_rounded,
                    title: 'Settings',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminSettingsScreen(
                            authService: widget.authService,
                            dataService: widget.dataService,
                          ),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
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

  Widget _buildDrawerItem({
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


