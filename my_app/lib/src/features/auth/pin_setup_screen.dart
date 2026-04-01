import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services/auth_service.dart';

class PinSetupScreen extends StatefulWidget {
  final AuthService authService;
  final VoidCallback onPinSet;

  const PinSetupScreen({
    super.key,
    required this.authService,
    required this.onPinSet,
  });

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final List<TextEditingController> _pinControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  
  int _pinLength = 4; // 4 or 6 digit PIN
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  bool _isLoading = false;
  String? _error;
  bool _enableBiometric = false;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    final available = await widget.authService.isBiometricAvailable();
    if (mounted) {
      setState(() => _biometricAvailable = available);
    }
  }

  @override
  void dispose() {
    for (var controller in _pinControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _onDigitEntered(int index, String value) {
    // Trigger rebuild to update button state
    setState(() {});
    
    if (value.length == 1) {
      // Move to next field
      if (index < _pinLength - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        // All digits entered - just unfocus, don't auto-submit
        _focusNodes[index].unfocus();
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
    _focusNodes[0].requestFocus();
  }

  void _onPinComplete() {
    final enteredPin = _getCurrentPin();
    
    if (enteredPin.length != _pinLength) {
      setState(() {
        _error = 'Please enter all $_pinLength digits';
      });
      return;
    }
    
    if (!_isConfirming) {
      // First entry - move to confirmation
      setState(() {
        _pin = enteredPin;
        _isConfirming = true;
        _error = null;
      });
      _clearPin();
    } else {
      // Confirmation
      if (enteredPin == _pin) {
        _setupPin();
      } else {
        setState(() {
          _error = 'PINs do not match. Please try again.';
          _isConfirming = false;
          _pin = '';
        });
        _clearPin();
      }
    }
  }

  Future<void> _setupPin() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await widget.authService.setupPin(_pin);
      
      // Enable biometric if selected
      if (_enableBiometric && _biometricAvailable) {
        try {
          await widget.authService.enableBiometric();
        } catch (e) {
          // Ignore biometric errors, PIN is already set
        }
      }
      
      widget.onPinSet();
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isConfirming = false;
        _pin = '';
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
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              // Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.indigo.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  size: 40,
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(height: 24),
              
              // Title
              Text(
                _isConfirming ? 'Confirm Your PIN' : 'Set Up Your PIN',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isConfirming 
                    ? 'Enter your PIN again to confirm'
                    : 'Create a PIN to secure your account',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              // PIN Length Selection (only show on first entry)
              if (!_isConfirming) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildPinLengthButton(4),
                    const SizedBox(width: 16),
                    _buildPinLengthButton(6),
                  ],
                ),
                const SizedBox(height: 24),
              ],
              
              // PIN Input
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pinLength, (index) => _buildPinField(index)),
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
              
              // Biometric Option (only show after PIN length is selected)
              if (!_isConfirming && _biometricAvailable) ...[
                const SizedBox(height: 24),
                CheckboxListTile(
                  value: _enableBiometric,
                  onChanged: (value) => setState(() => _enableBiometric = value ?? false),
                  title: const Text('Enable fingerprint unlock'),
                  subtitle: const Text('Use your fingerprint to unlock the app'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ],
              
              const SizedBox(height: 32),
              
              // Confirm Button
              if (_isLoading)
                const CircularProgressIndicator()
              else
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _getCurrentPin().length == _pinLength ? _onPinComplete : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[300],
                      disabledForegroundColor: Colors.grey[500],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      _isConfirming ? 'Confirm PIN' : 'Continue',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              
              const Spacer(),
              
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinLengthButton(int length) {
    final isSelected = _pinLength == length;
    return GestureDetector(
      onTap: () {
        setState(() {
          _pinLength = length;
          _clearPin();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.indigo : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.indigo : Colors.grey[300]!,
          ),
        ),
        child: Text(
          '$length digits',
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: FontWeight.w600,
          ),
        ),
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
