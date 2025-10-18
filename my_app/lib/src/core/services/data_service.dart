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
  final List<ProductCategory> categories = [
    const ProductCategory(id: 'shirt', name: 'Shirt'),
    const ProductCategory(id: 'pant', name: 'Pant'),
  ];

  final Map<String, double> ratePerCategory = {
    'shirt': 50.0,
    'pant': 60.0,
  };

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
}


