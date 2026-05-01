import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/worker.dart';
import '../../core/models/worker_category.dart';
import '../../core/models/stitch.dart';
import '../../core/models/attendance.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/data_service.dart';
import 'screens/inventory_screen.dart';
import 'screens/payments_screen.dart';
import 'screens/payment_history_screen.dart';
import 'screens/production_overview_screen.dart';
import 'screens/worker_rate_management_screen.dart';
import 'screens/admin_settings_screen.dart';
import 'screens/workers_screen.dart';
import '../shop/shop_home_screen.dart';

// ═══════════════════════════════════════════════════════
//  MAIN SCREEN — Bottom nav with Home + Dashboard + Attendance tabs
// ═══════════════════════════════════════════════════════

class AdminHomeScreen extends StatefulWidget {
  final AuthService authService;
  final DataService dataService;

  const AdminHomeScreen({super.key, required this.authService, required this.dataService});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentTab = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try { await widget.dataService.fetchWorkers(); } catch (_) {}
    try { await widget.dataService.syncRatesFromServer(); } catch (_) {}
    try { await widget.dataService.fetchAllProduction(); } catch (_) {}
    try { await widget.dataService.fetchPayments(); } catch (_) {}
    try { await widget.dataService.fetchWorkerCategories(); } catch (_) {}
    try { await widget.dataService.fetchAllAttendance(); } catch (_) {}
    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildAdminDrawer(),
      body: _loading
          ? Scaffold(
              appBar: AppBar(
                elevation: 0,
                title: const Text('VL Garments', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              body: const Center(child: CircularProgressIndicator()),
            )
          : IndexedStack(
              index: _currentTab,
              children: [
                _HomeTab(
                  dataService: widget.dataService,
                  onRefresh: _loadAll,
                  scaffoldKey: _scaffoldKey,
                ),
                _DashboardTab(
                  dataService: widget.dataService,
                  authService: widget.authService,
                  onRefresh: _loadAll,
                  openDrawer: () => _scaffoldKey.currentState?.openDrawer(),
                ),
                _AttendanceTab(
                  dataService: widget.dataService,
                  openDrawer: () => _scaffoldKey.currentState?.openDrawer(),
                ),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTab,
        onTap: (i) => setState(() => _currentTab = i),
        selectedItemColor: const Color(0xFF4A90E2),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fact_check_rounded),
            label: 'Attendance',
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  //  DRAWER
  // ═══════════════════════════════════════
  Widget _buildAdminDrawer() {
    final user = widget.authService.currentUser;

    return Drawer(
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
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
                  Text(user?.name ?? 'Admin',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(user?.email ?? '',
                      style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('Administrator',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _drawerItem(Icons.home_rounded, 'Home', () {
                    Navigator.pop(context);
                    setState(() => _currentTab = 0);
                  }),
                  _drawerItem(Icons.badge_rounded, 'Workers', () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(
                        builder: (_) => WorkersScreen(dataService: widget.dataService)));
                  }),
                  _drawerItem(Icons.attach_money_rounded, 'Rate Management', () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(
                        builder: (_) => WorkerRateManagementScreen(dataService: widget.dataService)));
                  }),
                  _drawerItem(Icons.payments_rounded, 'Payments', () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(
                        builder: (_) => PaymentsScreen(dataService: widget.dataService)));
                  }),
                  _drawerItem(Icons.history_rounded, 'Payment History', () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(
                        builder: (_) => PaymentHistoryScreen(dataService: widget.dataService)));
                  }),
                  _drawerItem(Icons.assessment_rounded, 'Production Overview', () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(
                        builder: (_) => ProductionOverviewScreen(dataService: widget.dataService)));
                  }),
                  _drawerItem(Icons.inventory_2_rounded, 'Inventory', () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(
                        builder: (_) => InventoryScreen(dataService: widget.dataService)));
                  }),
                  _drawerItem(Icons.storefront_rounded, 'Wardrobe / Shop', () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(
                        builder: (_) => ShopHomeScreen(dataService: widget.dataService)));
                  }),
                  const Divider(height: 32),
                  _drawerItem(Icons.settings_rounded, 'Settings', () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(
                        builder: (_) => AdminSettingsScreen(
                              authService: widget.authService,
                              dataService: widget.dataService,
                            )));
                  }),
                  _drawerItem(Icons.logout_rounded, 'Logout', () {
                    Navigator.pop(context);
                    widget.authService.signOut();
                  }, textColor: Colors.red),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Version 1.0.0', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(IconData icon, String title, VoidCallback onTap, {Color? textColor}) {
    return ListTile(
      leading: Icon(icon, color: textColor ?? Colors.black87, size: 24),
      title: Text(title,
          style: TextStyle(color: textColor ?? Colors.black87, fontSize: 15, fontWeight: FontWeight.w500)),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  HOME TAB — Roles → Workers → Add Entry drill-down
// ═══════════════════════════════════════════════════════

class _HomeTab extends StatefulWidget {
  final DataService dataService;
  final Future<void> Function() onRefresh;
  final GlobalKey<ScaffoldState>? scaffoldKey;

  const _HomeTab({required this.dataService, required this.onRefresh, this.scaffoldKey});

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  DateTime _selectedDate = DateTime.now();
  final _dateFormat = DateFormat('EEE, MMM dd, yyyy');

  // Drill-down state
  WorkerCategory? _selectedRole;
  Worker? _selectedWorker;

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _changeDate(int days) => setState(() => _selectedDate = _selectedDate.add(Duration(days: days)));
  void _goToToday() => setState(() => _selectedDate = DateTime.now());

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  List<StitchEntry> _entriesForDay() =>
      widget.dataService.stitchEntries.where((e) => _isSameDay(e.date, _selectedDate)).toList();

  double _totalPaidForWorker(String workerId) =>
      widget.dataService.payments.where((p) => p.workerId == workerId).fold<double>(0, (s, p) => s + p.amount);

  String _categoryLabel(String catId) {
    if (catId.contains('_')) return catId.split('_').sublist(1).join(' ');
    return catId.replaceAll('_', ' ');
  }

  String _titleCase(String s) {
    if (s.isEmpty) return s;
    return s.split(' ').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');
  }

  // ═══════════════════════════════════════
  //  ADD ENTRY DIALOG — for a specific worker
  // ═══════════════════════════════════════
  void _showAddEntryForWorker(Worker worker) {
    String? selectedCategory;
    final qtyController = TextEditingController(text: '1');
    double calcAmount = 0;

    final roleId = worker.category?.id ?? '';
    final filteredCats = widget.dataService.categories
        .where((c) => c.id.startsWith('${roleId}_'))
        .toList();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDlg) {
          void recalc() {
            if (selectedCategory != null) {
              final rate = widget.dataService.ratePerCategory[selectedCategory] ?? 0;
              final qty = int.tryParse(qtyController.text) ?? 0;
              setDlg(() => calcAmount = rate * qty);
            }
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF4A90E2).withOpacity(0.15),
                child: Text(worker.name[0].toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4A90E2))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(worker.name, style: const TextStyle(fontSize: 16)),
                  Text(worker.category?.name ?? '', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ]),
              ),
            ]),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Date
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(_dateFormat.format(_selectedDate), style: const TextStyle(fontWeight: FontWeight.w500)),
                  ]),
                ),
                const SizedBox(height: 16),

                // Item Category
                if (filteredCats.isNotEmpty)
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Item Category *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.category),
                    ),
                    value: selectedCategory,
                    isExpanded: true,
                    items: filteredCats.map((c) {
                      final rate = widget.dataService.ratePerCategory[c.id] ?? 0;
                      final itemName = _categoryLabel(c.id);
                      return DropdownMenuItem(
                        value: c.id,
                        child: Text('${_titleCase(itemName)}  (₹${rate.toStringAsFixed(0)}/pc)'),
                      );
                    }).toList(),
                    onChanged: (v) {
                      setDlg(() => selectedCategory = v);
                      recalc();
                    },
                  ),

                if (filteredCats.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: [
                      const Icon(Icons.warning_amber, color: Colors.orange, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No item rates configured for ${worker.category?.name ?? "this role"}. Set up rates first.',
                          style: const TextStyle(fontSize: 12, color: Colors.orange),
                        ),
                      ),
                    ]),
                  ),

                const SizedBox(height: 16),

                // Quantity
                if (filteredCats.isNotEmpty)
                  TextField(
                    controller: qtyController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Quantity *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.numbers),
                    ),
                    onChanged: (_) => recalc(),
                  ),

                if (selectedCategory != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF50C878).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF50C878).withOpacity(0.3)),
                    ),
                    child: Column(children: [
                      const Text('Calculated Amount', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text('₹${calcAmount.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF50C878))),
                      Text(
                        '${qtyController.text} × ₹${(widget.dataService.ratePerCategory[selectedCategory] ?? 0).toStringAsFixed(0)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ]),
                  ),
                ],
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton.icon(
                onPressed: () async {
                  if (selectedCategory == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Select an item category')),
                    );
                    return;
                  }
                  final qty = int.tryParse(qtyController.text) ?? 0;
                  if (qty <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Enter a valid quantity')),
                    );
                    return;
                  }
                  Navigator.pop(ctx);

                  final result = await widget.dataService.addProductionEntry(
                    categoryId: selectedCategory!,
                    quantity: qty,
                    date: _selectedDate,
                    workerIdForUI: worker.id,
                  );

                  if (result != null && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                          '✅ Added $qty × ${_titleCase(_categoryLabel(selectedCategory!))} for ${worker.name}'),
                      backgroundColor: const Color(0xFF50C878),
                    ));
                  } else if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to add entry'), backgroundColor: Colors.red),
                    );
                  }
                  await widget.onRefresh();
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.check),
                label: const Text('Add Entry'),
              ),
            ],
          );
        });
      },
    );
  }

  // ═══════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final dayEntries = _entriesForDay();
    final totalUnits = dayEntries.fold<int>(0, (s, e) => s + e.quantity);
    final totalEarned = widget.dataService.calculateAmountForEntries(dayEntries);
    final isToday = _isSameDay(_selectedDate, DateTime.now());

    // Determine title & back behaviour
    String title = 'Home';
    VoidCallback? onBack;
    if (_selectedWorker != null) {
      title = _selectedWorker!.name;
      onBack = () => setState(() => _selectedWorker = null);
    } else if (_selectedRole != null) {
      title = _selectedRole!.name;
      onBack = () => setState(() => _selectedRole = null);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black54),
        leading: onBack != null
            ? IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.black54), onPressed: onBack)
            : IconButton(
                icon: const Icon(Icons.menu_rounded, color: Colors.black54),
                onPressed: () => widget.scaffoldKey?.currentState?.openDrawer(),
              ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        actions: [
          IconButton(
            onPressed: () async {
              await widget.onRefresh();
              if (mounted) setState(() {});
            },
            icon: const Icon(Icons.refresh_rounded, color: Colors.black54),
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: _selectedWorker != null
          ? FloatingActionButton.extended(
              onPressed: () => _showAddEntryForWorker(_selectedWorker!),
              icon: const Icon(Icons.add),
              label: const Text('Add Entry'),
              backgroundColor: const Color(0xFF4A90E2),
              foregroundColor: Colors.white,
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async {
          await widget.onRefresh();
          if (mounted) setState(() {});
        },
        child: _selectedWorker != null
            ? _buildWorkerView(dayEntries, isToday)
            : _selectedRole != null
                ? _buildWorkersListView(dayEntries, isToday)
                : _buildRolesGridView(dayEntries, totalUnits, totalEarned, isToday),
      ),
    );
  }

  // ═══════════════════════════════════════
  //  LEVEL 1: Roles grid
  // ═══════════════════════════════════════
  Widget _buildRolesGridView(List<StitchEntry> dayEntries, int totalUnits, double totalEarned, bool isToday) {
    final categories = widget.dataService.workerCategories;
    final activeWorkers = widget.dataService.getActiveWorkers();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildDateSelector(isToday),
        const SizedBox(height: 16),
        // Summary row
        Row(children: [
          Expanded(child: _summaryCard(Icons.people_rounded, activeWorkers.length.toString(), 'Workers', const Color(0xFF4A90E2))),
          const SizedBox(width: 10),
          Expanded(child: _summaryCard(Icons.inventory_2_rounded, totalUnits.toString(), 'Day Units', const Color(0xFF50C878))),
          const SizedBox(width: 10),
          Expanded(child: _summaryCard(Icons.currency_rupee_rounded, '₹${totalEarned.toStringAsFixed(0)}', 'Day Earned', const Color(0xFF9B59B6))),
        ]),
        const SizedBox(height: 20),
        Text('Select a Role', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[800])),
        const SizedBox(height: 12),
        if (categories.isEmpty)
          _buildEmptyCard('No roles found', 'Add worker categories in Rate Management.'),
        ...categories.map((wc) {
          final roleWorkers = activeWorkers.where((w) => w.category?.id == wc.id).toList();
          final roleEntries = dayEntries.where((e) {
            final w = widget.dataService.getWorkerById(e.workerId);
            return w?.category?.id == wc.id;
          }).toList();
          final roleUnits = roleEntries.fold<int>(0, (s, e) => s + e.quantity);
          final roleEarned = widget.dataService.calculateAmountForEntries(roleEntries);

          return _buildRoleCard(wc, roleWorkers.length, roleUnits, roleEarned);
        }),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildRoleCard(WorkerCategory wc, int workerCount, int dayUnits, double dayEarned) {
    final roleColors = [
      const Color(0xFF4A90E2),
      const Color(0xFF50C878),
      const Color(0xFF9B59B6),
      const Color(0xFFFF9500),
      const Color(0xFFE74C3C),
      const Color(0xFF1ABC9C),
    ];
    final color = roleColors[widget.dataService.workerCategories.indexOf(wc) % roleColors.length];

    return GestureDetector(
      onTap: () => setState(() => _selectedRole = wc),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
            child: Icon(Icons.group_rounded, color: color, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(wc.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 4),
              Text('$workerCount workers', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (dayUnits > 0) ...[
              Text('$dayUnits units', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
              const SizedBox(height: 2),
              Text('₹${dayEarned.toStringAsFixed(0)}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ] else
              Text('No entries', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
          ]),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════
  //  LEVEL 2: Workers list (for selected role)
  // ═══════════════════════════════════════
  Widget _buildWorkersListView(List<StitchEntry> dayEntries, bool isToday) {
    final activeWorkers = widget.dataService.getActiveWorkers()
        .where((w) => w.category?.id == _selectedRole!.id)
        .toList();

    // Daily stats for this role
    final roleEntries = dayEntries.where((e) {
      final w = widget.dataService.getWorkerById(e.workerId);
      return w?.category?.id == _selectedRole!.id;
    }).toList();
    final roleUnits = roleEntries.fold<int>(0, (s, e) => s + e.quantity);
    final roleEarned = widget.dataService.calculateAmountForEntries(roleEntries);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildDateSelector(isToday),
        const SizedBox(height: 16),
        // Role summary
        Row(children: [
          Expanded(child: _summaryCard(Icons.people_rounded, activeWorkers.length.toString(), 'Workers', const Color(0xFF4A90E2))),
          const SizedBox(width: 10),
          Expanded(child: _summaryCard(Icons.inventory_2_rounded, roleUnits.toString(), 'Day Units', const Color(0xFF50C878))),
          const SizedBox(width: 10),
          Expanded(child: _summaryCard(Icons.currency_rupee_rounded, '₹${roleEarned.toStringAsFixed(0)}', 'Day Earned', const Color(0xFF9B59B6))),
        ]),
        const SizedBox(height: 20),
        Text('Workers', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[800])),
        const SizedBox(height: 12),
        if (activeWorkers.isEmpty)
          _buildEmptyCard('No workers', 'No active workers in ${_selectedRole!.name}.'),
        ...activeWorkers.map((worker) {
          final workerEntries = dayEntries.where((e) => e.workerId == worker.id).toList();
          final wUnits = workerEntries.fold<int>(0, (s, e) => s + e.quantity);
          final wEarned = widget.dataService.calculateAmountForEntries(workerEntries);

          return _buildWorkerListTile(worker, wUnits, wEarned);
        }),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildWorkerListTile(Worker worker, int dayUnits, double dayEarned) {
    return GestureDetector(
      onTap: () => setState(() => _selectedWorker = worker),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFF4A90E2).withOpacity(0.12),
            child: Text(worker.name[0].toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF4A90E2))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(worker.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
              const SizedBox(height: 2),
              Text(worker.phoneNumber, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (dayUnits > 0) ...[
              Text('₹${dayEarned.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF50C878))),
              Text('$dayUnits units', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            ] else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                child: Text('No entries', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ),
          ]),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════
  //  LEVEL 3: Worker detail / entries view
  // ═══════════════════════════════════════
  Widget _buildWorkerView(List<StitchEntry> dayEntries, bool isToday) {
    final worker = _selectedWorker!;
    final workerEntries = dayEntries.where((e) => e.workerId == worker.id).toList();
    final wUnits = workerEntries.fold<int>(0, (s, e) => s + e.quantity);
    final wEarned = widget.dataService.calculateAmountForEntries(workerEntries);
    final totalPaid = _totalPaidForWorker(worker.id);
    final allEntries = widget.dataService.stitchEntries.where((e) => e.workerId == worker.id).toList();
    final totalEarned = widget.dataService.calculateAmountForEntries(allEntries);
    final pending = totalEarned - totalPaid;

    // Group today's entries by category
    final catGroups = <String, int>{};
    for (final e in workerEntries) {
      catGroups[e.categoryId] = (catGroups[e.categoryId] ?? 0) + e.quantity;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildDateSelector(isToday),
        const SizedBox(height: 16),

        // Worker info card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(children: [
            Row(children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: const Color(0xFF4A90E2).withOpacity(0.12),
                child: Text(worker.name[0].toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF4A90E2))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(worker.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  Text(worker.category?.name ?? '', style: TextStyle(fontSize: 13, color: Colors.purple[400], fontWeight: FontWeight.w500)),
                  Text(worker.phoneNumber, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ]),
              ),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _miniStat('Total Earned', '₹${totalEarned.toStringAsFixed(0)}', const Color(0xFF9B59B6))),
              Expanded(child: _miniStat('Total Paid', '₹${totalPaid.toStringAsFixed(0)}', const Color(0xFF50C878))),
              Expanded(child: _miniStat('Pending', '₹${pending.toStringAsFixed(0)}', pending > 0 ? const Color(0xFFFF9500) : Colors.grey)),
            ]),
          ]),
        ),
        const SizedBox(height: 16),

        // Today's summary
        Row(children: [
          Expanded(child: _summaryCard(Icons.inventory_2_rounded, wUnits.toString(), 'Day Units', const Color(0xFF50C878))),
          const SizedBox(width: 10),
          Expanded(child: _summaryCard(Icons.currency_rupee_rounded, '₹${wEarned.toStringAsFixed(0)}', 'Day Earned', const Color(0xFF9B59B6))),
        ]),
        const SizedBox(height: 20),

        Text("Today's Entries", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[800])),
        const SizedBox(height: 12),

        if (catGroups.isEmpty)
          _buildEmptyCard('No entries yet', 'Tap + Add Entry to record work for ${worker.name}.'),

        ...catGroups.entries.map((cg) {
          final rate = widget.dataService.ratePerCategory[cg.key] ?? 0;
          final amt = rate * cg.value;
          final itemName = _categoryLabel(cg.key);
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF4A90E2).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.checkroom_rounded, color: Color(0xFF4A90E2), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_titleCase(itemName), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  Text('${cg.value} pcs × ₹${rate.toStringAsFixed(0)}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ]),
              ),
              Text('₹${amt.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF50C878))),
            ]),
          );
        }),

        const SizedBox(height: 80), // space for FAB
      ],
    );
  }

  // ═══════════════════════════════════════
  //  SHARED WIDGETS
  // ═══════════════════════════════════════
  Widget _buildDateSelector(bool isToday) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        IconButton(onPressed: () => _changeDate(-1), icon: const Icon(Icons.chevron_left_rounded), color: Colors.black54),
        Expanded(
          child: GestureDetector(
            onTap: _pickDate,
            child: Column(children: [
              Text(_dateFormat.format(_selectedDate),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                  textAlign: TextAlign.center),
              if (isToday)
                const Text('Today', style: TextStyle(fontSize: 12, color: Color(0xFF4A90E2), fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
        if (!isToday) TextButton(onPressed: _goToToday, child: const Text('Today', style: TextStyle(fontSize: 12))),
        IconButton(
            onPressed: isToday ? null : () => _changeDate(1),
            icon: const Icon(Icons.chevron_right_rounded), color: Colors.black54),
      ]),
    );
  }

  Widget _summaryCard(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.10), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withOpacity(0.2), blurRadius: 4)]),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 10),
        FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87))),
        const SizedBox(height: 4),
        FittedBox(fit: BoxFit.scaleDown, child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[800], fontWeight: FontWeight.w600))),
      ]),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Column(children: [
      FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color))),
      const SizedBox(height: 2),
      FittedBox(fit: BoxFit.scaleDown, child: Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600]))),
    ]);
  }

  Widget _buildEmptyCard(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        Icon(Icons.inbox_rounded, size: 48, color: Colors.grey[400]),
        const SizedBox(height: 12),
        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[700])),
        const SizedBox(height: 6),
        Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[500]), textAlign: TextAlign.center),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  DASHBOARD TAB — Overall stats, revenue, analytics
