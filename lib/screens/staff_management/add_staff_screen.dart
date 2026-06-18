import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/staff_provider.dart';
import '../../models/staff.dart';
import '../../utils/australian_phone_number.dart';
import '../../utils/australian_phone_text_input_formatter.dart';

class AddStaffScreen extends StatefulWidget {
  const AddStaffScreen({super.key});

  @override
  State<AddStaffScreen> createState() => _AddStaffScreenState();
}

class _AddStaffScreenState extends State<AddStaffScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _salaryController = TextEditingController();
  final _pinController = TextEditingController();

  String? _validateAustralianPhone(String? value) {
    final digits = AustralianPhoneNumber.digitsOnly(value ?? '');
    if (digits.isEmpty) {
      return 'Please enter a phone number';
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

  String _selectedRole = 'Waiter';
  String _selectedDepartment = 'Kitchen';
  DateTime _hireDate = DateTime.now();

  final List<String> _roles = [
    'Manager',
    'Supervisor',
    'Waiter',
    'Cook',
    'Cashier',
    'Bartender',
    'Host',
    'Dishwasher',
  ];

  final List<String> _departments = [
    'Kitchen',
    'Front of House',
    'Management',
    'Bar',
    'Cleaning',
    'Delivery',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _salaryController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Widget _buildPinField() {
    return TextFormField(
      controller: _pinController,
      decoration: const InputDecoration(
        labelText: 'Staff PIN (6 digits)',
        hintText: 'Enter 6-digit PIN',
        prefixIcon: Icon(Icons.lock),
        border: OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      maxLength: 6,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter a PIN';
        }
        if (value.length != 6 || !RegExp(r'^\d{6}$').hasMatch(value)) {
          return 'Please enter a valid 6-digit PIN';
        }
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Staff'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Personal Information'),
              const SizedBox(height: 16),
              _buildNameField(),
              const SizedBox(height: 16),
              _buildEmailField(),
              const SizedBox(height: 16),
              _buildPhoneField(),
              const SizedBox(height: 24),
              _buildSectionTitle('Employment Details'),
              const SizedBox(height: 16),
              _buildRoleDropdown(),
              const SizedBox(height: 16),
              _buildDepartmentDropdown(),
              const SizedBox(height: 16),
              _buildSalaryField(),
              const SizedBox(height: 16),
              _buildHireDatePicker(),
              const SizedBox(height: 16),
              _buildPinField(),
              const SizedBox(height: 32),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      decoration: const InputDecoration(
        labelText: 'Full Name *',
        hintText: 'Enter staff member\'s full name',
        prefixIcon: Icon(Icons.person),
        border: OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter the staff member\'s name';
        }
        return null;
      },
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      decoration: const InputDecoration(
        labelText: 'Email Address *',
        hintText: 'Enter email address',
        prefixIcon: Icon(Icons.email),
        border: OutlineInputBorder(),
      ),
      keyboardType: TextInputType.emailAddress,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter an email address';
        }
        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
          return 'Please enter a valid email address';
        }
        return null;
      },
    );
  }

  Widget _buildPhoneField() {
    return TextFormField(
      controller: _phoneController,
      decoration: const InputDecoration(
        labelText: 'Phone Number *',
        hintText: '(04) 1234 5678',
        prefixIcon: Icon(Icons.phone),
        border: OutlineInputBorder(),
      ),
      keyboardType: TextInputType.phone,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
        AustralianLocalPhoneInputFormatter(),
      ],
      validator: (value) {
        return _validateAustralianPhone(value);
      },
    );
  }

  Widget _buildRoleDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedRole,
      decoration: const InputDecoration(
        labelText: 'Role *',
        prefixIcon: Icon(Icons.work),
        border: OutlineInputBorder(),
      ),
      items: _roles
          .map((role) => DropdownMenuItem(
                value: role,
                child: Text(role),
              ))
          .toList(),
      onChanged: (value) {
        setState(() {
          _selectedRole = value!;
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a role';
        }
        return null;
      },
    );
  }

  Widget _buildDepartmentDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedDepartment,
      decoration: const InputDecoration(
        labelText: 'Department *',
        prefixIcon: Icon(Icons.apartment),
        border: OutlineInputBorder(),
      ),
      items: _departments
          .map((department) => DropdownMenuItem(
                value: department,
                child: Text(department),
              ))
          .toList(),
      onChanged: (value) {
        setState(() {
          _selectedDepartment = value!;
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a department';
        }
        return null;
      },
    );
  }

  Widget _buildSalaryField() {
    return TextFormField(
      controller: _salaryController,
      decoration: const InputDecoration(
        labelText: 'Monthly Salary *',
        hintText: 'Enter monthly salary',
        prefixIcon: Icon(Icons.money),
        prefixText: 'A\$',
        border: OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter a salary amount';
        }
        if (double.tryParse(value) == null) {
          return 'Please enter a valid number';
        }
        if (double.parse(value) <= 0) {
          return 'Please enter a positive amount';
        }
        return null;
      },
    );
  }

  Widget _buildHireDatePicker() {
    return InkWell(
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: _hireDate,
          firstDate: DateTime(2000),
          lastDate: DateTime.now(),
        );
        if (picked != null && picked != _hireDate) {
          setState(() {
            _hireDate = picked;
          });
        }
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Hire Date *',
          prefixIcon: Icon(Icons.calendar_today),
          border: OutlineInputBorder(),
        ),
        child: Text(
          _formatDate(_hireDate),
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _submitForm,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: const Text(
          'Add Staff Member',
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      try {
        final normalizedPhone = AustralianPhoneNumber.normalizeToStorageFormat(
          _phoneController.text,
        );
        if (normalizedPhone == null) {
          throw Exception(
            AustralianPhoneNumber.submitErrorMessage(
              internationalMode: false,
            ),
          );
        }

        final newStaff = Staff(
          id: '', // Will be generated by Firestore
          name: _nameController.text,
          email: _emailController.text,
          phone: normalizedPhone,
          role: _selectedRole,
          department: _selectedDepartment,
          hourlyRate: double.parse(_salaryController.text) / 2080,
          salary: double.parse(_salaryController.text),
          hireDate: _hireDate,
          pin: _pinController.text, // Add PIN
        );

        await context.read<StaffProvider>().addStaff(newStaff);

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Staff member added successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error adding staff: $e')),
          );
        }
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
