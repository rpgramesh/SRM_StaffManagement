import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/staff.dart';
import '../../services/staff_service.dart';
import '../../utils/australian_phone_number.dart';
import '../../utils/australian_phone_text_input_formatter.dart';

class UpdateProfileScreen extends StatefulWidget {
  final Staff staff;

  const UpdateProfileScreen({super.key, required this.staff});

  @override
  State<UpdateProfileScreen> createState() => _UpdateProfileScreenState();
}

class _UpdateProfileScreenState extends State<UpdateProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _staffService = StaffService();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emergencyContactController;
  late TextEditingController _addressController;
  late TextEditingController _skillsController;

  String? _selectedShiftPreference;
  int? _workHoursPerWeek;
  bool _isLoading = false;
  bool _hasChanges = false;

  final List<String> _shiftPreferences = [
    'Morning (6 AM - 2 PM)',
    'Afternoon (2 PM - 10 PM)',
    'Night (10 PM - 6 AM)',
    'Flexible',
  ];

  String? _validateRequiredAustralianPhone(String? value) {
    final digits = AustralianPhoneNumber.digitsOnly(value ?? '');
    if (digits.isEmpty) {
      return 'Phone number is required';
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

  String? _validateOptionalAustralianPhone(String? value) {
    final digits = AustralianPhoneNumber.digitsOnly(value ?? '');
    if (digits.isEmpty) {
      return null;
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

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _nameController = TextEditingController(text: widget.staff.name);
    _phoneController = TextEditingController(
      text: AustralianPhoneNumber.tryParse(widget.staff.phone)?.localDisplay ??
          widget.staff.phone,
    );
    _emergencyContactController = TextEditingController(
      text: AustralianPhoneNumber.tryParse(widget.staff.emergencyContact ?? '')
              ?.localDisplay ??
          (widget.staff.emergencyContact ?? ''),
    );
    _addressController =
        TextEditingController(text: widget.staff.address ?? '');
    _skillsController =
        TextEditingController(text: widget.staff.skills?.join(', ') ?? '');

    _selectedShiftPreference = widget.staff.shiftPreference;
    _workHoursPerWeek = widget.staff.workHoursPerWeek;

    // Add listeners to detect changes
    _nameController.addListener(_onFieldChanged);
    _phoneController.addListener(_onFieldChanged);
    _emergencyContactController.addListener(_onFieldChanged);
    _addressController.addListener(_onFieldChanged);
    _skillsController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emergencyContactController.dispose();
    _addressController.dispose();
    _skillsController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Verify user authentication
    final prefs = await SharedPreferences.getInstance();
    final currentStaffId = prefs.getString('currentStaffId');
    if (currentStaffId == null) {
      _showErrorDialog(
          'Authentication Error', 'Please log in to update your profile.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Parse skills from comma-separated string
      List<String> skills = _skillsController.text
          .split(',')
          .map((skill) => skill.trim())
          .where((skill) => skill.isNotEmpty)
          .toList();

      final normalizedPhone =
          AustralianPhoneNumber.normalizeToStorageFormat(_phoneController.text);
      final normalizedEmergencyContact =
          _emergencyContactController.text.trim().isEmpty
              ? null
              : AustralianPhoneNumber.normalizeToStorageFormat(
                  _emergencyContactController.text,
                );

      if (normalizedPhone == null) {
        _showErrorDialog(
          'Invalid Phone Number',
          AustralianPhoneNumber.submitErrorMessage(internationalMode: false),
        );
        return;
      }

      if (_emergencyContactController.text.trim().isNotEmpty &&
          normalizedEmergencyContact == null) {
        _showErrorDialog(
          'Invalid Emergency Contact',
          AustralianPhoneNumber.submitErrorMessage(internationalMode: false),
        );
        return;
      }

      // Create updated staff object
      final updatedStaff = widget.staff.copyWith(
        name: _nameController.text.trim(),
        phone: normalizedPhone,
        emergencyContact: normalizedEmergencyContact,
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        shiftPreference: _selectedShiftPreference,
        workHoursPerWeek: _workHoursPerWeek,
        skills: skills.isEmpty ? null : skills,
      );

      // Update profile in Firestore
      await _staffService.updateStaff(updatedStaff);

      setState(() {
        _hasChanges = false;
      });

      _showSuccessDialog();
    } catch (e) {
      _showErrorDialog(
          'Update Failed', 'Failed to update profile: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
        title: const Text('Profile Updated'),
        content: const Text('Your profile has been successfully updated.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context)
                  .pop(true); // Return to previous screen with success
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.error, color: Colors.red, size: 48),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text(
            'You have unsaved changes. Are you sure you want to leave?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Update Profile'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          actions: [
            if (_hasChanges)
              TextButton(
                onPressed: _isLoading ? null : _updateProfile,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save', style: TextStyle(color: Colors.white)),
              ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Profile Header
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: widget.staff.profileImage != null
                            ? ClipOval(
                                child: Image.network(
                                  widget.staff.profileImage!,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Text(
                                    widget.staff.name.isNotEmpty
                                        ? widget.staff.name[0].toUpperCase()
                                        : 'U',
                                    style: const TextStyle(
                                      fontSize: 36,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              )
                            : Text(
                                widget.staff.name.isNotEmpty
                                    ? widget.staff.name[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  fontSize: 36,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.staff.role,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        widget.staff.department,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Personal Information Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Personal Information',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          prefixIcon: Icon(Icons.phone),
                          hintText: '(04) 1234 5678',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.phone,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.digitsOnly,
                          AustralianLocalPhoneInputFormatter(),
                        ],
                        validator: (value) {
                          return _validateRequiredAustralianPhone(value);
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emergencyContactController,
                        decoration: const InputDecoration(
                          labelText: 'Emergency Contact',
                          prefixIcon: Icon(Icons.emergency),
                          border: OutlineInputBorder(),
                          helperText: 'Optional',
                          hintText: '(02) 1234 5678',
                        ),
                        keyboardType: TextInputType.phone,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.digitsOnly,
                          AustralianLocalPhoneInputFormatter(),
                        ],
                        validator: (value) {
                          return _validateOptionalAustralianPhone(value);
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(
                          labelText: 'Address',
                          prefixIcon: Icon(Icons.location_on),
                          border: OutlineInputBorder(),
                          helperText: 'Optional',
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Work Preferences Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Work Preferences',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedShiftPreference,
                        decoration: const InputDecoration(
                          labelText: 'Shift Preference',
                          prefixIcon: Icon(Icons.schedule),
                          border: OutlineInputBorder(),
                          helperText: 'Optional',
                        ),
                        items: _shiftPreferences.map((preference) {
                          return DropdownMenuItem(
                            value: preference,
                            child: Text(preference),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedShiftPreference = value;
                            _onFieldChanged();
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        initialValue: _workHoursPerWeek,
                        decoration: const InputDecoration(
                          labelText: 'Work Hours Per Week',
                          prefixIcon: Icon(Icons.access_time),
                          border: OutlineInputBorder(),
                          helperText: 'Optional',
                        ),
                        items: [20, 25, 30, 35, 40, 45, 50].map((hours) {
                          return DropdownMenuItem(
                            value: hours,
                            child: Text('$hours hours'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _workHoursPerWeek = value;
                            _onFieldChanged();
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _skillsController,
                        decoration: const InputDecoration(
                          labelText: 'Skills',
                          prefixIcon: Icon(Icons.star),
                          border: OutlineInputBorder(),
                          helperText: 'Separate multiple skills with commas',
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Read-only Information Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Employment Information',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      _buildReadOnlyField(
                          'Email', widget.staff.email, Icons.email),
                      const SizedBox(height: 12),
                      _buildReadOnlyField(
                          'Employee ID', widget.staff.id, Icons.badge),
                      const SizedBox(height: 12),
                      _buildReadOnlyField(
                          'Hire Date',
                          '${widget.staff.hireDate.day}/${widget.staff.hireDate.month}/${widget.staff.hireDate.year}',
                          Icons.calendar_today),
                      const SizedBox(height: 12),
                      _buildReadOnlyField(
                          'Total Hours Worked',
                          '${widget.staff.totalHoursWorked.toStringAsFixed(1)} hours',
                          Icons.timer),
                      const SizedBox(height: 12),
                      _buildReadOnlyField('Shifts Completed',
                          '${widget.staff.shiftsCompleted} shifts', Icons.work),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Update Button
              if (_hasChanges)
                ElevatedButton(
                  onPressed: _isLoading ? null : _updateProfile,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('Updating Profile...'),
                          ],
                        )
                      : const Text(
                          'Update Profile',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
