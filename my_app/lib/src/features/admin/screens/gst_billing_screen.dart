import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/data_service.dart';
import '../../../core/models/gst_setting.dart';
import '../../../core/models/gst_summary.dart';
import '../../../core/utils/export_helper.dart';

class GstBillingTab extends StatefulWidget {
  final DataService dataService;
  const GstBillingTab({super.key, required this.dataService});

  @override
  State<GstBillingTab> createState() => _GstBillingTabState();
}

class _GstBillingTabState extends State<GstBillingTab> {
  bool _loading = true;
  List<BrandBill> _bills = [];
  GstSetting? _gst;
  GstSummary? _gstSummary;
  final _dateFormat = DateFormat('dd/MM/yyyy');
  DateTime? _filterStart;
  DateTime? _filterEnd;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try { await widget.dataService.fetchGstSettings(); } catch (_) {}
    try { await widget.dataService.fetchBilling(startDate: _filterStart, endDate: _filterEnd); } catch (_) {}
    try { await widget.dataService.fetchGstSummary(startDate: _filterStart, endDate: _filterEnd); } catch (_) {}
    if (!mounted) return;
    setState(() {
      _gst = widget.dataService.gstSetting;
      _bills = widget.dataService.brandBills;
      _gstSummary = widget.dataService.gstSummary;
      _loading = false;
    });
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _filterStart != null && _filterEnd != null
          ? DateTimeRange(start: _filterStart!, end: _filterEnd!)
          : null,
    );
    if (picked != null) {
      _filterStart = picked.start;
      _filterEnd = picked.end;
      _loadData();
    }
  }

  void _clearDateFilter() {
    _filterStart = null;
    _filterEnd = null;
    _loadData();
  }

  void _showGstPayableBill() {
    if (_gstSummary == null) return;
    final s = _gstSummary!;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Column(children: [
                Text(_gst?.companyName ?? 'Vijayalakshmi Garments', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                if ((_gst?.gstin ?? '').isNotEmpty)
                  Text('GSTIN: ${_gst!.gstin}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                const Text('GST PAYABLE STATEMENT', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2)),
                if (_filterStart != null && _filterEnd != null)
                  Text('Period: ${_dateFormat.format(_filterStart!)} - ${_dateFormat.format(_filterEnd!)}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              ])),
              const Divider(thickness: 2),
              const SizedBox(height: 8),
              const Text('OUTPUT GST (On Sales)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              _billRow('CGST Collected', '₹${s.outputGst.cgst.toStringAsFixed(2)}'),
              _billRow('SGST Collected', '₹${s.outputGst.sgst.toStringAsFixed(2)}'),
              _billRow('Total Output GST', '₹${s.outputGst.total.toStringAsFixed(2)}', bold: true),
              const SizedBox(height: 12),
              const Text('INPUT GST (On Purchases)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              _billRow('CGST Paid', '₹${s.inputGst.cgst.toStringAsFixed(2)}'),
              _billRow('SGST Paid', '₹${s.inputGst.sgst.toStringAsFixed(2)}'),
              _billRow('Total Input GST', '₹${s.inputGst.total.toStringAsFixed(2)}', bold: true),
              const Divider(thickness: 2),
              _billRow(
                s.isCredit ? 'INPUT TAX CREDIT (ITC)' : 'NET GST PAYABLE',
                '₹${s.netGstPayable.abs().toStringAsFixed(2)}',
                bold: true, size: 16,
                color: s.isCredit ? const Color(0xFF50C878) : Colors.red,
              ),
              const SizedBox(height: 16),
              const Divider(),
              Center(child: Text(
                s.isCredit ? 'You have Input Tax Credit to carry forward' : 'Amount payable to Government',
                style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey[600], fontSize: 12),
              )),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  // ═══ GST SETTINGS DIALOG ═══
  void _showGstSettingsDialog() {
    final cgstCtrl = TextEditingController(text: (_gst?.cgstPercent ?? 2.5).toString());
    final sgstCtrl = TextEditingController(text: (_gst?.sgstPercent ?? 2.5).toString());
    final nameCtrl = TextEditingController(text: _gst?.companyName ?? 'Vijayalakshmi Garments');
    final addrCtrl = TextEditingController(text: _gst?.companyAddress ?? '');
    final phoneCtrl = TextEditingController(text: _gst?.companyPhone ?? '');
    final gstinCtrl = TextEditingController(text: _gst?.gstin ?? '');
    final prefixCtrl = TextEditingController(text: _gst?.invoicePrefix ?? 'VLG-');
    final invoiceNumCtrl = TextEditingController(text: (_gst?.lastInvoiceNumber ?? 0).toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFF4A90E2).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.settings, color: Color(0xFF4A90E2)),
          ),
          const SizedBox(width: 12),
          const Text('GST Settings'),
        ]),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Company Name', prefixIcon: Icon(Icons.business))),
            const SizedBox(height: 12),
            TextField(controller: addrCtrl, decoration: const InputDecoration(labelText: 'Address', prefixIcon: Icon(Icons.location_on)), maxLines: 2),
            const SizedBox(height: 12),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone)), keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            TextField(controller: gstinCtrl, decoration: const InputDecoration(labelText: 'GSTIN', prefixIcon: Icon(Icons.receipt_long))),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Text('Tax Rates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: cgstCtrl, decoration: const InputDecoration(labelText: 'CGST %', prefixIcon: Icon(Icons.percent)), keyboardType: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: sgstCtrl, decoration: const InputDecoration(labelText: 'SGST %', prefixIcon: Icon(Icons.percent)), keyboardType: TextInputType.number)),
            ]),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Text('Invoice Numbering', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: prefixCtrl, decoration: const InputDecoration(labelText: 'Prefix', prefixIcon: Icon(Icons.tag), hintText: 'VLG-'))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: invoiceNumCtrl, decoration: const InputDecoration(labelText: 'Next No.', prefixIcon: Icon(Icons.numbers)), keyboardType: TextInputType.number)),
            ]),
            const SizedBox(height: 4),
            Text('Next invoice: ${prefixCtrl.text}${((int.tryParse(invoiceNumCtrl.text) ?? 0) + 1).toString().padLeft(4, '0')}',
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Save'),
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await widget.dataService.updateGstSettings(
                cgstPercent: double.tryParse(cgstCtrl.text) ?? 2.5,
                sgstPercent: double.tryParse(sgstCtrl.text) ?? 2.5,
                companyName: nameCtrl.text,
                companyAddress: addrCtrl.text,
                companyPhone: phoneCtrl.text,
                gstin: gstinCtrl.text,
                invoicePrefix: prefixCtrl.text,
                lastInvoiceNumber: int.tryParse(invoiceNumCtrl.text) ?? 0,
              );
              if (res != null && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ GST settings updated'), backgroundColor: Colors.green));
                _loadData();
              }
            },
          ),
        ],
      ),
    );
  }

  // ═══ BILL PREVIEW DIALOG ═══
  void _showBillPreview(BrandBill bill) {
    final billDate = bill.date != null ? _dateFormat.format(bill.date!) : _dateFormat.format(DateTime.now());

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Header
              Center(child: Column(children: [
                Text(_gst?.companyName ?? 'Vijayalakshmi Garments', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                if ((_gst?.companyAddress ?? '').isNotEmpty)
                  Text(_gst!.companyAddress, style: TextStyle(fontSize: 12, color: Colors.grey[600]), textAlign: TextAlign.center),
                if ((_gst?.companyPhone ?? '').isNotEmpty)
                  Text('Ph: ${_gst!.companyPhone}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                if ((_gst?.gstin ?? '').isNotEmpty)
                  Text('GSTIN: ${_gst!.gstin}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                const Text('TAX INVOICE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2)),
              ])),
              const Divider(thickness: 2),

              // Invoice details row
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (bill.invoiceNumber.isNotEmpty)
                    Text('Invoice #: ${bill.invoiceNumber}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF4A90E2))),
                  Text('Date: $billDate', style: const TextStyle(fontSize: 12)),
                ]),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFF9B59B6).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text(bill.brandName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF9B59B6))),
                ),
              ]),
              const Divider(),

              // Items table
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                color: Colors.grey[100],
                child: const Row(children: [
                  Expanded(flex: 3, child: Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  Expanded(flex: 2, child: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: Text('Rate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
                  Expanded(flex: 2, child: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(children: [
                  Expanded(flex: 3, child: Text(bill.brandName, style: const TextStyle(fontSize: 12))),
                  Expanded(flex: 2, child: Text('${bill.totalQuantity}', style: const TextStyle(fontSize: 12), textAlign: TextAlign.center)),
                  Expanded(flex: 2, child: Text('₹${bill.sellingRate.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12), textAlign: TextAlign.right)),
                  Expanded(flex: 2, child: Text('₹${bill.taxableAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12), textAlign: TextAlign.right)),
                ]),
              ),
              const Divider(),

              // Tax breakdown
              _billRow('Taxable Amount', '₹${bill.taxableAmount.toStringAsFixed(2)}'),
              _billRow('CGST @ ${bill.cgstPercent}%', '₹${bill.cgstAmount.toStringAsFixed(2)}'),
              _billRow('SGST @ ${bill.sgstPercent}%', '₹${bill.sgstAmount.toStringAsFixed(2)}'),
              const Divider(thickness: 2),
              _billRow('Grand Total', '₹${bill.grandTotal.toStringAsFixed(2)}', bold: true, size: 16),
              const SizedBox(height: 8),
              _billRow('Production Cost', '₹${bill.totalProductionCost.toStringAsFixed(2)}', color: Colors.grey[600]),

              const SizedBox(height: 20),
              const Divider(),
              Center(child: Text('Thank You for Your Business!', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey[600], fontSize: 12))),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _billRow(String label, String value, {bool bold = false, double size = 13, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: size, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color)),
        Text(value, style: TextStyle(fontSize: size, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color)),
      ]),
    );
  }

  // ═══ BUILD ═══
  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final totalTaxable = _bills.fold<double>(0, (s, b) => s + b.taxableAmount);
    final totalGst = _bills.fold<double>(0, (s, b) => s + b.totalGst);
    final totalGrand = _bills.fold<double>(0, (s, b) => s + b.grandTotal);

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Title + Settings + Export
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(
              child: Text('GST & Billing', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.grey[800])),
            ),
            Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                icon: const Icon(Icons.file_download_outlined, color: Color(0xFF4A90E2)),
                tooltip: 'Export to Excel',
                onPressed: () => ExportHelper.exportToExcel(context, widget.dataService, 'gst-billing', startDate: _filterStart, endDate: _filterEnd),
              ),
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.grey),
                tooltip: 'GST Settings',
                onPressed: _showGstSettingsDialog,
              ),
            ]),
          ]),
          const SizedBox(height: 8),

          // Date Range Filter
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: _pickDateRange,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(children: [
                      Icon(Icons.date_range, size: 18, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        _filterStart != null && _filterEnd != null
                            ? '${_dateFormat.format(_filterStart!)} - ${_dateFormat.format(_filterEnd!)}'
                            : 'All Time (tap to filter)',
                        style: TextStyle(fontSize: 13, color: _filterStart != null ? Colors.black87 : Colors.grey[500]),
                      ),
                    ]),
                  ),
                ),
              ),
              if (_filterStart != null)
                IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: _clearDateFilter,
                ),
            ]),
          ),

          // GST Payable Summary Card
          if (_gstSummary != null) ...[
            GestureDetector(
              onTap: _showGstPayableBill,
              child: Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    _gstSummary!.isCredit ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C),
                    _gstSummary!.isCredit ? const Color(0xFF27AE60) : const Color(0xFFC0392B),
                  ]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(_gstSummary!.isCredit ? Icons.trending_down : Icons.trending_up, color: Colors.white, size: 22),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      _gstSummary!.isCredit ? 'Input Tax Credit (ITC)' : 'Net GST Payable',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    )),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                      child: const Text('View Bill', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Center(child: Text(
                    '₹${_gstSummary!.netGstPayable.abs().toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 32),
                  )),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _gstSummaryChip('Output GST', '₹${_gstSummary!.outputGst.total.toStringAsFixed(0)}', '${_gstSummary!.outputGst.itemCount} sales')),
                    const SizedBox(width: 8),
                    Expanded(child: _gstSummaryChip('Input GST', '₹${_gstSummary!.inputGst.total.toStringAsFixed(0)}', '${_gstSummary!.inputGst.itemCount} purchases')),
                  ]),
                ]),
              ),
            ),
          ],

          // GST config card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF4A90E2), Color(0xFF357ABD)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.receipt_long, color: Colors.white, size: 22),
                const SizedBox(width: 8),
                const Expanded(child: Text('Current GST Configuration', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
                GestureDetector(
                  onTap: _showGstSettingsDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                    child: const Text('Edit', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Wrap(spacing: 12, runSpacing: 8, children: [
                _gstChip('CGST', '${_gst?.cgstPercent ?? 2.5}%'),
                _gstChip('SGST', '${_gst?.sgstPercent ?? 2.5}%'),
                _gstChip('Total', '${(_gst?.totalGstPercent ?? 5.0)}%'),
                _gstChip('Invoice#', '${_gst?.invoicePrefix ?? "VLG-"}${((_gst?.lastInvoiceNumber ?? 0) + 1).toString().padLeft(4, '0')}'),
              ]),
              if ((_gst?.gstin ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('GSTIN: ${_gst!.gstin}', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12)),
              ],
            ]),
          ),
          const SizedBox(height: 20),

          // Summary stats
          Row(children: [
            Expanded(child: _statCard('Taxable', '₹${totalTaxable.toStringAsFixed(0)}', Icons.attach_money, const Color(0xFF4A90E2))),
            const SizedBox(width: 10),
            Expanded(child: _statCard('Total GST', '₹${totalGst.toStringAsFixed(0)}', Icons.account_balance, const Color(0xFFFF9500))),
            const SizedBox(width: 10),
            Expanded(child: _statCard('Grand Total', '₹${totalGrand.toStringAsFixed(0)}', Icons.receipt, const Color(0xFF50C878))),
          ]),
          const SizedBox(height: 24),

          // Individual bills
          Row(children: [
            Expanded(child: Text('Individual Bills', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.grey[800]))),
            Text('${_bills.length} bills', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          ]),
          const SizedBox(height: 12),

          if (_bills.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(children: [
                  Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('No Billing Data', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                  const SizedBox(height: 8),
                  Text('Log completed products to generate bills', style: TextStyle(color: Colors.grey[600])),
                ]),
              ),
            )
          else
            ..._bills.map((bill) => _buildBillCard(bill)),
        ]),
      ),
    );
  }

  Widget _gstChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
      child: Column(children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10)),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
      ]),
    );
  }

  Widget _gstSummaryChip(String label, String value, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11)),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10)),
      ]),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 8),
        FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color))),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ]),
    );
  }

  Widget _buildBillCard(BrandBill bill) {
    final billDate = bill.date != null ? _dateFormat.format(bill.date!) : '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header row with invoice number
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFF9B59B6).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.receipt, color: Color(0xFF9B59B6), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (bill.invoiceNumber.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFF4A90E2).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text(bill.invoiceNumber, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4A90E2))),
                ),
              if (bill.invoiceNumber.isNotEmpty) const SizedBox(width: 8),
              Flexible(child: Text(bill.brandName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 2),
            Text('$billDate  •  ${bill.totalQuantity} units  •  ₹${bill.sellingRate.toStringAsFixed(0)}/unit', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ])),
          FilledButton.icon(
            onPressed: () => _showBillPreview(bill),
            icon: const Icon(Icons.visibility, size: 16),
            label: const Text('Bill'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
        ]),
        const Divider(height: 24),
        // Tax breakdown
        _taxRow('Taxable Amount', '₹${bill.taxableAmount.toStringAsFixed(2)}', Colors.black87),
        _taxRow('CGST @ ${bill.cgstPercent}%', '₹${bill.cgstAmount.toStringAsFixed(2)}', const Color(0xFF4A90E2)),
        _taxRow('SGST @ ${bill.sgstPercent}%', '₹${bill.sgstAmount.toStringAsFixed(2)}', const Color(0xFF4A90E2)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(color: const Color(0xFF50C878).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Grand Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text('₹${bill.grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF50C878))),
          ]),
        ),
      ]),
    );
  }

  Widget _taxRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 13, color: color)),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }
}
