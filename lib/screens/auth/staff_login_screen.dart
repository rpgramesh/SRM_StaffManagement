import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../utils/australian_phone_number.dart';
import '../../widgets/phone_number_keypad.dart';
import 'staff_pin_screen.dart';

class StaffLoginScreen extends StatefulWidget {
  const StaffLoginScreen({super.key});

  @override
  State<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends State<StaffLoginScreen> {
  String _phoneDigits = '';
  bool _isLoading = false;
  bool _useInternationalDialing = false;
  bool _showValidationFeedback = false;

  int get _requiredDigits => _useInternationalDialing
      ? AustralianPhoneNumber.internationalLength
      : AustralianPhoneNumber.localLength;

  String? get _inlineValidationError {
    final error = AustralianPhoneNumber.validationErrorForDigits(
      _phoneDigits,
      internationalMode: _useInternationalDialing,
    );
    if (error != null) {
      return error;
    }
    if (_showValidationFeedback &&
        !_hasValidPhoneNumber &&
        _phoneDigits.isNotEmpty) {
      return AustralianPhoneNumber.submitErrorMessage(
        internationalMode: _useInternationalDialing,
      );
    }
    return null;
  }

  bool get _hasValidPhoneNumber {
    if (_useInternationalDialing) {
      return AustralianPhoneNumber.isValidInternationalDigits(_phoneDigits);
    }
    return AustralianPhoneNumber.isValidLocalDigits(_phoneDigits);
  }

  String get _formattedPhoneDisplay {
    if (_useInternationalDialing) {
      return AustralianPhoneNumber.formatInternationalDigits(_phoneDigits);
    }
    return AustralianPhoneNumber.formatLocalDigits(_phoneDigits);
  }

  String get _storagePhoneNumber {
    return _useInternationalDialing
        ? '+61$_phoneDigits'
        : '+61${_phoneDigits.substring(1)}';
  }

  void _setDialingMode(bool internationalMode) {
    setState(() {
      _useInternationalDialing = internationalMode;
      _phoneDigits = '';
      _showValidationFeedback = false;
    });
  }

  void _onNext() async {
    setState(() {
      _showValidationFeedback = true;
    });

    if (!_hasValidPhoneNumber) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AustralianPhoneNumber.submitErrorMessage(
              internationalMode: _useInternationalDialing,
            ),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = AuthService();
      final staffData = await authService.getStaffByPhone(_storagePhoneNumber);

      if (!mounted) {
        return;
      }

      if (staffData != null) {
        if (staffData['pin'] != null &&
            staffData['pin'].toString().isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  StaffPinScreen(phoneNumber: _storagePhoneNumber),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Your account needs PIN setup. Please contact administrator to set up your PIN.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Staff account not found. Please contact administrator.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
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
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Staff Login'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 40),
                    const Text(
                      'Welcome Back!',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter your phone number to continue.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        ChoiceChip(
                          key: const ValueKey('phone-mode-local'),
                          label: const Text('Local (0X)'),
                          selected: !_useInternationalDialing,
                          onSelected:
                              _isLoading ? null : (_) => _setDialingMode(false),
                        ),
                        ChoiceChip(
                          key: const ValueKey('phone-mode-international'),
                          label: const Text('International +61'),
                          selected: _useInternationalDialing,
                          onSelected:
                              _isLoading ? null : (_) => _setDialingMode(true),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: PhoneNumberKeypad(
                          digits: _phoneDigits,
                          displayText: _formattedPhoneDisplay,
                          digitCountText:
                              '${_phoneDigits.length}/$_requiredDigits digits',
                          statusColor: _hasValidPhoneNumber
                              ? Colors.green.shade700
                              : Colors.grey.shade600,
                          errorText: _inlineValidationError,
                          countryCode: '+61',
                          maxDigits: _requiredDigits,
                          enabled: !_isLoading,
                          onChanged: (digits) {
                            setState(() {
                              _phoneDigits = digits;
                              _showValidationFeedback = false;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: !_isLoading ? _onNext : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Next',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
