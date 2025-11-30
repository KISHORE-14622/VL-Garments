enum PaymentStatus { pending, paid }

class StaffPayment {
  final String id;
  final String staffId;
  final DateTime periodStart;
  final DateTime periodEnd;
  final double amount;
  final PaymentStatus status;
  final String? paymentMethod; // 'cash', 'razorpay', etc.
  final String? razorpayPaymentId;
  final String? razorpayOrderId;

  const StaffPayment({
    required this.id,
    required this.staffId,
    required this.periodStart,
    required this.periodEnd,
    required this.amount,
    required this.status,
    this.paymentMethod,
    this.razorpayPaymentId,
    this.razorpayOrderId,
  });
}


