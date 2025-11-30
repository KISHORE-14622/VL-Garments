import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'auth_service.dart';

class RazorpayService {
  final AuthService authService;
  late Razorpay _razorpay;
  
  Function(String, String, String)? onSuccess;
  Function(String)? onError;

  RazorpayService({required this.authService}) {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void dispose() {
    _razorpay.clear();
  }

  Future<Map<String, dynamic>?> createOrder({
    required double amount,
    String currency = 'INR',
  }) async {
    try {
      final url = '${dotenv.env['API_URL']}/payments/razorpay/create-order';
      final response = await http.post(
        Uri.parse(url),
        headers: authService.authHeaders,
        body: jsonEncode({
          'amount': amount,
          'currency': currency,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        print('Failed to create order: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error creating Razorpay order: $e');
      return null;
    }
  }

  Future<bool> verifyPayment({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    try {
      final url = '${dotenv.env['API_URL']}/payments/razorpay/verify';
      final response = await http.post(
        Uri.parse(url),
        headers: authService.authHeaders,
        body: jsonEncode({
          'razorpay_order_id': orderId,
          'razorpay_payment_id': paymentId,
          'razorpay_signature': signature,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['verified'] == true;
      }
      return false;
    } catch (e) {
      print('Error verifying payment: $e');
      return false;
    }
  }

  void openCheckout({
    required String orderId,
    required double amount,
    required String name,
    required String description,
    String? email,
    String? contact,
  }) {
    var options = {
      'key': dotenv.env['RAZORPAY_KEY_ID'] ?? '',
      'amount': (amount * 100).toInt(), // Amount in paise
      'currency': 'INR',
      'name': 'VL Garments',
      'description': description,
      'order_id': orderId,
      'prefill': {
        'name': name,
        if (email != null) 'email': email,
        if (contact != null) 'contact': contact,
      },
      'theme': {
        'color': '#2196F3',
      }
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      print('Error opening Razorpay checkout: $e');
      if (onError != null) {
        onError!('Failed to open payment gateway');
      }
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    if (onSuccess != null) {
      onSuccess!(
        response.orderId ?? '',
        response.paymentId ?? '',
        response.signature ?? '',
      );
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (onError != null) {
      onError!(response.message ?? 'Payment failed');
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    print('External wallet selected: ${response.walletName}');
  }
}
