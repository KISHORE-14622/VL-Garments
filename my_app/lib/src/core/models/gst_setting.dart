class GstSetting {
  final String id;
  final double cgstPercent;
  final double sgstPercent;
  final String companyName;
  final String companyAddress;
  final String companyPhone;
  final String gstin;
  final int lastInvoiceNumber;
  final String invoicePrefix;

  GstSetting({
    required this.id,
    required this.cgstPercent,
    required this.sgstPercent,
    this.companyName = 'Vijayalakshmi Garments',
    this.companyAddress = '',
    this.companyPhone = '',
    this.gstin = '',
    this.lastInvoiceNumber = 0,
    this.invoicePrefix = 'VLG-',
  });

  factory GstSetting.fromJson(Map<String, dynamic> json) {
    return GstSetting(
      id: (json['_id'] ?? '').toString(),
      cgstPercent: (json['cgstPercent'] as num?)?.toDouble() ?? 2.5,
      sgstPercent: (json['sgstPercent'] as num?)?.toDouble() ?? 2.5,
      companyName: json['companyName'] as String? ?? 'Vijayalakshmi Garments',
      companyAddress: json['companyAddress'] as String? ?? '',
      companyPhone: json['companyPhone'] as String? ?? '',
      gstin: json['gstin'] as String? ?? '',
      lastInvoiceNumber: (json['lastInvoiceNumber'] as num?)?.toInt() ?? 0,
      invoicePrefix: json['invoicePrefix'] as String? ?? 'VLG-',
    );
  }

  double get totalGstPercent => cgstPercent + sgstPercent;
}

class BrandBill {
  final String entryId;
  final String invoiceNumber;
  final String brandName;
  final DateTime? date;
  final int totalQuantity;
  final double sellingRate;
  final double totalProductionCost;
  final double taxableAmount;
  final double cgstPercent;
  final double cgstAmount;
  final double sgstPercent;
  final double sgstAmount;
  final double totalGst;
  final double grandTotal;

  BrandBill({
    this.entryId = '',
    this.invoiceNumber = '',
    required this.brandName,
    this.date,
    required this.totalQuantity,
    this.sellingRate = 0,
    required this.totalProductionCost,
    required this.taxableAmount,
    required this.cgstPercent,
    required this.cgstAmount,
    required this.sgstPercent,
    required this.sgstAmount,
    required this.totalGst,
    required this.grandTotal,
  });

  factory BrandBill.fromJson(Map<String, dynamic> json) {
    return BrandBill(
      entryId: (json['entryId'] ?? '').toString(),
      invoiceNumber: json['invoiceNumber'] as String? ?? '',
      brandName: json['brandName'] as String? ?? 'Unknown',
      date: json['date'] != null ? DateTime.tryParse(json['date'].toString()) : null,
      totalQuantity: (json['totalQuantity'] as num?)?.toInt() ?? 0,
      sellingRate: (json['sellingRate'] as num?)?.toDouble() ?? 0,
      totalProductionCost: (json['totalProductionCost'] as num?)?.toDouble() ?? 0,
      taxableAmount: (json['taxableAmount'] as num?)?.toDouble() ?? 0,
      cgstPercent: (json['cgstPercent'] as num?)?.toDouble() ?? 0,
      cgstAmount: (json['cgstAmount'] as num?)?.toDouble() ?? 0,
      sgstPercent: (json['sgstPercent'] as num?)?.toDouble() ?? 0,
      sgstAmount: (json['sgstAmount'] as num?)?.toDouble() ?? 0,
      totalGst: (json['totalGst'] as num?)?.toDouble() ?? 0,
      grandTotal: (json['grandTotal'] as num?)?.toDouble() ?? 0,
    );
  }
}
