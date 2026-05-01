class GstSummary {
  final GstBreakdown inputGst;
  final GstBreakdown outputGst;
  final double netGstPayable;
  final bool isCredit;
  final String companyName;
  final String gstin;

  GstSummary({
    required this.inputGst,
    required this.outputGst,
    required this.netGstPayable,
    required this.isCredit,
    this.companyName = '',
    this.gstin = '',
  });

  factory GstSummary.fromJson(Map<String, dynamic> json) {
    return GstSummary(
      inputGst: GstBreakdown.fromJson(json['inputGst'] as Map<String, dynamic>? ?? {}),
      outputGst: GstBreakdown.fromJson(json['outputGst'] as Map<String, dynamic>? ?? {}),
      netGstPayable: (json['netGstPayable'] as num?)?.toDouble() ?? 0,
      isCredit: json['isCredit'] as bool? ?? false,
      companyName: (json['gstSettings']?['companyName'] as String?) ?? '',
      gstin: (json['gstSettings']?['gstin'] as String?) ?? '',
    );
  }
}

class GstBreakdown {
  final double cgst;
  final double sgst;
  final double total;
  final int itemCount;

  GstBreakdown({
    required this.cgst,
    required this.sgst,
    required this.total,
    required this.itemCount,
  });

  factory GstBreakdown.fromJson(Map<String, dynamic> json) {
    return GstBreakdown(
      cgst: (json['cgst'] as num?)?.toDouble() ?? 0,
      sgst: (json['sgst'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0,
      itemCount: (json['itemCount'] as num?)?.toInt() ?? 0,
    );
  }
}
