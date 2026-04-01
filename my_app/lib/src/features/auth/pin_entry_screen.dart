import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services/auth_service.dart';

class PinEntryScreen extends StatefulWidget {
  final AuthService authService;
  final VoidCallback onUnlocked;
  final VoidCallback onSignOut;

  const PinEntryScreen({
    super.key,
    required this.authService,
    required this.onUnlocked,
    required this.onSignOut,
  });

  @override
  State<PinEntryScreen> createState() => _PinEntryScreenState();
}

class _PinEntryScreenState extends State<PinEntryScreen> with SingleTickerProviderStateMixin {
  final List<TextEditingController> _pinControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  
  int _pinLength = 4; // Will be determined by stored PIN length
  bool _isLoading = false;
  String? _error;
  int _attempts = 0;
  static const int _maxAttempts = 5;
  
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 10)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);
    
    _tryBiometric();
    _detectPinLength();
  }

  Future<void> _detectPinLength() async {
    // Try to get PIN length from stored PIN
    final storedPin = await widget.authService.storage.getLocalPin();
    if (storedPin != null && mounted) {
      setState(() {
        _pinLength = storedPin.length;
      });
    }
  }

  Future<void> _tryBiometric() async {
    if (!widget.authService.biometricEnabled) return;
    
    // Small delay to let the screen render
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (!mounted) return;
    
    final success = await widget.authService.authenticateWithBiometric();
    if (success && mounted) {
      widget.onUnlocked();
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    for (var controller in _pinControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _triggerShake() {
    _shakeController.forward(from: 0);
  }

  void _onDigitEntered(int index, String value) {
    if (value.length == 1) {
      if (index < _pinLength - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        _verifyPin();
      }
    }
  }

  void _onKeyPressed(int index, RawKeyEvent event) {
    if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace) {
      if (_pinControllers[index].text.isEmpty && index > 0) {
        _focusNodes[index - 1].requestFocus();
        _pinControllers[index - 1].clear();
      }
    }
  }

  String _getCurrentPin() {
    return _pinControllers
        .take(_pinLength)
        .map((c) => c.text)
        .join();
  }

  void _clearPin() {
    for (var controller in _pinControllers) {
      controller.clear();
    }
    if (_focusNodes.isNotEmpty) {
      _focusNodes[0].requestFocus();
    }
  }

  Future<void> _verifyPin() async {
    final pin = _getCurrentPin();
    if (pin.length != _pinLength) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final success = await widget.authService.verifyPin(pin);
      
      if (success) {
        widget.onUnlocked();
      } else {
        _attempts++;
        _triggerShake();
        
        if (_attempts >= _maxAttempts) {
          setState(() {
            _error = 'Too many incorrect attempts. Please sign in again.';
          });
          await Future.delayed(const Duration(seconds: 2));
          widget.onSignOut();
        } else {
          setState(() {
            _error = 'Incorrect PIN. ${_maxAttempts - _attempts} attempts remaining.';
          });
          _clearPin();
        }
      }
    } catch (e) {
      _triggerShake();
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
      _clearPin();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.authService.currentUser;
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              
              // User Avatar
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.indigo.withOpacity(0.1),
                child: Text(
                  (user?.name ?? 'A').substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Welcome back
              Text(
                'Welcome back,',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user?.name ?? 'Admin',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 32),
              
              // Title
              const Text(
                'Enter your PIN',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 24),
              
              // PIN Input with shake animation
              AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(_shakeAnimation.value * ((_shakeController.status == AnimationStatus.forward) ? 1 : -1), 0),
                    child: child,
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pinLength, (index) => _buildPinField(index)),
                ),
              ),
              
              // Error Message
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade600, size: 20),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _error!,
                          style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 32),
              
              // Biometric button
              if (widget.authService.biometricEnabled) ...[
                TextButton.icon(
                  onPressed: _isLoading ? null : _tryBiometric,
                  icon: const Icon(Icons.fingerprint, size: 28),
                  label: const Text('Use Fingerprint'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.indigo,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              const Spacer(),
              
              // Loading indicator
              if (_isLoading)
                const CircularProgressIndicator()
              else
                // Sign out option
                TextButton(
                  onPressed: () => _showSignOutDialog(),
                  child: Text(
                    'Sign in with different account',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out?'),
        content: const Text(
          'This will sign you out completely. You will need to enter your email and password to sign in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onSignOut();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  Widget _buildPinField(int index) {
    return Container(
      width: 48,
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      child: RawKeyboardListener(
        focusNode: FocusNode(),
        onKey: (event) => _onKeyPressed(index, event),
        child: TextField(
          controller: _pinControllers[index],
          focusNode: _focusNodes[index],
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 1,
          obscureText: true,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.indigo, width: 2),
            ),
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (value) => _onDigitEntered(index, value),
        ),
      ),
    );
  }
}
