import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/data_service.dart';
import '../../../core/models/stitch.dart';
import '../../../core/models/staff.dart';

class StaffDetailScreen extends StatefulWidget {
  final DataService dataService;
  final String staffId;

  const StaffDetailScreen({
    super.key,
    required this.dataService,
    required this.staffId,
  });

  @override
  State<StaffDetailScreen> createState() => _StaffDetailScreenState();
}

class _StaffDetailScreenState extends State<StaffDetailScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await Future.wait([
      widget.dataService.fetchStaff(),
      widget.dataService.fetchAllProduction(),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  List<StitchEntry> _entriesByStaff() {
    return widget.dataService.stitchEntries
        .where((e) => e.staffId == widget.staffId)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  @override
  Widget build(BuildContext context) {
    // Accept either Staff document id or User id in widget.staffId
    Staff? staff = widget.dataService.getStaffById(widget.staffId);
    if (staff == null) {
      final matches = widget.dataService.staffMembers.where((s) => s.userId == widget.staffId);
      if (matches.isNotEmpty) {
        staff = matches.first;
      }
    }
    final String targetUserId = staff?.userId ?? widget.staffId;

    final entries = widget.dataService.stitchEntries
        .where((e) => e.staffId == targetUserId)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final dateFmt = DateFormat('MMM dd, yyyy');

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(staff?.name ?? 'Staff'),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: Staff details
                  Container(
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
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: Colors.white,
                          child: Text(
                            (staff?.name.isNotEmpty == true ? staff!.name[0] : '?').toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                              fontSize: 24,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                staff?.name ?? widget.staffId,
                                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              if (staff != null) ...[
                                Row(children: [
                                  const Icon(Icons.phone, size: 14, color: Colors.white70),
                                  const SizedBox(width: 6),
                                  Text(staff.phoneNumber, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                ]),
                                if ((staff.email ?? '').isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Row(children: [
                                    const Icon(Icons.email, size: 14, color: Colors.white70),
                                    const SizedBox(width: 6),
                                    Text(staff.email!, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                  ]),
                                ],
                                const SizedBox(height: 4),
                                Row(children: [
                                  const Icon(Icons.calendar_today, size: 14, color: Colors.white70),
                                  const SizedBox(width: 6),
                                  Text('Joined: ' + dateFmt.format(staff?.joinedDate ?? DateTime.now()),
                                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                ]),
                              ],
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                                child: Text('${entries.length} total entries',
                                    style: const TextStyle(color: Colors.white, fontSize: 12)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  Text('Entries by this staff',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.grey[800])),
                  const SizedBox(height: 12),

                  if (entries.isEmpty) _buildEmptyState() else ...entries.map(_buildEntryTile).toList(),
                ],
              ),
            ),
    );
  }

  Widget _buildEntryTile(StitchEntry entry) {
    final dateFormat = DateFormat('MMM dd, yyyy HH:mm');
    final categoryName = widget.dataService.categories
        .firstWhere((c) => c.id == entry.categoryId, orElse: () => widget.dataService.categories.first)
        .name;
    final worker = widget.dataService.getWorkerById(entry.workerId);
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
            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.inventory_2, color: Colors.blue, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(categoryName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text('Worker: ' + (worker?.name ?? entry.workerId), style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              const SizedBox(height: 2),
              Text('Quantity: ${entry.quantity}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('₹' + amount.toStringAsFixed(0),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
            Text(dateFormat.format(entry.date), style: TextStyle(color: Colors.grey[600], fontSize: 11)),
          ]),
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
            Text('No Entries', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[700])),
            const SizedBox(height: 8),
            Text('This staff has not added any entries yet', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}
