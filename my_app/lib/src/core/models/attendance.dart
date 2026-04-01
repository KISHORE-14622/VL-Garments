class AttendanceRecord {
  final String id;
  final DateTime date;
  final String workerId;
  final String? workerName;
  final String? workerPhone;
  final String status; // present, absent, half-day
  final String? notes;

  const AttendanceRecord({
    required this.id,
    required this.date,
    required this.workerId,
    this.workerName,
    this.workerPhone,
    this.status = 'present',
    this.notes,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    String workerId = '';
    String? workerName;
    String? workerPhone;
    final raw = json['worker'];
    if (raw is Map<String, dynamic>) {
      workerId = raw['_id'] ?? raw['id'] ?? '';
      workerName = raw['name'];
      workerPhone = raw['phoneNumber'];
    } else if (raw is String) {
      workerId = raw;
    }

    return AttendanceRecord(
      id: json['_id'] ?? json['id'] ?? '',
      date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
      workerId: workerId,
      workerName: workerName,
      workerPhone: workerPhone,
      status: json['status'] ?? 'present',
      notes: json['notes'],
    );
  }
}
