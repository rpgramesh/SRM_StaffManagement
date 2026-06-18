import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/auth_service.dart';
import '../../const/colors.dart';
import '../../utils/australian_phone_number.dart';
import '../../utils/australian_phone_text_input_formatter.dart';
import '../staff_management_app_screen.dart';

class AdminSetupScreen extends StatefulWidget {
  const AdminSetupScreen({super.key});

  @override
  State<AdminSetupScreen> createState() => _AdminSetupScreenState();
}

class _AdminSetupScreenState extends State<AdminSetupScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();

  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  String? _validateAustralianPhone(String? value) {
    final digits = AustralianPhoneNumber.digitsOnly(value ?? '');
    if (digits.isEmpty) {
      return 'Please enter phone number';
    }

    final prefixError = AustralianPhoneNumber.validationErrorForDigits(
      digits,
      internationalMode: false,
    );
    if (prefixError != null) {
      return prefixError;
    }

    if (!AustralianPhoneNumber.isValidLocalDigits(digits)) {
      return AustralianPhoneNumber.submitErrorMessage(internationalMode: false);
    }

    return null;
  }

  Future<void> _createAdminAccount() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter admin name';
      });
      return;
    }

    if (_phoneController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter phone number';
      });
      return;
    }

    final phoneValidation = _validateAustralianPhone(_phoneController.text);
    if (phoneValidation != null) {
      setState(() {
        _errorMessage = phoneValidation;
      });
      return;
    }

    if (_pinController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter PIN';
      });
      return;
    }

    if (_pinController.text != _confirmPinController.text) {
      setState(() {
        _errorMessage = 'PINs do not match';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final normalizedPhone =
          AustralianPhoneNumber.normalizeToStorageFormat(_phoneController.text);
      if (normalizedPhone == null) {
        setState(() {
          _errorMessage = AustralianPhoneNumber.submitErrorMessage(
              internationalMode: false);
        });
        return;
      }

      final success = await _authService.createInitialAdmin(
        phoneNumber: normalizedPhone,
        pin: _pinController.text.trim(),
        name: _nameController.text.trim(),
      );

      if (success) {
        // Navigate to dashboard
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const StaffManagementAppScreen(),
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to create admin account. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),

              // Header
              const Text(
                'Setup Admin Account',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Create the first admin account to get started.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 40),

              // Form
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Name field
                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Admin Name',
                          hintText: 'Enter admin name',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.person),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Phone field
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.digitsOnly,
                          AustralianLocalPhoneInputFormatter(),
                        ],
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          hintText: '(04) 1234 5678',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.phone),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // PIN field
                      TextField(
                        controller: _pinController,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        maxLength: 6,
                        decoration: InputDecoration(
                          labelText: '6-Digit PIN',
                          hintText: 'Enter 6-digit PIN',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.lock),
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Confirm PIN field
                      TextField(
                        controller: _confirmPinController,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        maxLength: 6,
                        decoration: InputDecoration(
                          labelText: 'Confirm PIN',
                          hintText: 'Re-enter 6-digit PIN',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.lock_outline),
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Error message
                      if (_errorMessage.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline,
                                  color: Colors.red.shade600),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage,
                                  style: TextStyle(color: Colors.red.shade600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 24),

                      // Create button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _createAdminAccount,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColor.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Create Admin Account',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
