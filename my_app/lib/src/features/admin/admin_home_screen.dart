import 'package:flutter/material.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/data_service.dart';
import 'screens/inventory_screen.dart';
import 'screens/payment_history_screen.dart';
import 'screens/production_overview_screen.dart';
import 'screens/rate_management_screen.dart';
import 'screens/staff_management_screen.dart';
import '../shop/shop_home_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  final AuthService authService;
  final DataService dataService;

  const AdminHomeScreen({super.key, required this.authService, required this.dataService});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      widget.dataService.fetchRates(),
      widget.dataService.fetchStaff(),
      widget.dataService.fetchWorkers(),
      widget.dataService.fetchStitchEntries(), // Load stitch entries
    ]);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          elevation: 0,
          title: const Text('Admin Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final totalWorkers = widget.dataService.workers.where((w) => w.isActive).length;
    final totalProduction = widget.dataService.stitchEntries.fold<int>(0, (sum, e) => sum + e.quantity);
    final totalRevenue = widget.dataService.calculateAmountForEntries(widget.dataService.stitchEntries);
    final pendingPayments = widget.dataService.payments.where((p) => p.status.toString().contains('pending')).length;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        title: const Text('Admin Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            onPressed: () => widget.authService.signOut(),
            icon: const Icon(Icons.logout_outlined),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            Text(
              'Welcome Back!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Here\'s what\'s happening with your business today.',
              style: TextStyle(color: Colors.grey[600], fontSize: 15),
            ),
            const SizedBox(height: 24),

            // Stats Cards
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.5,
              children: [
                _buildStatCard(
                  context,
                  icon: Icons.people_outline,
                  title: 'Total Staff',
                  value: totalWorkers.toString(),
                  color: Colors.blue,
                ),
                _buildStatCard(
                  context,
                  icon: Icons.production_quantity_limits_outlined,
                  title: 'Production',
                  value: totalProduction.toString(),
                  color: Colors.green,
                ),
                _buildStatCard(
                  context,
                  icon: Icons.currency_rupee,
                  title: 'Revenue',
                  value: '₹${totalRevenue.toStringAsFixed(0)}',
                  color: Colors.purple,
                ),
                _buildStatCard(
                  context,
                  icon: Icons.pending_actions_outlined,
                  title: 'Pending',
                  value: pendingPayments.toString(),
                  color: Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Quick Actions
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
            ),
            const SizedBox(height: 16),

            _buildActionCard(
              context,
              icon: Icons.people,
              title: 'Staff Management',
              subtitle: 'Manage staff members and their details',
              color: Colors.blue,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StaffManagementScreen(
                    dataService: widget.dataService,
                    authService: widget.authService,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            _buildActionCard(
              context,
              icon: Icons.attach_money,
              title: 'Rate Management',
              subtitle: 'Set rates for different categories',
              color: Colors.green,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RateManagementScreen(dataService: widget.dataService),
                ),
              ),
            ),
            const SizedBox(height: 12),

            _buildActionCard(
              context,
              icon: Icons.assessment_outlined,
              title: 'Production Overview',
              subtitle: 'View detailed production statistics',
              color: Colors.purple,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProductionOverviewScreen(dataService: widget.dataService),
                ),
              ),
            ),
            const SizedBox(height: 12),

            _buildActionCard(
              context,
              icon: Icons.payment,
              title: 'Payment History',
              subtitle: 'Track all payments and transactions',
              color: Colors.orange,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PaymentHistoryScreen(dataService: widget.dataService),
                ),
              ),
            ),
            const SizedBox(height: 12),

            _buildActionCard(
              context,
              icon: Icons.inventory_2_outlined,
              title: 'Inventory Management',
              subtitle: 'Manage stock and supplies',
              color: Colors.teal,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => InventoryScreen(dataService: widget.dataService),
                ),
              ),
            ),
            const SizedBox(height: 12),

            _buildActionCard(
              context,
              icon: Icons.storefront,
              title: 'Wardrobe / Shop',
              subtitle: 'Manage and preview products',
              color: Colors.indigo,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ShopHomeScreen(dataService: widget.dataService),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
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
              const SizedBox(height: 4),
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

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}


