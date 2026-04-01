import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/inventory.dart';
import '../models/payment.dart';
import '../models/product.dart';
import '../models/stitch.dart';
import '../models/worker.dart';
import '../models/worker_category.dart';
import '../models/attendance.dart';
import 'auth_service.dart';

class DataService {
  final AuthService auth;
  DataService({required this.auth});
  final List<ProductCategory> categories = [];

  final Map<String, double> ratePerCategory = {};

  final List<Product> products = [];
  final List<StitchEntry> stitchEntries = [];
  final List<WorkerPayment> payments = [];
  final List<InventoryItem> inventory = [];
  final List<Worker> workers = [];
  final List<WorkerCategory> workerCategories = [];
  final List<AttendanceRecord> attendanceRecords = [];

  // Fetch worker categories
  Future<void> fetchWorkerCategories() async {
    try {
      final url = '${dotenv.env['API_URL']}/worker-categories';
      final response = await http.get(Uri.parse(url), headers: auth.authHeaders);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        workerCategories
          ..clear()
          ..addAll(data.map((e) => WorkerCategory.fromJson(e as Map<String, dynamic>)));
      }
    } catch (e) {
      print('Error fetching worker categories: $e');
    }
  }

  Future<WorkerCategory?> createWorkerCategory(String name) async {
    try {
      final url = '${dotenv.env['API_URL']}/worker-categories';
      final res = await http.post(
        Uri.parse(url),
        headers: auth.authHeaders,
        body: jsonEncode({'name': name}),
      );
      if (res.statusCode == 201 || res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final cat = WorkerCategory.fromJson(data);
        workerCategories.add(cat);
        return cat;
      }
    } catch (e) {
      print('Error creating worker category: $e');
    }
    return null;
  }

  Future<bool> deleteWorkerCategory(String categoryId) async {
    try {
      final url = '${dotenv.env['API_URL']}/worker-categories/$categoryId';
      final res = await http.delete(
        Uri.parse(url),
        headers: auth.authHeaders,
      );
      if (res.statusCode == 200 || res.statusCode == 204) {
        workerCategories.removeWhere((c) => c.id == categoryId);
        return true;
      }
    } catch (e) {
      print('Error deleting worker category: $e');
    }
    return false;
  }

  // Helper: compute weekly totals for a worker (last 7 days)
  Map<String, dynamic> weeklyTotalsForWorker(String workerId) {
    final since = DateTime.now().subtract(const Duration(days: 7));
    final entries = stitchEntries.where((e) => e.workerId == workerId && e.date.isAfter(since));
    final units = entries.fold<int>(0, (sum, e) => sum + e.quantity);
    final amount = calculateAmountForEntries(entries);
    return {'units': units, 'amount': amount};
  }

  // ========== PAYMENTS ==========

  Future<WorkerPayment?> createPayment({
    required String workerId,
    required double amount,
    required DateTime periodStart,
    required DateTime periodEnd,
    String status = 'pending',
    String? paymentMethod,
    String? razorpayPaymentId,
    String? razorpayOrderId,
  }) async {
    try {
      final url = '${dotenv.env['API_URL']}/payments';
      final body = {
        'worker': workerId,
        'amount': amount,
        'periodStart': periodStart.toIso8601String(),
        'periodEnd': periodEnd.toIso8601String(),
        'status': status,
        if (paymentMethod != null) 'paymentMethod': paymentMethod,
        if (razorpayPaymentId != null) 'razorpayPaymentId': razorpayPaymentId,
        if (razorpayOrderId != null) 'razorpayOrderId': razorpayOrderId,
      };
      
      final res = await http.post(
        Uri.parse(url),
        headers: auth.authHeaders,
        body: jsonEncode(body),
      );
      
      if (res.statusCode == 201 || res.statusCode == 200) {
        final p = jsonDecode(res.body);
        final statusStr = (p['status'] ?? 'pending').toString();
        final paymentStatus = statusStr == 'paid' ? PaymentStatus.paid : PaymentStatus.pending;
        final payment = WorkerPayment(
          id: (p['_id'] ?? '').toString(),
          workerId: (p['worker'] is Map) ? (p['worker']['_id'] ?? '').toString() : (p['worker'] ?? '').toString(),
          periodStart: DateTime.parse(p['periodStart']),
          periodEnd: DateTime.parse(p['periodEnd']),
          amount: (p['amount'] is num) ? (p['amount'] as num).toDouble() : double.tryParse(p['amount']?.toString() ?? '0') ?? 0.0,
          status: paymentStatus,
          paymentMethod: p['paymentMethod']?.toString(),
          razorpayPaymentId: p['razorpayPaymentId']?.toString(),
          razorpayOrderId: p['razorpayOrderId']?.toString(),
        );
        payments.add(payment);
        return payment;
      } else {
        throw Exception('Failed to create payment: ${res.statusCode}');
      }
    } catch (e) {
      print('Error creating payment: $e');
      rethrow;
    }
  }

  Future<void> fetchPayments() async {
    try {
      final url = '${dotenv.env['API_URL']}/payments';
      final res = await http.get(Uri.parse(url), headers: auth.authHeaders);
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        payments
          ..clear()
          ..addAll(list.map((p) {
            final statusStr = (p['status'] ?? 'pending').toString();
            final status = statusStr == 'paid' ? PaymentStatus.paid : PaymentStatus.pending;
            return WorkerPayment(
              id: (p['_id'] ?? '').toString(),
              workerId: (p['worker'] is Map) ? (p['worker']['_id'] ?? '').toString() : (p['worker'] ?? '').toString(),
              periodStart: DateTime.parse(p['periodStart']),
              periodEnd: DateTime.parse(p['periodEnd']),
              amount: (p['amount'] is num) ? (p['amount'] as num).toDouble() : double.tryParse(p['amount']?.toString() ?? '0') ?? 0.0,
              status: status,
              paymentMethod: p['paymentMethod']?.toString(),
              razorpayPaymentId: p['razorpayPaymentId']?.toString(),
              razorpayOrderId: p['razorpayOrderId']?.toString(),
            );
          }));
      } else {
        throw Exception('Failed to fetch payments: ${res.statusCode}');
      }
    } catch (e) {
      // swallow errors but keep app running
      print('Error fetching payments: $e');
    }
  }

  // Admin: fetch all production entries
  Future<void> fetchAllProduction() async {
    final url = '${dotenv.env['API_URL']}/production';
    final res = await http.get(Uri.parse(url), headers: auth.authHeaders);
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List<dynamic>;
      stitchEntries
        ..clear()
        ..addAll(list.map((e) {
          return StitchEntry(
            id: (e['_id'] ?? '').toString(),
            workerId: ((e['worker'] ?? '')).toString().isNotEmpty ? (e['worker'] ?? '').toString() : 'unknown',
            createdBy: ((e['staff'] ?? '')).toString(),
            categoryId: (e['category'] ?? '').toString(),
            quantity: (e['quantity'] is num) ? (e['quantity'] as num).toInt() : int.tryParse(e['quantity']?.toString() ?? '0') ?? 0,
            date: DateTime.tryParse((e['date'] ?? '').toString()) ?? DateTime.now(),
          );
        }));
      return;
    }
    throw Exception('Failed to fetch all production: ${res.statusCode}');
  }

  // Load rates from server into local caches: categories and ratePerCategory
  Future<void> syncRatesFromServer() async {
    final rates = await fetchRates();
    final cats = <ProductCategory>[];
    final seen = <String>{};
    ratePerCategory.clear();
    for (final r in rates) {
      final category = (r['category'] ?? '').toString();
      final amount = (r['amount'] is num) ? (r['amount'] as num).toDouble() : double.tryParse(r['amount']?.toString() ?? '0') ?? 0.0;
      if (category.isEmpty) continue;
      ratePerCategory[category] = amount;
      if (!seen.contains(category)) {
        seen.add(category);
        cats.add(ProductCategory(id: category, name: _titleCase(category.replaceAll('_', ' '))));
      }
    }
    categories
      ..clear()
      ..addAll(cats);
  }

  String _titleCase(String input) {
    if (input.isEmpty) return input;
    return input.split(' ').map((w) => w.isEmpty ? w : (w[0].toUpperCase() + w.substring(1))).join(' ');
  }

  double calculateAmountForEntries(Iterable<StitchEntry> entries) {
    double total = 0;
    for (final e in entries) {
      final rate = ratePerCategory[e.categoryId] ?? 0;
      total += rate * e.quantity;
    }
    return total;
  }

  // ========== WORKER MANAGEMENT ==========

  // Fetch all workers from backend
  Future<void> fetchWorkers() async {
    try {
      final url = '${dotenv.env['API_URL']}/workers';
      final response = await http.get(Uri.parse(url), headers: auth.authHeaders);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        workers.clear();
        for (var item in data) {
          workers.add(Worker.fromJson(item));
        }
      }
    } catch (e) {
      print('Error fetching workers: $e');
    }
  }

  // Add a new worker to backend
  Future<Worker?> addWorker(Worker worker, {String? categoryId}) async {
    try {
      final url = '${dotenv.env['API_URL']}/workers';
      final response = await http.post(
        Uri.parse(url),
        headers: auth.authHeaders,
        body: jsonEncode({
          'name': worker.name,
          'phoneNumber': worker.phoneNumber,
          if (worker.email != null) 'email': worker.email,
          'address': worker.address,
          'notes': worker.notes,
          'dailyWage': worker.dailyWage,
          if (categoryId != null && categoryId.isNotEmpty) 'category': categoryId
          else if (worker.category != null) 'category': worker.category!.id,
        }),
      );
      
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final newWorker = Worker.fromJson(data);
        workers.add(newWorker);
        return newWorker;
      }
    } catch (e) {
      print('Error adding worker: $e');
    }
    return null;
  }

  // Remove a worker
  Future<bool> removeWorker(String workerId) async {
    try {
      final url = '${dotenv.env['API_URL']}/workers/$workerId';
      final response = await http.delete(Uri.parse(url), headers: auth.authHeaders);
      
      if (response.statusCode == 200) {
        workers.removeWhere((w) => w.id == workerId);
        return true;
      }
    } catch (e) {
      print('Error removing worker: $e');
    }
    return false;
  }

  // ========== PRODUCTS ==========

  // ========== PRODUCTION (ADMIN) ==========

  Future<void> fetchMyProduction() async {
    final url = '${dotenv.env['API_URL']}/production/me';
    final res = await http.get(Uri.parse(url), headers: auth.authHeaders);
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List<dynamic>;
      stitchEntries
        ..clear()
        ..addAll(list.map((e) {
          return StitchEntry(
            id: (e['_id'] ?? '').toString(),
            workerId: ((e['worker'] ?? '')).toString().isNotEmpty ? (e['worker'] ?? '').toString() : 'unknown',
            createdBy: ((e['staff'] ?? auth.currentUser?.id ?? '')).toString(),
            categoryId: (e['category'] ?? '').toString(),
            quantity: (e['quantity'] is num) ? (e['quantity'] as num).toInt() : int.tryParse(e['quantity']?.toString() ?? '0') ?? 0,
            date: DateTime.tryParse((e['date'] ?? '').toString()) ?? DateTime.now(),
          );
        }));
      return;
    }
    throw Exception('Failed to fetch production: ${res.statusCode}');
  }

  Future<StitchEntry?> addProductionEntry({
    required String categoryId,
    required int quantity,
    DateTime? date,
    String? workerIdForUI,
  }) async {
    final url = '${dotenv.env['API_URL']}/production';
    final payload = {
      'category': categoryId,
      'quantity': quantity,
      'date': (date ?? DateTime.now()).toIso8601String(),
      if (workerIdForUI != null) 'worker': workerIdForUI,
    };
    final res = await http.post(
      Uri.parse(url),
      headers: auth.authHeaders,
      body: jsonEncode(payload),
    );
    if (res.statusCode == 201) {
      final e = jsonDecode(res.body) as Map<String, dynamic>;
      final entry = StitchEntry(
        id: (e['_id'] ?? '').toString(),
        workerId: ((e['worker'] ?? '')).toString().isNotEmpty ? (e['worker'] ?? '').toString() : (workerIdForUI ?? 'unknown'),
        createdBy: ((e['staff'] ?? auth.currentUser?.id ?? '')).toString(),
        categoryId: (e['category'] ?? '').toString(),
        quantity: (e['quantity'] is num) ? (e['quantity'] as num).toInt() : int.tryParse(e['quantity']?.toString() ?? '0') ?? 0,
        date: DateTime.tryParse((e['date'] ?? '').toString()) ?? DateTime.now(),
      );
      stitchEntries.add(entry);
      return entry;
    }
    return null;
  }

  Future<List<dynamic>> fetchProducts() async {
    final url = '${dotenv.env['API_URL']}/products';
    final res = await http.get(Uri.parse(url));
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as List<dynamic>;
    }
    throw Exception('Failed to fetch products');
  }

  Future<Map<String, dynamic>> createProduct({
    required String name,
    required double price,
    required String category,
    String description = '',
    String imageUrl = '',
  }) async {
    final url = '${dotenv.env['API_URL']}/products';
    final res = await http.post(
      Uri.parse(url),
      headers: auth.authHeaders,
      body: jsonEncode({
        'name': name,
        'price': price,
        'category': category,
        'description': description,
        'imageUrl': imageUrl,
      }),
    );
    if (res.statusCode == 201) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to create product: ${res.statusCode}');
  }

  Future<Map<String, dynamic>> updateProduct(String id, Map<String, dynamic> payload) async {
    final url = '${dotenv.env['API_URL']}/products/$id';
    final res = await http.put(
      Uri.parse(url),
      headers: auth.authHeaders,
      body: jsonEncode(payload),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to update product: ${res.statusCode}');
  }

  Future<bool> deleteProduct(String id) async {
    final url = '${dotenv.env['API_URL']}/products/$id';
    final res = await http.delete(Uri.parse(url), headers: auth.authHeaders);
    return res.statusCode == 200;
  }

  // ========== RATES ==========

  Future<List<dynamic>> fetchRates() async {
    final url = '${dotenv.env['API_URL']}/rates';
    final res = await http.get(Uri.parse(url));
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as List<dynamic>;
    }
    throw Exception('Failed to fetch rates');
  }

  Future<Map<String, dynamic>> upsertRate({required String category, required double amount}) async {
    final url = '${dotenv.env['API_URL']}/rates';
    final res = await http.post(
      Uri.parse(url),
      headers: auth.authHeaders,
      body: jsonEncode({'category': category, 'amount': amount}),
    );
    if (res.statusCode == 200 || res.statusCode == 201) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to upsert rate: ${res.statusCode}');
  }

  // Get worker by ID
  Worker? getWorkerById(String workerId) {
    try {
      return workers.firstWhere((w) => w.id == workerId);
    } catch (e) {
      return null;
    }
  }

  // Get active workers
  List<Worker> getActiveWorkers() {
    return workers.where((w) => w.isActive).toList();
  }

  // Fetch stitch entries from backend
  Future<void> fetchStitchEntries() async {
    try {
      final url = '${dotenv.env['API_URL']}/stitch-entries';
      print('Fetching stitch entries from: $url');
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        stitchEntries.clear();
        for (var item in data) {
          // Extract workerId - backend may return it as an object with _id field
          final workerIdValue = item['workerId'];
          final workerId = workerIdValue is String 
              ? workerIdValue 
              : (workerIdValue?['_id']?.toString() ?? 'unknown');
          final sVal = item['staff'] ?? item['staffId'] ?? auth.currentUser?.id ?? '';
          final createdBy = sVal is String ? sVal : (sVal?['_id']?.toString() ?? (auth.currentUser?.id ?? ''));
          
          stitchEntries.add(StitchEntry(
            id: (item['_id'] ?? '').toString(),
            workerId: workerId,
            createdBy: createdBy,
            categoryId: (item['categoryId'] ?? item['category'] ?? '').toString(),
            quantity: (item['quantity'] is num) ? (item['quantity'] as num).toInt() : int.tryParse(item['quantity']?.toString() ?? '0') ?? 0,
            date: DateTime.tryParse((item['date'] ?? '').toString()) ?? DateTime.now(),
          ));
        }
        print('✅ Fetched ${stitchEntries.length} stitch entries');
      } else {
        print('❌ Failed to fetch stitch entries: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('❌ Error fetching stitch entries: $e');
      print('Stack trace: $stackTrace');
    }
  }

  // Add stitch entry to backend
  Future<StitchEntry?> addStitchEntry(StitchEntry entry) async {
    try {
      final url = '${dotenv.env['API_URL']}/stitch-entries';
      print('Adding stitch entry to: $url');
      print('Worker: ${entry.workerId}, Category: ${entry.categoryId}, Quantity: ${entry.quantity}');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'workerId': entry.workerId,
          'categoryId': entry.categoryId,
          'quantity': entry.quantity,
          'date': entry.date.toIso8601String(),
        }),
      );
      
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        
        // Extract workerId - backend returns it as an object with _id field
        final workerIdValue = data['workerId'];
        final workerId = workerIdValue is String 
            ? workerIdValue 
            : workerIdValue['_id'] as String;
        
        final sVal = data['staff'] ?? data['staffId'] ?? auth.currentUser?.id ?? '';
        final createdBy = sVal is String ? sVal : (sVal?['_id']?.toString() ?? (auth.currentUser?.id ?? ''));
        final savedEntry = StitchEntry(
          id: (data['_id'] ?? '').toString(),
          workerId: workerId,
          createdBy: createdBy,
          categoryId: (data['categoryId'] ?? data['category'] ?? '').toString(),
          quantity: (data['quantity'] is num) ? (data['quantity'] as num).toInt() : int.tryParse(data['quantity']?.toString() ?? '0') ?? 0,
          date: DateTime.tryParse((data['date'] ?? '').toString()) ?? DateTime.now(),
        );
        stitchEntries.add(savedEntry);
        print('✅ Stitch entry added successfully');
        return savedEntry;
      } else {
        print('❌ Failed to add stitch entry: ${response.statusCode} - ${response.body}');
      }
    } catch (e, stackTrace) {
      print('❌ Error adding stitch entry: $e');
      print('Stack trace: $stackTrace');
    }
    return null;
  }

  // Get total revenue (all entries)
  Future<double> getTotalRevenue() async {
    try {
      final url = '${dotenv.env['API_URL']}/stitch-entries/total-revenue';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['totalRevenue'] as num).toDouble();
      }
    } catch (e) {
      print('Error fetching total revenue: $e');
    }
    return 0.0;
  }

  // Get weekly statistics
  Future<Map<String, dynamic>> getWeeklyStats() async {
    try {
      final url = '${dotenv.env['API_URL']}/stitch-entries/weekly-stats';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Error fetching weekly stats: $e');
    }
    return {};
  }

  // ═══ ATTENDANCE ═══

  Future<void> fetchAttendance(DateTime date) async {
    try {
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final url = '${dotenv.env['API_URL']}/attendance?date=$dateStr';
      final response = await http.get(Uri.parse(url), headers: auth.authHeaders);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        attendanceRecords
          ..clear()
          ..addAll(data.map((e) => AttendanceRecord.fromJson(e as Map<String, dynamic>)));
      }
    } catch (e) {
      print('Error fetching attendance: $e');
    }
  }

  Future<List<AttendanceRecord>?> markAttendance({
    required DateTime date,
    required List<String> workerIds,
    String status = 'present',
    String? notes,
  }) async {
    try {
      final url = '${dotenv.env['API_URL']}/attendance';
      final body = {
        'date': date.toIso8601String(),
        'workers': workerIds,
        'status': status,
        if (notes != null) 'notes': notes,
      };
      final response = await http.post(
        Uri.parse(url),
        headers: auth.authHeaders,
        body: jsonEncode(body),
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final records = data.map((e) => AttendanceRecord.fromJson(e as Map<String, dynamic>)).toList();
        // Refresh the list
        await fetchAttendance(date);
        return records;
      }
    } catch (e) {
      print('Error marking attendance: $e');
    }
    return null;
  }

  Future<bool> updateAttendanceStatus(String id, String status) async {
    try {
      final url = '${dotenv.env['API_URL']}/attendance/$id';
      final response = await http.put(
        Uri.parse(url),
        headers: auth.authHeaders,
        body: jsonEncode({'status': status}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating attendance: $e');
    }
    return false;
  }

  Future<bool> deleteAttendance(String id) async {
    try {
      final url = '${dotenv.env['API_URL']}/attendance/$id';
      final response = await http.delete(Uri.parse(url), headers: auth.authHeaders);
      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting attendance: $e');
    }
    return false;
  }
}


