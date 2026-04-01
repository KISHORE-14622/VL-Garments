enum PaymentStatus { pending, paid }

class WorkerPayment {
  final String id;
  final String workerId;
  final DateTime periodStart;
  final DateTime periodEnd;
  final double amount;
  final PaymentStatus status;
  final String? paymentMethod; // 'cash', 'razorpay', etc.
  final String? razorpayPaymentId;
  final String? razorpayOrderId;

  const WorkerPayment({
    required this.id,
    required this.workerId,
    required this.periodStart,
    required this.periodEnd,
    required this.amount,
    required this.status,
    this.paymentMethod,
    this.razorpayPaymentId,
    this.razorpayOrderId,
  });
}


