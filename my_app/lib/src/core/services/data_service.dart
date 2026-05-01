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
import '../models/completed_product.dart';
import '../models/brand.dart';
import '../models/gst_setting.dart';
import '../models/gst_summary.dart';
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
  final List<CompletedProduct> completedProducts = [];
  final List<Brand> brands = [];
  GstSetting? gstSetting;
  List<BrandBill> brandBills = [];
  GstSummary? gstSummary;

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

  // ========== BRANDS ==========
  
  Future<void> fetchBrands() async {
    try {
      final url = '${dotenv.env['API_URL']}/brands';
      final response = await http.get(Uri.parse(url), headers: auth.authHeaders);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        brands
          ..clear()
          ..addAll(data.map((e) => Brand.fromJson(e as Map<String, dynamic>)));
      }
    } catch (e) {
      print('Error fetching brands: $e');
    }
  }

  Future<Brand?> addBrand({required String name, required double sellingRate, required double costPerUnit}) async {
    try {
      final url = '${dotenv.env['API_URL']}/brands';
      final res = await http.post(
        Uri.parse(url),
        headers: auth.authHeaders,
        body: jsonEncode({
          'name': name,
          'sellingRate': sellingRate,
          'costPerUnit': costPerUnit,
        }),
      );
      if (res.statusCode == 201 || res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final b = Brand.fromJson(data);
        brands.add(b);
        brands.sort((a, b) => a.name.compareTo(b.name));
        return b;
      }
    } catch (e) {
      print('Error adding brand: $e');
    }
    return null;
  }

  Future<Brand?> updateBrand(String id, {required String name, required double sellingRate, required double costPerUnit}) async {
    try {
      final url = '${dotenv.env['API_URL']}/brands/$id';
      final res = await http.put(
        Uri.parse(url),
        headers: auth.authHeaders,
        body: jsonEncode({
          'name': name,
          'sellingRate': sellingRate,
          'costPerUnit': costPerUnit,
        }),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final updatedBrand = Brand.fromJson(data);
        final index = brands.indexWhere((b) => b.id == id);
        if (index != -1) {
          brands[index] = updatedBrand;
        }
        return updatedBrand;
      }
    } catch (e) {
      print('Error updating brand: $e');
    }
    return null;
  }

  Future<bool> deleteBrand(String id) async {
    try {
      final url = '${dotenv.env['API_URL']}/brands/$id';
      final res = await http.delete(Uri.parse(url), headers: auth.authHeaders);
      if (res.statusCode == 200) {
        brands.removeWhere((b) => b.id == id);
        return true;
      }
    } catch (e) {
      print('Error deleting brand: $e');
    }
    return false;
  }

  // ========== COMPLETED PRODUCTION (COMPANY REVENUE) ==========
  
  double calculateCostPerUnit() {
    double totalCost = 0;
    for (var rate in ratePerCategory.values) {
      totalCost += rate;
    }
    return totalCost;
  }

  Future<void> fetchCompletedProduction() async {
    try {
      final url = '${dotenv.env['API_URL']}/completed-production';
      final response = await http.get(Uri.parse(url), headers: auth.authHeaders);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        completedProducts
          ..clear()
          ..addAll(data.map((e) => CompletedProduct.fromJson(e as Map<String, dynamic>)));
      }
    } catch (e) {
      print('Error fetching completed production: $e');
    }
  }

  Future<CompletedProduct?> addCompletedProduction({
    required DateTime date,
    required int quantity,
    required double sellingRate,
    required double costPerUnit,
    String brandName = '',
    String notes = '',
  }) async {
    try {
      final url = '${dotenv.env['API_URL']}/completed-production';
      final res = await http.post(
        Uri.parse(url),
        headers: auth.authHeaders,
        body: jsonEncode({
          'date': date.toIso8601String(),
          'quantity': quantity,
          'sellingRate': sellingRate,
          'costPerUnit': costPerUnit,
          'brandName': brandName,
          'notes': notes,
        }),
      );
      if (res.statusCode == 201 || res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final cp = CompletedProduct.fromJson(data);
        completedProducts.insert(0, cp);
        return cp;
      }
    } catch (e) {
      print('Error adding completed production: $e');
    }
    return null;
  }

  Future<bool> deleteCompletedProduction(String id) async {
    try {
      final url = '${dotenv.env['API_URL']}/completed-production/$id';
      final res = await http.delete(Uri.parse(url), headers: auth.authHeaders);
      if (res.statusCode == 200) {
        completedProducts.removeWhere((cp) => cp.id == id);
        return true;
      }
    } catch (e) {
      print('Error deleting completed production: $e');
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

  // Update an existing worker (e.g. set daily wage)
  Future<Worker?> updateWorker(String workerId, Map<String, dynamic> updates) async {
    try {
      final url = '${dotenv.env['API_URL']}/workers/$workerId';
      final response = await http.put(
        Uri.parse(url),
        headers: auth.authHeaders,
        body: jsonEncode(updates),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final updatedWorker = Worker.fromJson(data);
        final idx = workers.indexWhere((w) => w.id == workerId);
        if (idx != -1) workers[idx] = updatedWorker;
        return updatedWorker;
      }
    } catch (e) {
      print('Error updating worker: $e');
    }
    return null;
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

  // Get active workers who are paid daily wages
  List<Worker> getDailyWageWorkers() {
    return workers.where((w) => w.isActive && (w.dailyWage) > 0).toList();
  }

  // Fetch ALL attendance records (no date filter) for pending payment calc
  final List<AttendanceRecord> allAttendanceRecords = [];

  Future<void> fetchAllAttendance() async {
    try {
      final url = '${dotenv.env['API_URL']}/attendance';
      final response = await http.get(Uri.parse(url), headers: auth.authHeaders);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        allAttendanceRecords
          ..clear()
          ..addAll(data.map((e) => AttendanceRecord.fromJson(e as Map<String, dynamic>)));
      }
    } catch (e) {
      print('Error fetching all attendance: $e');
    }
  }

  // Calculate pending daily-wage amounts per worker based on attendance history
  // Returns: { workerId -> { worker, pendingAmount, presentDays, halfDays, periodStart, periodEnd } }
  Map<String, Map<String, dynamic>> calculateDailyWagePending() {
    final result = <String, Map<String, dynamic>>{};

    for (final worker in getDailyWageWorkers()) {
      final workerRecords = allAttendanceRecords
          .where((r) => r.workerId == worker.id)
          .toList();

      if (workerRecords.isEmpty) continue;

      // Calculate total earned from attendance
      double totalEarned = 0;
      int presentDays = 0;
      int halfDays = 0;
      for (final r in workerRecords) {
        switch (r.status) {
          case 'present':
            totalEarned += worker.dailyWage;
            presentDays++;
            break;
          case 'half-day':
            totalEarned += worker.dailyWage * 0.5;
            halfDays++;
            break;
          case 'absent':
            break; // no pay
        }
      }

      // Calculate already paid
      final paidPayments = payments
          .where((p) => p.workerId == worker.id && p.status.toString().contains('paid'))
          .toList();
      final totalPaid = paidPayments.fold<double>(0, (s, p) => s + p.amount);

      final pendingAmount = totalEarned - totalPaid;
      if (pendingAmount <= 0) continue;

      // Determine period
      final dates = workerRecords.map((r) => r.date).toList();
      DateTime? periodStart;
      DateTime? periodEnd;
      if (dates.isNotEmpty) {
        periodStart = dates.reduce((a, b) => a.isBefore(b) ? a : b);
        periodEnd = dates.reduce((a, b) => a.isAfter(b) ? a : b);
      }

      result[worker.id] = {
        'worker': worker,
        'pendingAmount': pendingAmount,
        'totalEarned': totalEarned,
        'totalPaid': totalPaid,
        'presentDays': presentDays,
        'halfDays': halfDays,
        'periodStart': periodStart ?? DateTime.now(),
        'periodEnd': periodEnd ?? DateTime.now(),
        'payType': 'daily_wage',
      };
    }

    return result;
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

  // ========== INVENTORY ==========

  Future<void> fetchInventory() async {
    try {
      final url = '${dotenv.env['API_URL']}/inventory';
      final response = await http.get(Uri.parse(url), headers: auth.authHeaders);
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        inventory
          ..clear()
          ..addAll(list.map((e) => InventoryItem.fromJson(e as Map<String, dynamic>)));
      }
    } catch (e) {
      print('Error fetching inventory: $e');
    }
  }

  Future<InventoryItem?> addInventoryItem({
    required String name,
    required int quantity,
    required double unitCost,
    double cgstPercent = 0,
    double sgstPercent = 0,
    String supplier = '',
  }) async {
    try {
      final url = '${dotenv.env['API_URL']}/inventory';
      final body = {
        'name': name,
        'quantity': quantity,
        'unitCost': unitCost,
        'cgstPercent': cgstPercent,
        'sgstPercent': sgstPercent,
        'supplier': supplier,
      };
      final response = await http.post(
        Uri.parse(url),
        headers: auth.authHeaders,
        body: jsonEncode(body),
      );
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final item = InventoryItem.fromJson(data);
        inventory.insert(0, item);
        return item;
      }
    } catch (e) {
      print('Error adding inventory item: $e');
    }
    return null;
  }

  Future<bool> updateInventoryItem(String id, {
    String? name,
    int? quantity,
    double? unitCost,
    double? cgstPercent,
    double? sgstPercent,
    String? supplier,
  }) async {
    try {
      final url = '${dotenv.env['API_URL']}/inventory/$id';
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (quantity != null) body['quantity'] = quantity;
      if (unitCost != null) body['unitCost'] = unitCost;
      if (cgstPercent != null) body['cgstPercent'] = cgstPercent;
      if (sgstPercent != null) body['sgstPercent'] = sgstPercent;
      if (supplier != null) body['supplier'] = supplier;
      final response = await http.put(
        Uri.parse(url),
        headers: auth.authHeaders,
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final updated = InventoryItem.fromJson(data);
        final index = inventory.indexWhere((i) => i.id == id);
        if (index != -1) inventory[index] = updated;
        return true;
      }
    } catch (e) {
      print('Error updating inventory item: $e');
    }
    return false;
  }

  Future<bool> deleteInventoryItem(String id) async {
    try {
      final url = '${dotenv.env['API_URL']}/inventory/$id';
      final response = await http.delete(Uri.parse(url), headers: auth.authHeaders);
      if (response.statusCode == 200) {
        inventory.removeWhere((i) => i.id == id);
        return true;
      }
    } catch (e) {
      print('Error deleting inventory item: $e');
    }
    return false;
  }

  // ========== GST SETTINGS ==========

  Future<GstSetting?> fetchGstSettings() async {
    try {
      final url = '${dotenv.env['API_URL']}/gst-settings';
      final response = await http.get(Uri.parse(url), headers: auth.authHeaders);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        gstSetting = GstSetting.fromJson(data);
        return gstSetting;
      }
    } catch (e) {
      print('Error fetching GST settings: $e');
    }
    return null;
  }

  Future<GstSetting?> updateGstSettings({
    double? cgstPercent,
    double? sgstPercent,
    String? companyName,
    String? companyAddress,
    String? companyPhone,
    String? gstin,
    int? lastInvoiceNumber,
    String? invoicePrefix,
  }) async {
    try {
      final url = '${dotenv.env['API_URL']}/gst-settings';
      final body = <String, dynamic>{};
      if (cgstPercent != null) body['cgstPercent'] = cgstPercent;
      if (sgstPercent != null) body['sgstPercent'] = sgstPercent;
      if (companyName != null) body['companyName'] = companyName;
      if (companyAddress != null) body['companyAddress'] = companyAddress;
      if (companyPhone != null) body['companyPhone'] = companyPhone;
      if (gstin != null) body['gstin'] = gstin;
      if (lastInvoiceNumber != null) body['lastInvoiceNumber'] = lastInvoiceNumber;
      if (invoicePrefix != null) body['invoicePrefix'] = invoicePrefix;
      final response = await http.put(
        Uri.parse(url),
        headers: auth.authHeaders,
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        gstSetting = GstSetting.fromJson(data);
        return gstSetting;
      }
    } catch (e) {
      print('Error updating GST settings: $e');
    }
    return null;
  }

  // ========== BILLING ==========

  Future<List<BrandBill>> fetchBilling({String? brandId, DateTime? startDate, DateTime? endDate}) async {
    try {
      var url = '${dotenv.env['API_URL']}/billing/generate';
      final params = <String>[];
      if (brandId != null) params.add('brandId=$brandId');
      if (startDate != null) params.add('startDate=${startDate.toIso8601String()}');
      if (endDate != null) params.add('endDate=${endDate.toIso8601String()}');
      if (params.isNotEmpty) url += '?${params.join('&')}';

      final response = await http.get(Uri.parse(url), headers: auth.authHeaders);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final billsJson = data['brandBills'] as List<dynamic>? ?? [];
        brandBills = billsJson.map((b) => BrandBill.fromJson(b as Map<String, dynamic>)).toList();

        // Also update GST settings from response
        if (data['gstSettings'] != null) {
          gstSetting = GstSetting.fromJson(data['gstSettings'] as Map<String, dynamic>);
        }
        return brandBills;
      }
    } catch (e) {
      print('Error fetching billing data: $e');
    }
    return [];
  }

  // ========== GST SUMMARY (Net Payable) ==========

  Future<GstSummary?> fetchGstSummary({DateTime? startDate, DateTime? endDate}) async {
    try {
      var url = '${dotenv.env['API_URL']}/gst-summary';
      final params = <String>[];
      if (startDate != null) params.add('startDate=${startDate.toIso8601String()}');
      if (endDate != null) params.add('endDate=${endDate.toIso8601String()}');
      if (params.isNotEmpty) url += '?${params.join('&')}';

      final response = await http.get(Uri.parse(url), headers: auth.authHeaders);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        gstSummary = GstSummary.fromJson(data);
        return gstSummary;
      }
    } catch (e) {
      print('Error fetching GST summary: $e');
    }
    return null;
  }

  // ========== EXCEL EXPORT ==========

  /// Downloads an Excel export file and returns the bytes.
  /// [type] can be: 'gst-billing', 'revenue', 'production', 'inventory', 'payments'
  Future<List<int>?> downloadExport(String type, {DateTime? startDate, DateTime? endDate}) async {
    try {
      var url = '${dotenv.env['API_URL']}/exports/$type';
      final params = <String>[];
      if (startDate != null) params.add('startDate=${startDate.toIso8601String()}');
      if (endDate != null) params.add('endDate=${endDate.toIso8601String()}');
      if (params.isNotEmpty) url += '?${params.join('&')}';

      final response = await http.get(Uri.parse(url), headers: auth.authHeaders);
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (e) {
      print('Error downloading export: $e');
    }
    return null;
  }
}