// ═══════════════════════════════════════════════════════

class _DashboardTab extends StatelessWidget {
  final DataService dataService;
  final AuthService authService;
  final Future<void> Function() onRefresh;
  final VoidCallback openDrawer;

  const _DashboardTab({required this.dataService, required this.authService, required this.onRefresh, required this.openDrawer});

  int _calculatePendingWorkers() {
    int count = 0;

    // 1. Stitch-entry (piece-rate) workers — skip daily-wage workers
    for (final worker in dataService.workers) {
      if (worker.dailyWage > 0) continue; // handled separately below
      final entries = dataService.stitchEntries.where((e) => e.workerId == worker.id).toList();
      if (entries.isEmpty) continue;
      final totalEarned = dataService.calculateAmountForEntries(entries);
      final totalPaid = dataService.payments
          .where((p) => p.workerId == worker.id && p.status.toString().contains('paid'))
          .fold<double>(0, (s, p) => s + p.amount);
      if (totalEarned > totalPaid) count++;
    }

    // 2. Daily-wage workers — count those with attendance-based pending amounts
    final dailyWagePending = dataService.calculateDailyWagePending();
    count += dailyWagePending.length;

    return count;
  }

  @override
  Widget build(BuildContext context) {
    final totalWorkers = dataService.workers.length;
    final totalProduction = dataService.stitchEntries.fold<int>(0, (s, e) => s + e.quantity);
    final totalRevenue = dataService.calculateAmountForEntries(dataService.stitchEntries);
    final pendingPayments = _calculatePendingWorkers();
    final totalPaid = dataService.payments.fold<double>(0, (s, p) => s + p.amount);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black54),
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: Colors.black54),
          onPressed: openDrawer,
        ),
        title: const Text('Dashboard', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        actions: [
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded, color: Colors.black54),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Welcome Back!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 4),
            Text("Here's your business overview", style: TextStyle(color: Colors.grey[600], fontSize: 14)),
            const SizedBox(height: 20),

            // Stats
            Row(children: [
              Expanded(child: _statCard(Icons.people_rounded, totalWorkers.toString(), 'Workers', const Color(0xFF4A90E2))),
              const SizedBox(width: 12),
              Expanded(child: _statCard(Icons.inventory_2_rounded, totalProduction.toString(), 'Production', const Color(0xFF50C878))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _statCard(Icons.currency_rupee_rounded, '₹${(totalRevenue / 1000).toStringAsFixed(1)}K', 'Revenue', const Color(0xFF9B59B6))),
              const SizedBox(width: 12),
              Expanded(child: _statCard(Icons.pending_actions_rounded, pendingPayments.toString(), 'Pending', const Color(0xFFFF9500))),
            ]),
            const SizedBox(height: 24),

            // Production Trends
            _sectionCard(
              context,
              icon: Icons.trending_up_rounded,
              iconColor: const Color(0xFF4A90E2),
              title: 'Production Trends',
              child: Row(children: [
                Expanded(child: _trendItem(
                  'Today',
                  dataService.stitchEntries
                      .where((e) => e.date.isAfter(DateTime.now().subtract(const Duration(days: 1))))
                      .fold<int>(0, (s, e) => s + e.quantity)
                      .toString(),
                  Icons.today, const Color(0xFF50C878),
                )),
                Expanded(child: _trendItem(
                  'This Week',
                  dataService.stitchEntries
                      .where((e) => e.date.isAfter(DateTime.now().subtract(const Duration(days: 7))))
                      .fold<int>(0, (s, e) => s + e.quantity)
                      .toString(),
                  Icons.date_range, const Color(0xFF4A90E2),
                )),
                Expanded(child: _trendItem(
                  'This Month',
                  dataService.stitchEntries
                      .where((e) => e.date.isAfter(DateTime.now().subtract(const Duration(days: 30))))
                      .fold<int>(0, (s, e) => s + e.quantity)
                      .toString(),
                  Icons.calendar_today, const Color(0xFF9B59B6),
                )),
              ]),
            ),
            const SizedBox(height: 16),

            // Payment Overview
            _sectionCard(
              context,
              icon: Icons.account_balance_wallet_rounded,
              iconColor: const Color(0xFFFF9500),
              title: 'Payment Overview',
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Total Paid', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('₹${totalPaid.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF50C878))),
                  ]),
                ),
                Container(width: 1, height: 40, color: Colors.grey[300]),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Pending', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      const SizedBox(height: 4),
                      Text('$pendingPayments Workers',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFFF9500))),
                    ]),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),

            // Quick Insights
            _sectionCard(
              context,
              icon: Icons.insights_rounded,
              iconColor: const Color(0xFF9B59B6),
              title: 'Quick Insights',
              child: Column(children: [
                _insightRow('Active Workers', totalWorkers.toString(), Icons.people_rounded),
                const Divider(height: 24),
                _insightRow('Total Production Units', totalProduction.toString(), Icons.inventory_2_rounded),
                const Divider(height: 24),
                _insightRow('Average per Worker',
                    totalWorkers > 0 ? (totalProduction / totalWorkers).toStringAsFixed(0) : '0',
                    Icons.analytics_rounded),
              ]),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _statCard(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withOpacity(0.2), blurRadius: 4)]),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 16),
        FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87))),
        const SizedBox(height: 4),
        FittedBox(fit: BoxFit.scaleDown, child: Text(label, style: TextStyle(color: Colors.grey[800], fontSize: 13, fontWeight: FontWeight.w600))),
      ]),
    );
  }

  Widget _sectionCard(BuildContext context,
      {required IconData icon, required Color iconColor, required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
        ]),
        const SizedBox(height: 20),
        child,
      ]),
    );
  }

  Widget _trendItem(String label, String value, IconData icon, Color color) {
    return Column(children: [
      Icon(icon, color: color, size: 24),
      const SizedBox(height: 8),
      FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87))),
      const SizedBox(height: 4),
      FittedBox(fit: BoxFit.scaleDown, child: Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[700], fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
    ]);
  }

  Widget _insightRow(String label, String value, IconData icon) {
    return Row(children: [
      Icon(icon, size: 20, color: Colors.grey[600]),
      const SizedBox(width: 12),
      Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[800], fontWeight: FontWeight.w500))),
      FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87))),
    ]);
  }
}

