import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/inventory.dart';
import '../models/payment.dart';
import '../models/product.dart';
import '../models/stitch.dart';
import '../models/staff.dart';
import '../models/worker.dart';

class DataService {
  final List<ProductCategory> categories = [];

  final Map<String, double> ratePerCategory = {};

  // Fetch rates from backend and build categories list
  Future<void> fetchRates() async {
    try {
      final url = '${dotenv.env['API_URL']}/rates';
      print('Fetching rates from: $url');
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        ratePerCategory.clear();
        categories.clear();
        
        for (var item in data) {
          final categoryId = item['category'] as String;
          final amount = (item['amount'] as num).toDouble();
          
          ratePerCategory[categoryId] = amount;
          
          // Build category from ID (capitalize first letter)
          final categoryName = categoryId.split('_')
              .map((word) => word[0].toUpperCase() + word.substring(1))
              .join(' ');
          
          categories.add(ProductCategory(
            id: categoryId,
            name: categoryName,
          ));
        }
        
        print('✅ Fetched ${categories.length} categories with rates: $ratePerCategory');
      } else {
        print('❌ Failed to fetch rates: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('❌ Error fetching rates: $e');
      print('Stack trace: $stackTrace');
    }
  }

  // Update rate in backend
  Future<bool> updateRate(String category, double amount) async {
    try {
      final url = '${dotenv.env['API_URL']}/rates';
      print('Updating rate: $url');
      print('Category: $category, Amount: $amount');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'category': category,
          'amount': amount,
        }),
      );
      
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Update local rate
        ratePerCategory[category] = amount;
        
        // Add category if it doesn't exist
        final categoryExists = categories.any((c) => c.id == category);
        if (!categoryExists) {
          final categoryName = category.split('_')
              .map((word) => word[0].toUpperCase() + word.substring(1))
              .join(' ');
          categories.add(ProductCategory(
            id: category,
            name: categoryName,
          ));
          print('✅ Added new category: $categoryName');
        }
        
        print('✅ Updated rate for $category: $amount');
        return true;
      } else {
        print('❌ Failed to update rate: ${response.statusCode} - ${response.body}');
      }
    } catch (e, stackTrace) {
      print('❌ Error updating rate: $e');
      print('Stack trace: $stackTrace');
    }
    return false;
  }

  final List<Product> products = [];
  final List<StitchEntry> stitchEntries = [];
  final List<StaffPayment> payments = [];
  final List<InventoryItem> inventory = [];
  final List<Staff> staffMembers = [];
  final List<Worker> workers = [];

  // Fetch all staff members from backend
  Future<void> fetchStaff() async {
    try {
      final url = '${dotenv.env['API_URL']}/staff';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        staffMembers.clear();
        for (var item in data) {
          staffMembers.add(Staff(
            id: item['_id'],
            name: item['name'],
            phoneNumber: item['phoneNumber'],
            email: item['email'],
            joinedDate: DateTime.parse(item['joinedDate']),
            isActive: item['isActive'] ?? true,
          ));
        }
      }
    } catch (e) {
      print('Error fetching staff: $e');
    }
  }

  // Add a new staff member to backend
  Future<Staff?> addStaff(Staff staff, String userId, String email) async {
    try {
      final url = '${dotenv.env['API_URL']}/staff';
      print('Creating staff at: $url');
      print('UserId: $userId, Name: ${staff.name}, Email: $email');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'name': staff.name,
          'phoneNumber': staff.phoneNumber,
          'email': email,
        }),
      );
      
      print('Staff creation response: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final newStaff = Staff(
          id: data['_id'],
          name: data['name'],
          phoneNumber: data['phoneNumber'],
          email: data['email'],
          joinedDate: DateTime.parse(data['joinedDate']),
          isActive: data['isActive'] ?? true,
        );
        staffMembers.add(newStaff);
        return newStaff;
      } else {
        print('Failed to create staff: ${response.statusCode} - ${response.body}');
      }
    } catch (e, stackTrace) {
      print('Error adding staff: $e');
      print('Stack trace: $stackTrace');
    }
    return null;
  }

  // Remove a staff member
  void removeStaff(String staffId) {
    staffMembers.removeWhere((s) => s.id == staffId);
  }

  // Get staff by ID
  Staff? getStaffById(String staffId) {
    try {
      return staffMembers.firstWhere((s) => s.id == staffId);
    } catch (e) {
      return null;
    }
  }

  // Get active staff members
  List<Staff> getActiveStaff() {
    return staffMembers.where((s) => s.isActive).toList();
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
      final response = await http.get(Uri.parse(url));
      
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
  Future<Worker?> addWorker(Worker worker) async {
    try {
      final url = '${dotenv.env['API_URL']}/workers';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': worker.name,
          'phoneNumber': worker.phoneNumber,
          'address': worker.address,
          'notes': worker.notes,
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
      final response = await http.delete(Uri.parse(url));
      
      if (response.statusCode == 200) {
        workers.removeWhere((w) => w.id == workerId);
        return true;
      }
    } catch (e) {
      print('Error removing worker: $e');
    }
    return false;
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
              : workerIdValue['_id'] as String;
          
          stitchEntries.add(StitchEntry(
            id: item['_id'],
            workerId: workerId,
            categoryId: item['categoryId'],
            quantity: item['quantity'],
            date: DateTime.parse(item['date']),
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
        
        final savedEntry = StitchEntry(
          id: data['_id'],
          workerId: workerId,
          categoryId: data['categoryId'],
          quantity: data['quantity'],
          date: DateTime.parse(data['date']),
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
}


