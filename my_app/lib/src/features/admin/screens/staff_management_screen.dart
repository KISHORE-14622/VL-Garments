import 'package:flutter/material.dart';
import '../../../core/services/data_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/models/stitch.dart';
import '../../../core/models/staff.dart';
import 'staff_detail_screen.dart';

class StaffManagementScreen extends StatefulWidget {
  final DataService dataService;
  final AuthService authService;

  const StaffManagementScreen({super.key, required this.dataService, required this.authService});

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  String _sortBy = 'production'; // production, earnings, name
  String _filterPeriod = 'all'; // all, week, month
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    setState(() => _isLoading = true);
    await widget.dataService.fetchStaff();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  List<Staff> _getSortedStaff() {
    final staff = List<Staff>.from(widget.dataService.staffMembers);
    
    staff.sort((a, b) {
      final aEntries = _getFilteredEntries(a.id);
      final bEntries = _getFilteredEntries(b.id);
      
      switch (_sortBy) {
        case 'production':
          final aProduction = aEntries.fold<int>(0, (sum, e) => (sum + e.quantity));
          final bProduction = bEntries.fold<int>(0, (sum, e) => (sum + e.quantity));
          return bProduction.compareTo(aProduction);
        case 'earnings':
          final aEarnings = widget.dataService.calculateAmountForEntries(aEntries);
          final bEarnings = widget.dataService.calculateAmountForEntries(bEntries);
          return bEarnings.compareTo(aEarnings);
        case 'name':
          return a.name.compareTo(b.name);
        default:
          return 0;
      }
    });
    
    return staff;
  }

  List<StitchEntry> _getFilteredEntries(String workerId) {
    final entries = widget.dataService.stitchEntries.where((e) => e.workerId == workerId).toList();
    final now = DateTime.now();
    
    switch (_filterPeriod) {
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

  @override
  Widget build(BuildContext context) {
    final staffList = _getSortedStaff();
    
    // Calculate overall stats
    final totalStaff = staffList.length;
    final allEntries = widget.dataService.stitchEntries;
    final totalProduction = allEntries.fold<int>(0, (sum, e) => (sum + e.quantity));
    final totalEarnings = widget.dataService.calculateAmountForEntries(allEntries);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Staff Management'),
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) {
              setState(() {
                _sortBy = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'production',
                child: Row(
                  children: [
                    Icon(Icons.inventory_2, size: 20),
                    SizedBox(width: 12),
                    Text('Sort by Production'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'earnings',
                child: Row(
                  children: [
                    Icon(Icons.currency_rupee, size: 20),
                    SizedBox(width: 12),
                    Text('Sort by Earnings'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'name',
                child: Row(
                  children: [
                    Icon(Icons.sort_by_alpha, size: 20),
                    SizedBox(width: 12),
                    Text('Sort by Name'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: staffList.isEmpty
          ? _buildEmptyState()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Overall Stats
                  _buildOverallStats(totalStaff, totalProduction, totalEarnings),
                  const SizedBox(height: 24),
                  
                  // Period Filter
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Staff Members (${staffList.length})',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                      ),
                      DropdownButton<String>(
                        value: _filterPeriod,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All Time')),
                          DropdownMenuItem(value: 'week', child: Text('This Week')),
                          DropdownMenuItem(value: 'month', child: Text('This Month')),
                        ],
                        onChanged: (v) => setState(() => _filterPeriod = v ?? _filterPeriod),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Staff List
                  ...staffList.map((staff) {
                    final staffEntries = _getFilteredEntries(staff.id);
                    final totalProduction = staffEntries.fold<int>(0, (sum, e) => (sum + e.quantity));
                    final totalEarnings = widget.dataService.calculateAmountForEntries(staffEntries);

                    return _buildStaffCard(
                      context,
                      staff: staff,
                      totalProduction: totalProduction,
                      totalEarnings: totalEarnings,
                      entriesCount: staffEntries.length,
                    );
                  }).toList(),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddStaffDialog(),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Staff'),
      ),
    );
  }

  Widget _buildOverallStats(int totalStaff, int totalProduction, double totalEarnings) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withOpacity(0.7),
          ],
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
              Icon(Icons.people, color: Colors.white, size: 28),
              SizedBox(width: 12),
              Text(
                'Overall Statistics',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildOverallStatItem(
                  'Total Staff',
                  totalStaff.toString(),
                  Icons.people_alt,
                ),
              ),
              Expanded(
                child: _buildOverallStatItem(
                  'Production',
                  totalProduction.toString(),
                  Icons.inventory_2,
                ),
              ),
              Expanded(
                child: _buildOverallStatItem(
                  'Earnings',
                  '₹${totalEarnings.toStringAsFixed(0)}',
                  Icons.currency_rupee,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverallStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
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
            'No Staff Members Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add staff members to get started',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffCard(
    BuildContext context, {
    required Staff staff,
    required int totalProduction,
    required double totalEarnings,
    required int entriesCount,
  }) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StaffDetailScreen(
              dataService: widget.dataService,
              workerId: staff.id,
            ),
          ),
        );
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                      staff.name.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                        fontSize: 18,
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
                        staff.name,
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
                            staff.phoneNumber,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.receipt_long, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            '$entriesCount entries',
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
            const SizedBox(height: 16),
            Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.grey[300]!,
                    Colors.grey[100]!,
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.production_quantity_limits,
                    label: 'Production',
                    value: totalProduction.toString(),
                    color: Colors.green,
                  ),
                ),
                Container(
                  width: 1,
                  height: 50,
                  color: Colors.grey[200],
                ),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.currency_rupee,
                    label: 'Earnings',
                    value: '₹${totalEarnings.toStringAsFixed(0)}',
                    color: Colors.purple,
                  ),
                ),
                Container(
                  width: 1,
                  height: 50,
                  color: Colors.grey[200],
                ),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.analytics,
                    label: 'Avg/Entry',
                    value: entriesCount > 0 
                        ? (totalProduction / entriesCount).toStringAsFixed(1)
                        : '0',
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  void _showAddStaffDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool obscurePassword = true;
    bool isLoading = false;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Staff Member'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Staff Name *',
                    hintText: 'Enter staff name',
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
                    hintText: 'Enter phone number',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email *',
                    hintText: 'Enter email address',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password *',
                    hintText: 'Enter password',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePassword ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setDialogState(() {
                          obscurePassword = !obscurePassword;
                        });
                      },
                    ),
                  ),
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
                final email = emailController.text.trim();
                final password = passwordController.text.trim();
                
                if (name.isEmpty || phone.isEmpty || email.isEmpty || password.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill all required fields'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                
                if (!email.contains('@') || !email.contains('.')) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid email address'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                
                if (password.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password must be at least 6 characters'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                
                setDialogState(() {
                  isLoading = true;
                });
                
                try {
                  // Create user account without affecting admin session
                  final userData = await widget.authService.createStaffAccount(
                    name: name,
                    email: email,
                    password: password,
                    role: 'staff',
                  );
                  
                  // Add staff to backend with user ID
                  final staff = Staff(
                    id: '', // Will be set by backend
                    name: name,
                    phoneNumber: phone,
                    joinedDate: DateTime.now(),
                  );
                  
                  final createdStaff = await widget.dataService.addStaff(staff, userData['id'], email);
                  
                  if (mounted) {
                    Navigator.pop(context);
                    setState(() {});
                    
                    if (createdStaff != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Staff account for "$name" created successfully!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('User created but failed to create staff record'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  }
                } catch (e) {
                  setDialogState(() {
                    isLoading = false;
                  });
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Create Account'),
            ),
          ],
        ),
      ),
    );
  }
}