// ═══════════════════════════════════════════════════════
//  ATTENDANCE TAB — Day-wise attendance management
// ═══════════════════════════════════════════════════════

class _AttendanceTab extends StatefulWidget {
  final DataService dataService;
  final VoidCallback openDrawer;

  const _AttendanceTab({required this.dataService, required this.openDrawer});

  @override
  State<_AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<_AttendanceTab> {
  DateTime _selectedDate = DateTime.now();
  final _dateFormat = DateFormat('EEE, MMM dd, yyyy');
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    setState(() => _loading = true);
    await widget.dataService.fetchAttendance(_selectedDate);
    if (mounted) setState(() => _loading = false);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _changeDate(int days) {
    setState(() => _selectedDate = _selectedDate.add(Duration(days: days)));
    _loadAttendance();
  }

  void _goToToday() {
    setState(() => _selectedDate = DateTime.now());
    _loadAttendance();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadAttendance();
    }
  }

  // ═══ MARK ATTENDANCE ═══
  void _showMarkAttendanceSheet() {
    // Only workers with a daily wage are shown in attendance
    final activeWorkers = widget.dataService.getActiveWorkers()
        .where((w) => w.dailyWage > 0)
        .toList();
    final alreadyMarked = widget.dataService.attendanceRecords
        .map((r) => r.workerId)
        .toSet();

    // Pre-select workers not yet marked
    final selected = <String>{};
    String selectedStatus = 'present';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          final filteredWorkers = activeWorkers;

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.75,
            maxChildSize: 0.95,
            minChildSize: 0.4,
            builder: (_, scrollCtrl) {
              return Column(
                children: [
                  // Handle
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)),
                  ),
                  // Title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text('Mark Attendance',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                        Text(_dateFormat.format(_selectedDate),
                            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Status selector
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _statusChip('Present', 'present', selectedStatus, (v) => setSheet(() => selectedStatus = v)),
                        const SizedBox(width: 8),
                        _statusChip('Absent', 'absent', selectedStatus, (v) => setSheet(() => selectedStatus = v)),
                        const SizedBox(width: 8),
                        _statusChip('Half Day', 'half-day', selectedStatus, (v) => setSheet(() => selectedStatus = v)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Select all / none
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text('${selected.length} selected',
                            style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            setSheet(() {
                              for (final w in filteredWorkers) {
                                if (!alreadyMarked.contains(w.id)) selected.add(w.id);
                              }
                            });
                          },
                          child: const Text('Select All', style: TextStyle(fontSize: 12)),
                        ),
                        TextButton(
                          onPressed: () => setSheet(() => selected.clear()),
                          child: const Text('Clear', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),

                  // Worker list
                  Expanded(
                    child: ListView.builder(
                      controller: scrollCtrl,
                      itemCount: filteredWorkers.length,
                      itemBuilder: (_, i) {
                        final w = filteredWorkers[i];
                        final isMarked = alreadyMarked.contains(w.id);
                        final isSelected = selected.contains(w.id);

                        return ListTile(
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: isMarked
                                ? Colors.green.withOpacity(0.15)
                                : isSelected
                                    ? const Color(0xFF4A90E2)
                                    : const Color(0xFF4A90E2).withOpacity(0.1),
                            child: isMarked
                                ? const Icon(Icons.check, color: Colors.green, size: 18)
                                : Text(w.name[0].toUpperCase(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? Colors.white : const Color(0xFF4A90E2),
                                    )),
                          ),
                          title: Text(w.name,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isMarked ? Colors.grey : Colors.black87,
                              )),
                          subtitle: Text(
                            isMarked
                                ? 'Already marked'
                                : w.dailyWage > 0
                                    ? '₹${w.dailyWage.toStringAsFixed(0)}/day'
                                    : (w.category?.name ?? 'No wage set'),
                            style: TextStyle(fontSize: 12, color: isMarked ? Colors.green[400] : Colors.grey[600]),
                          ),
                          trailing: isMarked
                              ? Icon(Icons.check_circle, color: Colors.green[400], size: 20)
                              : Checkbox(
                                  value: isSelected,
                                  onChanged: (_) {
                                    setSheet(() {
                                      if (isSelected) {
                                        selected.remove(w.id);
                                      } else {
                                        selected.add(w.id);
                                      }
                                    });
                                  },
                                  activeColor: const Color(0xFF4A90E2),
                                ),
                          onTap: isMarked
                              ? null
                              : () {
                                  setSheet(() {
                                    if (isSelected) {
                                      selected.remove(w.id);
                                    } else {
                                      selected.add(w.id);
                                    }
                                  });
                                },
                        );
                      },
                    ),
                  ),

