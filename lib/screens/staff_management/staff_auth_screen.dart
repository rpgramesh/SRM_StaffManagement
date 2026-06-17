import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:local_auth/local_auth.dart';
import '../../models/staff.dart';
import '../../services/auth_service.dart';
import '../../data/demo_staff_data.dart';

class StaffAuthScreen extends StatefulWidget {
  const StaffAuthScreen({super.key});

  @override
  State<StaffAuthScreen> createState() => _StaffAuthScreenState();
}

class _StaffAuthScreenState extends State<StaffAuthScreen> {
  final TextEditingController _pinController = TextEditingController();
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isLoading = false;
  final bool _obscurePin = true;
  Staff? _selectedStaff;
  bool _showStaffSelection = true;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _authenticateWithBiometrics() async {
    try {
      // Check if biometric authentication is available
      final isAvailable = await _localAuth.canCheckBiometrics;
      if (!isAvailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric authentication not available')),
        );
        return;
      }

      // For now, just show that biometric auth is not implemented
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Biometric authentication not implemented yet')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Authentication error: ${e.toString()}')),
      );
    }
  }

  Future<void> _authenticateWithPin() async {
    if (_pinController.text.length != 6 || _selectedStaff == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select staff and enter 6-digit PIN')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = AuthService();
      
      // Use AuthService to authenticate staff with phone and PIN
      final user = await authService.signInStaffWithPin(
        _selectedStaff!.phone, 
        _pinController.text
      );
      
      if (user != null) {
        // Store logged-in staff info
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('currentStaffId', _selectedStaff!.id);
        await prefs.setString('currentStaffName', _selectedStaff!.name);
        await prefs.setString('currentStaffRole', _selectedStaff!.role);
        await prefs.setString('currentStaffPhone', _selectedStaff!.phone);

        // Navigate to role-based dashboard which will route to staff dashboard
        Navigator.pushReplacementNamed(context, '/dashboard');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid PIN for selected staff')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Authentication failed: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildStaffSelection() {
    return StreamBuilder<List<DocumentSnapshot>>(
      stream: FirebaseFirestore.instance
          .collection('staff')
          .where('isActive', isEqualTo: true)
          .snapshots()
          .map((snapshot) {
            final docs = snapshot.docs;
            // Sort by name in ascending order
            docs.sort((a, b) {
              final aName = a.data()['name'] as String? ?? '';
              final bName = b.data()['name'] as String? ?? '';
              return aName.compareTo(bName);
            });
            return docs;
          }),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Error loading staff'),
                const SizedBox(height: 16),
                Text(
                  'Details: ${snapshot.error}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // Retry button
                    setState(() {});
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final staffDocs = snapshot.data!;
        if (staffDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('No active staff members found'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await DemoStaffData.populateDemoData();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text('Demo staff data loaded successfully')),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                'Error loading demo data: ${e.toString()}')),
                      );
                    }
                  },
                  child: const Text('Load Demo Staff'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await DemoStaffData.addPinsToExistingStaff();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text('PINs added to existing staff successfully')),
                      );
                      // Refresh the staff list
                      setState(() {});
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                'Error adding PINs: ${e.toString()}')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                  child: const Text('Add PINs to Existing Staff'),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            const Text(
              'Select Your Name',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...staffDocs.map((doc) {
              final staff = Staff.fromFirestore(doc);
              return Card(
                child: ListTile(
                  title: Text(staff.name),
                  subtitle: Text('${staff.role} - ${staff.department}'),
                  leading: const Icon(Icons.person),
                  trailing: _selectedStaff?.id == staff.id
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedStaff = staff;
                      _showStaffSelection = false;
                    });
                  },
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildPinEntry() {
    return Column(
      children: [
        Text(
          'Welcome, ${_selectedStaff!.name}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter your 6-digit PIN',
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
        const SizedBox(height: 24),
        PinCodeTextField(
          appContext: context,
          controller: _pinController,
          length: 6,
          obscureText: _obscurePin,
          obscuringCharacter: '*',
          keyboardType: TextInputType.number,
          pinTheme: PinTheme(
            shape: PinCodeFieldShape.box,
            borderRadius: BorderRadius.circular(8),
            fieldHeight: 60,
            fieldWidth: 50,
            activeFillColor: Colors.white,
            inactiveFillColor: Colors.grey[100],
            selectedFillColor: Colors.blue[50],
            activeColor: Colors.blue,
            inactiveColor: Colors.grey,
            selectedColor: Colors.blue,
          ),
          onCompleted: (v) {
            _authenticateWithPin();
          },
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _authenticateWithPin,
          icon: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.lock_open),
          label: const Text('Login'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          ),
        ),
        TextButton(
          onPressed: () {
            setState(() {
              _selectedStaff = null;
              _showStaffSelection = true;
              _pinController.clear();
            });
          },
          child: const Text('Not you? Select different staff'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Staff Login'),
        elevation: 0,
        backgroundColor: Colors.blue,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child:
              _showStaffSelection ? _buildStaffSelection() : _buildPinEntry(),
        ),
      ),
    );
  }
}
