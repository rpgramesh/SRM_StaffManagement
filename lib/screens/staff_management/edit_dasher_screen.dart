import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../services/manager_service.dart';

class EditDasherScreen extends StatefulWidget {
  final Map<String, dynamic> dasher;
  
  const EditDasherScreen({super.key, required this.dasher});

  @override
  State<EditDasherScreen> createState() => _EditDasherScreenState();
}

class _EditDasherScreenState extends State<EditDasherScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _vehicleNumberController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  final _addressController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  bool _isAvailable = true;
  bool _isOnline = false;
  final List<String> _vehicleTypes = ['Motorcycle', 'Bicycle', 'Car', 'Scooter'];
  String _selectedVehicleType = 'Motorcycle';
  
  // Authentication options
  String _selectedAuthMethod = 'PIN'; // Default to PIN
  final List<String> _authMethods = ['PIN', 'Fingerprint', 'Face ID'];
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isBiometricAvailable = false;
  List<BiometricType> _availableBiometrics = [];
  bool _faceIdEnrolled = false;
  bool _fingerprintEnrolled = false;
  bool _authMethodChanged = false;

  @override
  void initState() {
    super.initState();
    _populateFields();
    _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    // Skip biometric check on web platforms
    if (kIsWeb) {
      setState(() {
        _isBiometricAvailable = false;
        // Only PIN is available on web
      });
      return;
    }

    try {
      final bool isAvailable = await _localAuth.canCheckBiometrics;
      final List<BiometricType> availableBiometrics = await _localAuth.getAvailableBiometrics();
      
      setState(() {
        _isBiometricAvailable = isAvailable;
        _availableBiometrics = availableBiometrics;
      });
    } catch (e) {
      print('Error checking biometric availability: $e');
      setState(() {
        _isBiometricAvailable = false;
        _availableBiometrics = [];
      });
    }
  }

  void _populateFields() {
    _nameController.text = widget.dasher['name'] ?? '';
    _phoneController.text = widget.dasher['phone'] ?? '';
    _emailController.text = widget.dasher['email'] ?? '';
    _addressController.text = widget.dasher['address'] ?? '';
    _vehicleNumberController.text = widget.dasher['vehicle_number'] ?? '';
    _licenseNumberController.text = widget.dasher['license_number'] ?? '';
    _emergencyContactController.text = widget.dasher['emergency_contact'] ?? '';
    _selectedVehicleType = widget.dasher['vehicle_type'] ?? 'Motorcycle';
    _isAvailable = widget.dasher['isAvailable'] ?? true;
    _isOnline = widget.dasher['isOnline'] ?? false;
    
    // Populate authentication data
    _selectedAuthMethod = widget.dasher['authMethod'] ?? 'PIN';
    if (widget.dasher['authMethod'] == 'Fingerprint' || widget.dasher['authMethod'] == 'Face ID') {
      if (widget.dasher['authMethod'] == 'Fingerprint') {
        _fingerprintEnrolled = widget.dasher['biometricEnrolled'] ?? false;
      } else if (widget.dasher['authMethod'] == 'Face ID') {
        _faceIdEnrolled = widget.dasher['biometricEnrolled'] ?? false;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _vehicleNumberController.dispose();
    _licenseNumberController.dispose();
    _emergencyContactController.dispose();
    _addressController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Dasher'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _showDeleteConfirmation,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Personal Information'),
              _buildTextField(
                controller: _nameController,
                label: 'Full Name',
                icon: Icons.person,
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              ),
              _buildTextField(
                controller: _phoneController,
                label: 'Phone Number',
                icon: Icons.phone,
                keyboardType: TextInputType.phone,
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              ),
              _buildTextField(
                controller: _emailController,
                label: 'Email Address',
                icon: Icons.email,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Required';
                  if (!value!.contains('@')) return 'Invalid email';
                  return null;
                },
              ),
              _buildTextField(
                controller: _addressController,
                label: 'Address',
                icon: Icons.location_on,
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              ),
              
              const SizedBox(height: 20),
              _buildSectionHeader('Vehicle Information'),
              _buildDropdownField(),
              _buildTextField(
                controller: _vehicleNumberController,
                label: 'Vehicle Number',
                icon: Icons.directions_car,
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              ),
              _buildTextField(
                controller: _licenseNumberController,
                label: 'License Number',
                icon: Icons.credit_card,
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              ),
              
              const SizedBox(height: 20),
              _buildSectionHeader('Emergency Contact'),
              _buildTextField(
                controller: _emergencyContactController,
                label: 'Emergency Contact Number',
                icon: Icons.emergency,
                keyboardType: TextInputType.phone,
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
              ),
              
              const SizedBox(height: 20),
              _buildSectionHeader('Security Authentication'),
              _buildAuthenticationSection(),
              
              const SizedBox(height: 20),
              _buildSectionHeader('Status'),
              SwitchListTile(
                title: const Text('Available for Deliveries'),
                subtitle: Text(_isAvailable ? 'Dasher is available' : 'Dasher is not available'),
                value: _isAvailable,
                onChanged: (value) => setState(() => _isAvailable = value),
                activeThumbColor: Colors.green,
              ),
              SwitchListTile(
                title: const Text('Online Status'),
                subtitle: Text(_isOnline ? 'Dasher is online' : 'Dasher is offline'),
                value: _isOnline,
                onChanged: (value) => setState(() => _isOnline = value),
                activeThumbColor: Colors.blue,
              ),
              
              const SizedBox(height: 20),
              _buildSectionHeader('Statistics'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Rating:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('${widget.dasher['rating'] ?? 0}/5.0'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Deliveries:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('${widget.dasher['totalDeliveries'] ?? 0}'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Earnings:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('A\$${widget.dasher['totalEarnings'] ?? 0}'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _updateDasher,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Update Dasher',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAuthenticationSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Authentication Method',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            
            // Current authentication method display
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  Icon(_getAuthIcon(widget.dasher['authMethod'] ?? 'PIN')),
                  const SizedBox(width: 8),
                  Text(
                    'Current: ${widget.dasher['authMethod'] ?? 'PIN'}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  if (widget.dasher['authMethod'] != null)
                    Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 20,
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Authentication method selection for updates
            DropdownButtonFormField<String>(
              initialValue: _selectedAuthMethod,
              decoration: InputDecoration(
                labelText: 'Change Authentication Method',
                prefixIcon: const Icon(Icons.security),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              items: _getAvailableAuthMethods().map((String method) {
                return DropdownMenuItem<String>(
                  value: method,
                  child: Row(
                    children: [
                      Icon(_getAuthIcon(method)),
                      const SizedBox(width: 8),
                      Text(method),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedAuthMethod = newValue!;
                  _authMethodChanged = newValue != (widget.dasher['authMethod'] ?? 'PIN');
                  // Reset enrollment status when changing methods
                  _faceIdEnrolled = false;
                  _fingerprintEnrolled = false;
                  _pinController.clear();
                  _confirmPinController.clear();
                });
              },
            ),
            
            const SizedBox(height: 16),
            
            // Show PIN fields if PIN is selected and method changed
            if (_selectedAuthMethod == 'PIN' && _authMethodChanged) ..._buildPinFields(),
            
            // Show biometric enrollment buttons if method changed
            if (_selectedAuthMethod == 'Fingerprint' && _authMethodChanged) ..._buildFingerprintEnrollment(),
            if (_selectedAuthMethod == 'Face ID' && _authMethodChanged) ..._buildFaceIdEnrollment(),
            
            const SizedBox(height: 12),
            _buildAuthStatusIndicator(),
          ],
        ),
      ),
    );
  }

  List<String> _getAvailableAuthMethods() {
    List<String> methods = ['PIN'];
    
    if (_isBiometricAvailable) {
      if (_availableBiometrics.contains(BiometricType.fingerprint)) {
        methods.add('Fingerprint');
      }
      if (_availableBiometrics.contains(BiometricType.face)) {
        methods.add('Face ID');
      }
    }
    
    return methods;
  }

  IconData _getAuthIcon(String method) {
    switch (method) {
      case 'PIN':
        return Icons.pin;
      case 'Fingerprint':
        return Icons.fingerprint;
      case 'Face ID':
        return Icons.face;
      default:
        return Icons.security;
    }
  }

  List<Widget> _buildPinFields() {
    return [
      _buildTextField(
        controller: _pinController,
        label: 'Create new 4-digit PIN',
        icon: Icons.lock,
        keyboardType: TextInputType.number,
        obscureText: true,
        maxLength: 4,
        validator: (value) {
          if (!_authMethodChanged) return null;
          if (value?.isEmpty ?? true) return 'PIN is required';
          if (value!.length != 4) return 'PIN must be 4 digits';
          if (!RegExp(r'^[0-9]+\$').hasMatch(value)) return 'PIN must contain only numbers';
          return null;
        },
      ),
      _buildTextField(
        controller: _confirmPinController,
        label: 'Confirm new PIN',
        icon: Icons.lock_outline,
        keyboardType: TextInputType.number,
        obscureText: true,
        maxLength: 4,
        validator: (value) {
          if (!_authMethodChanged) return null;
          if (value?.isEmpty ?? true) return 'Please confirm PIN';
          if (value != _pinController.text) return 'PINs do not match';
          return null;
        },
      ),
    ];
  }

  List<Widget> _buildFingerprintEnrollment() {
    return [
      ElevatedButton.icon(
        onPressed: _enrollFingerprint,
        icon: Icon(_fingerprintEnrolled ? Icons.check_circle : Icons.fingerprint),
        label: Text(_fingerprintEnrolled ? 'Fingerprint Enrolled' : 'Enroll Fingerprint'),
        style: ElevatedButton.styleFrom(
          backgroundColor: _fingerprintEnrolled ? Colors.green : Colors.blue,
          foregroundColor: Colors.white,
        ),
      ),
    ];
  }

  List<Widget> _buildFaceIdEnrollment() {
    return [
      ElevatedButton.icon(
        onPressed: _enrollFaceId,
        icon: Icon(_faceIdEnrolled ? Icons.check_circle : Icons.face),
        label: Text(_faceIdEnrolled ? 'Face ID Enrolled' : 'Enroll Face ID'),
        style: ElevatedButton.styleFrom(
          backgroundColor: _faceIdEnrolled ? Colors.green : Colors.blue,
          foregroundColor: Colors.white,
        ),
      ),
    ];
  }

  Widget _buildAuthStatusIndicator() {
    bool isConfigured = false;
    String statusText = '';
    Color statusColor = Colors.red;
    
    if (!_authMethodChanged) {
      // Show current authentication status
      statusText = 'Current authentication method is configured';
      statusColor = Colors.green;
      isConfigured = true;
    } else {
      // Show new authentication status
      switch (_selectedAuthMethod) {
        case 'PIN':
          isConfigured = _pinController.text.length == 4 && _confirmPinController.text.length == 4;
          statusText = isConfigured ? 'New PIN configured' : 'New PIN not configured';
          break;
        case 'Fingerprint':
          isConfigured = _fingerprintEnrolled;
          statusText = isConfigured ? 'Fingerprint enrolled' : 'Fingerprint not enrolled';
          break;
        case 'Face ID':
          isConfigured = _faceIdEnrolled;
          statusText = isConfigured ? 'Face ID enrolled' : 'Face ID not enrolled';
          break;
      }
      statusColor = isConfigured ? Colors.green : Colors.red;
    }
    
    return Row(
      children: [
        Icon(
          isConfigured ? Icons.check_circle : Icons.error,
          color: statusColor,
          size: 16,
        ),
        const SizedBox(width: 8),
        Text(
          statusText,
          style: TextStyle(color: statusColor, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Future<void> _enrollFingerprint() async {
    try {
      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Please scan your fingerprint to enroll for dasher authentication',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      
      if (didAuthenticate) {
        setState(() {
          _fingerprintEnrolled = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fingerprint enrolled successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error enrolling fingerprint: \$e')),
      );
    }
  }

  Future<void> _enrollFaceId() async {
    try {
      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Please look at the camera to enroll Face ID for dasher authentication',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      
      if (didAuthenticate) {
        setState(() {
          _faceIdEnrolled = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Face ID enrolled successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error enrolling Face ID: \$e')),
      );
    }
  }

  String _hashPin(String pin) {
    var bytes = utf8.encode(pin);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool obscureText = false,
    int? maxLength,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        obscureText: obscureText,
        maxLength: maxLength,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.blue, width: 2),
          ),
          counterText: maxLength != null ? '' : null,
        ),
      ),
    );
  }

  Widget _buildDropdownField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        initialValue: _selectedVehicleType,
        decoration: InputDecoration(
          labelText: 'Vehicle Type',
          prefixIcon: const Icon(Icons.motorcycle),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.blue, width: 2),
          ),
        ),
        items: _vehicleTypes.map((String type) {
          return DropdownMenuItem<String>(
            value: type,
            child: Text(type),
          );
        }).toList(),
        onChanged: (String? newValue) {
          setState(() {
            _selectedVehicleType = newValue!;
          });
        },
        validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
      ),
    );
  }

  void _updateDasher() async {
    if (_formKey.currentState?.validate() ?? false) {
      // Prepare dasher data
      final dasherData = <String, dynamic>{
        'name': _nameController.text,
        'phone': _phoneController.text,
        'email': _emailController.text,
        'address': _addressController.text,
        'vehicle_type': _selectedVehicleType,
        'vehicle_number': _vehicleNumberController.text,
        'license_number': _licenseNumberController.text,
        'emergency_contact': _emergencyContactController.text,
        'isAvailable': _isAvailable,
        'isOnline': _isOnline,
      };

      // Handle authentication updates if method changed
      if (_authMethodChanged) {
        bool authConfigured = false;
        Map<String, dynamic> authData = {};
        
        switch (_selectedAuthMethod) {
          case 'PIN':
            if (_pinController.text.length == 4 && _confirmPinController.text.length == 4) {
              authConfigured = true;
              authData = {
                'authMethod': 'PIN',
                'pinHash': _hashPin(_pinController.text),
              };
            }
            break;
          case 'Fingerprint':
            if (_fingerprintEnrolled) {
              authConfigured = true;
              authData = {
                'authMethod': 'Fingerprint',
                'biometricEnrolled': true,
              };
            }
            break;
          case 'Face ID':
            if (_faceIdEnrolled) {
              authConfigured = true;
              authData = {
                'authMethod': 'Face ID',
                'biometricEnrolled': true,
              };
            }
            break;
        }
        
        if (!authConfigured) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Please configure \$_selectedAuthMethod authentication')),
          );
          return;
        }
        
        // Add authentication data to dasher data
        dasherData.addAll(authData);
      }

      try {
        await Provider.of<ManagerService>(context, listen: false)
            .updateDasher(widget.dasher['id'], dasherData);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dasher updated successfully')),
        );
        
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating dasher: \$e')),
        );
      }
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Dasher'),
        content: Text('Are you sure you want to delete ${widget.dasher['name']}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: _deleteDasher,
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _deleteDasher() async {
    try {
      await FirebaseFirestore.instance
          .collection('dashers')
          .doc(widget.dasher['id'])
          .delete();
      
      Navigator.pop(context); // Close dialog
      Navigator.pop(context); // Close edit screen
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dasher deleted successfully')),
      );
    } catch (e) {
      Navigator.pop(context); // Close dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting dasher: \$e')),
      );
    }
  }
}