                  // Submit button
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: selected.isEmpty
                            ? null
                            : () async {
                                Navigator.pop(ctx);
                                final result = await widget.dataService.markAttendance(
                                  date: _selectedDate,
                                  workerIds: selected.toList(),
                                  status: selectedStatus,
                                );
                                if (result != null && mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: Text('✅ Marked ${result.length} worker(s) as $selectedStatus'),
                                    backgroundColor: const Color(0xFF50C878),
                                  ));
                                  _loadAttendance();
                                }
                              },
                        icon: const Icon(Icons.check),
                        label: Text('Mark ${selected.length} Workers'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: const Color(0xFF4A90E2),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        });
      },
    );
  }

  Widget _statusChip(String label, String value, String current, void Function(String) onTap) {
    final isSelected = current == value;
    Color chipColor;
    switch (value) {
      case 'present': chipColor = const Color(0xFF50C878); break;
      case 'absent': chipColor = const Color(0xFFE74C3C); break;
      default: chipColor = const Color(0xFFFF9500);
    }
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? chipColor.withOpacity(0.15) : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? chipColor : Colors.grey[300]!),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? chipColor : Colors.grey[700],
            )),
      ),
    );
  }

  // ═══ CHANGE STATUS ═══
  void _showChangeStatusDialog(AttendanceRecord record) {
    showDialog(
      context: context,
      builder: (ctx) {
        String newStatus = record.status;
        return StatefulBuilder(builder: (ctx, setDlg) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(record.workerName ?? 'Worker'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _statusOption('Present', 'present', newStatus, (v) => setDlg(() => newStatus = v)),
                _statusOption('Absent', 'absent', newStatus, (v) => setDlg(() => newStatus = v)),
                _statusOption('Half Day', 'half-day', newStatus, (v) => setDlg(() => newStatus = v)),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final ok = await widget.dataService.updateAttendanceStatus(record.id, newStatus);
                  if (ok && mounted) {
                    _loadAttendance();
                  }
                },
                child: const Text('Update'),
              ),
            ],
          );
        });
      },
    );
  }

  Widget _statusOption(String label, String value, String current, void Function(String) onTap) {
    Color statusColor;
    IconData statusIcon;
    switch (value) {
      case 'present':
        statusColor = const Color(0xFF50C878);
        statusIcon = Icons.check_circle;
        break;
      case 'absent':
        statusColor = const Color(0xFFE74C3C);
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = const Color(0xFFFF9500);
        statusIcon = Icons.timelapse;
    }
    return ListTile(
      leading: Icon(statusIcon, color: statusColor),
      title: Text(label),
      trailing: current == value ? Icon(Icons.check, color: statusColor) : null,
      onTap: () => onTap(value),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      selected: current == value,
      selectedTileColor: statusColor.withOpacity(0.08),
    );
  }

  @override
  Widget build(BuildContext context) {
    final records = widget.dataService.attendanceRecords;
    final isToday = _isSameDay(_selectedDate, DateTime.now());
    // Count all active workers for attendance
    final totalWorkers = widget.dataService.getActiveWorkers().length;

    int presentCount = 0, absentCount = 0, halfDayCount = 0;
    double totalEarnings = 0;
    for (final r in records) {
      final worker = widget.dataService.getWorkerById(r.workerId);
      final wage = worker?.dailyWage ?? 0;
      switch (r.status) {
        case 'present':
          presentCount++;
          totalEarnings += wage;
          break;
        case 'absent':
          absentCount++;
          break;
        case 'half-day':
          halfDayCount++;
          totalEarnings += wage * 0.5;
          break;
      }
    }
    final unmarkedCount = totalWorkers - records.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black54),
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: Colors.black54),
          onPressed: widget.openDrawer,
        ),
        title: const Text('Attendance', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        actions: [
          IconButton(
            onPressed: _loadAttendance,
            icon: const Icon(Icons.refresh_rounded, color: Colors.black54),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showMarkAttendanceSheet,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Mark Attendance'),
        backgroundColor: const Color(0xFF4A90E2),
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _loadAttendance,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Date selector
            _buildDateSelector(isToday),
            const SizedBox(height: 16),

            // Summary
            Row(children: [
              Expanded(child: _statCard(presentCount.toString(), 'Present', const Color(0xFF50C878), Icons.check_circle_rounded)),
              const SizedBox(width: 8),
              Expanded(child: _statCard(absentCount.toString(), 'Absent', const Color(0xFFE74C3C), Icons.cancel_rounded)),
              const SizedBox(width: 8),
              Expanded(child: _statCard(halfDayCount.toString(), 'Half Day', const Color(0xFFFF9500), Icons.timelapse_rounded)),
              const SizedBox(width: 8),
              Expanded(child: _statCard(unmarkedCount.toString(), 'Unmarked', Colors.grey, Icons.help_outline_rounded)),
            ]),
            const SizedBox(height: 12),

            // Daily Earnings Card
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4A90E2), Color(0xFF357ABD)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: const Color(0xFF4A90E2).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Daily Payable', style: TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text('₹${totalEarnings.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${presentCount + halfDayCount} paid', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                      const SizedBox(height: 2),
                      Text('of ${records.length} marked', style: const TextStyle(fontSize: 12, color: Colors.white54)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Attendance list
            Row(
              children: [
                Text('Daily Wage Attendance',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[800])),
                const Spacer(),
                Text('${records.length}/$totalWorkers',

                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[600])),
              ],
            ),
            const SizedBox(height: 12),

            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),

            if (!_loading && records.isEmpty)
              _buildEmptyCard(),

            if (!_loading)
              ...records.map((r) => _buildAttendanceCard(r)),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector(bool isToday) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        IconButton(onPressed: () => _changeDate(-1), icon: const Icon(Icons.chevron_left_rounded), color: Colors.black54),
        Expanded(
          child: GestureDetector(
            onTap: _pickDate,
            child: Column(children: [
              Text(_dateFormat.format(_selectedDate),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                  textAlign: TextAlign.center),
              if (isToday)
                const Text('Today', style: TextStyle(fontSize: 12, color: Color(0xFF4A90E2), fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
        if (!isToday) TextButton(onPressed: _goToToday, child: const Text('Today', style: TextStyle(fontSize: 12))),
        IconButton(
            onPressed: isToday ? null : () => _changeDate(1),
            icon: const Icon(Icons.chevron_right_rounded), color: Colors.black54),
      ]),
    );
  }

  Widget _statCard(String value, String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      ]),
    );
  }

  Widget _buildEmptyCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        Icon(Icons.fact_check_outlined, size: 48, color: Colors.grey[400]),
        const SizedBox(height: 12),
        Text('No attendance marked',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[700])),
        const SizedBox(height: 6),
        Text('Tap the button below to mark attendance',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]), textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _buildAttendanceCard(AttendanceRecord record) {
    Color statusColor;
    IconData statusIcon;
    String statusLabel;
    double multiplier;
    switch (record.status) {
      case 'present':
        statusColor = const Color(0xFF50C878);
        statusIcon = Icons.check_circle;
        statusLabel = 'Present';
        multiplier = 1.0;
        break;
      case 'absent':
        statusColor = const Color(0xFFE74C3C);
        statusIcon = Icons.cancel;
        statusLabel = 'Absent';
        multiplier = 0.0;
        break;
      default:
        statusColor = const Color(0xFFFF9500);
        statusIcon = Icons.timelapse;
        statusLabel = 'Half Day';
        multiplier = 0.5;
    }

    final worker = widget.dataService.getWorkerById(record.workerId);
    final wage = worker?.dailyWage ?? 0;
    final earnings = wage * multiplier;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: statusColor.withOpacity(0.12),
          child: Text(
            (record.workerName ?? '?')[0].toUpperCase(),
            style: TextStyle(fontWeight: FontWeight.bold, color: statusColor),
          ),
        ),
        title: Text(record.workerName ?? 'Unknown',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Row(
          children: [
            if (wage > 0) ...[
              Icon(Icons.currency_rupee, size: 12, color: earnings > 0 ? const Color(0xFF50C878) : Colors.grey[400]),
              Text(
                earnings > 0 ? '${earnings.toStringAsFixed(0)}' : '0',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: earnings > 0 ? const Color(0xFF50C878) : Colors.grey[400],
                ),
              ),
              if (record.status == 'half-day')
                Text(' (of ₹${wage.toStringAsFixed(0)})',
                    style: TextStyle(fontSize: 11, color: Colors.grey[400])),
              const SizedBox(width: 8),
            ],
            if (record.workerPhone != null)
              Text(record.workerPhone!, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          ],
        ),
        trailing: GestureDetector(
          onTap: () => _showChangeStatusDialog(record),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(statusIcon, size: 16, color: statusColor),
              const SizedBox(width: 4),
              Text(statusLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor)),
            ]),
          ),
        ),
      ),
    );
  }
}


