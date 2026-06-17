import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StaffPinScreen extends StatefulWidget {
  final String phoneNumber;
  
  const StaffPinScreen({super.key, required this.phoneNumber});

  @override
  State<StaffPinScreen> createState() => _StaffPinScreenState();
}

class _StaffPinScreenState extends State<StaffPinScreen> {
  String _pin = '';
  bool _isLoading = false;
  final int _pinLength = 6;

  void _onNumberTap(String number) {
    if (_pin.length < _pinLength) {
      setState(() {
        _pin += number;
      });
      
      // Auto-submit when PIN is complete
      if (_pin.length == _pinLength) {
        _verifyPin();
      }
    }
  }

  void _onBackspace() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  void _verifyPin() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authService = AuthService();
      final staffInfo = await authService.signInStaffWithPin(widget.phoneNumber, _pin);
      
      if (staffInfo != null && staffInfo['user'] != null) {
        // Persist session details for other screens relying on SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final String staffId = (staffInfo['staffId'] ?? '').toString();
        final Map<String, dynamic> staffData = Map<String, dynamic>.from(staffInfo['staffData'] ?? {});
        final String name = (staffData['name'] ?? '').toString();
        final String role = (staffInfo['role'] ?? 'staff').toString();
        final String phone = (staffData['phone'] ?? widget.phoneNumber).toString();

        if (staffId.isNotEmpty) {
          await prefs.setString('currentStaffId', staffId);
        }
        await prefs.setString('currentStaffName', name);
        await prefs.setString('currentStaffRole', role);
        await prefs.setString('currentStaffPhone', phone);
        
        // Navigate to main app dashboard
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/dashboard',
          (route) => false,
        );
      } else {
        // Show error and reset PIN
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authentication failed. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _pin = '';
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _pin = '';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _forgotPin() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forgot PIN?'),
        content: const Text('Please contact your administrator to reset your PIN.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 60),
              const Text(
                'Enter PIN',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter your 6-digit PIN to login.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 60),
              // PIN dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pinLength,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index < _pin.length ? Colors.blue : Colors.grey[300],
                      border: Border.all(
                        color: index < _pin.length ? Colors.blue : Colors.grey[400]!,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              if (_isLoading)
                const CircularProgressIndicator()
              else
                Column(
                  children: [
                    TextButton(
                      onPressed: _forgotPin,
                      child: const Text(
                        'Forgot PIN?',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Number pad
                    Container(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildNumberButton('1'),
                              _buildNumberButton('2'),
                              _buildNumberButton('3'),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildNumberButton('4'),
                              _buildNumberButton('5'),
                              _buildNumberButton('6'),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildNumberButton('7'),
                              _buildNumberButton('8'),
                              _buildNumberButton('9'),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              const SizedBox(width: 70, height: 70), // Empty space
                              _buildNumberButton('0'),
                              _buildBackspaceButton(),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumberButton(String number) {
    return GestureDetector(
      onTap: _isLoading ? null : () => _onNumberTap(number),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(35),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Center(
          child: Text(
            number,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w500,
              color: _isLoading ? Colors.grey : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _onBackspace,
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(35),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            Icons.backspace_outlined,
            size: 24,
            color: _isLoading ? Colors.grey : Colors.black87,
          ),
        ),
      ),
    );
  }
}