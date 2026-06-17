import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/staff.dart';
import '../../providers/staff_provider.dart';
import '../../services/staff_migration_service.dart';
import '../../utils/australian_phone_number.dart';
import '../../utils/australian_phone_text_input_formatter.dart';

class EditStaffScreen extends StatefulWidget {
  final Staff staff;

  const EditStaffScreen({super.key, required this.staff});

  @override
  State<EditStaffScreen> createState() => _EditStaffScreenState();
}

class _EditStaffScreenState extends State<EditStaffScreen> {
  static const Map<String, String> _roleLabels = <String, String>{
    'admin': 'Admin',
    'manager': 'Manager',
    'supervisor': 'Supervisor',
    'staff': 'Staff',
    'waiter': 'Waiter',
    'cook': 'Cook',
    'cashier': 'Cashier',
    'bartender': 'Bartender',
    'host': 'Host',
    'dishwasher': 'Dishwasher',
  };

  static const List<String> _departmentOptions = <String>[
    '',
    'Kitchen',
    'Front of House',
    'Management',
    'Bar',
    'Cleaning',
    'Delivery',
  ];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _salaryController;
  late final TextEditingController _pinController;

  late String _selectedRole;
  late String _selectedDepartment;
  late DateTime _hireDate;
  late bool _isActive;
  late String? _profileImageUrl;

  bool _isSaving = false;
  bool _obscurePin = true;
  bool _isUploadingPhoto = false;

  Uint8List? _pendingProfileImageBytes;
  String? _pendingProfileImageFileName;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.staff.name);
    _emailController = TextEditingController(text: widget.staff.email);
    _phoneController = TextEditingController(
      text: AustralianPhoneNumber.tryParse(widget.staff.phone)?.localDisplay ??
          widget.staff.phone,
    );
    _salaryController = TextEditingController(text: _initialSalaryText());
    _pinController = TextEditingController();
    _selectedRole = _resolveRole(widget.staff.role);
    _selectedDepartment = _resolveDepartment(widget.staff.department);
    _hireDate = widget.staff.hireDate;
    _isActive = widget.staff.isActive;
    _profileImageUrl = widget.staff.profileImage;
    _nameController.addListener(_handleNameChanged);
  }

  @override
  void dispose() {
    _nameController.removeListener(_handleNameChanged);
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _salaryController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _handleNameChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  String _initialSalaryText() {
    final salary = widget.staff.salary ?? (widget.staff.hourlyRate * 2080);
    final hasFraction = salary % 1 != 0;
    return salary.toStringAsFixed(hasFraction ? 2 : 0);
  }

  String _resolveRole(String role) {
    final normalized = role.trim().toLowerCase();
    if (_roleLabels.containsKey(normalized)) {
      return normalized;
    }
    return 'staff';
  }

  String _resolveDepartment(String department) {
    final trimmed = department.trim();
    if (_departmentOptions.contains(trimmed)) {
      return trimmed;
    }
    return '';
  }

  String _roleLabel(String role) => _roleLabels[role] ?? role;

  String _departmentLabel(String department) {
    return department.isEmpty ? 'Not Set' : department;
  }

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

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    String? hintText,
    Widget? suffixIcon,
    String? helperText,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      helperText: helperText,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.blue, width: 1.5),
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: Colors.blue.shade700),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildResponsivePair(Widget left, Widget right) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 620) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: left),
              const SizedBox(width: 16),
              Expanded(child: right),
            ],
          );
        }

        return Column(
          children: [
            left,
            const SizedBox(height: 16),
            right,
          ],
        );
      },
    );
  }

  String get _displayName {
    final name = _nameController.text.trim();
    return name.isEmpty ? widget.staff.name : name;
  }

  ImageProvider? _profileImageProvider() {
    if (_pendingProfileImageBytes != null) {
      return MemoryImage(_pendingProfileImageBytes!);
    }
    if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      return NetworkImage(_profileImageUrl!);
    }
    return null;
  }

  Future<void> _showAvatarOptions() async {
    if (_isSaving || _isUploadingPhoto) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final hasImage = _pendingProfileImageBytes != null ||
            (_profileImageUrl != null && _profileImageUrl!.isNotEmpty);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Profile Photo',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'Upload, replace, or remove the staff avatar shown across the app.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('Take Photo'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _pickProfileImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.photo_library_outlined),
                  title: Text(hasImage ? 'Replace Photo' : 'Upload Photo'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _pickProfileImage(ImageSource.gallery);
                  },
                ),
                if (hasImage)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading:
                        const Icon(Icons.delete_outline, color: Colors.red),
                    title: const Text(
                      'Remove Photo',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _removeProfileImage();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Uint8List _cropAndCompressProfileImage(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('Unsupported image format.');
    }

    final shortestSide =
        decoded.width < decoded.height ? decoded.width : decoded.height;
    final xOffset = (decoded.width - shortestSide) ~/ 2;
    final yOffset = (decoded.height - shortestSide) ~/ 2;

    final cropped = img.copyCrop(
      decoded,
      x: xOffset,
      y: yOffset,
      width: shortestSide,
      height: shortestSide,
    );
    final resized = img.copyResize(
      cropped,
      width: 720,
      height: 720,
      interpolation: img.Interpolation.average,
    );

    return Uint8List.fromList(img.encodeJpg(resized, quality: 82));
  }

  Future<void> _pickProfileImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final selected = await picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 1400,
        maxHeight: 1400,
      );

      if (selected == null) {
        return;
      }

      final bytes = await selected.readAsBytes();
      final processedBytes = _cropAndCompressProfileImage(bytes);
      if (!mounted) {
        return;
      }

      setState(() {
        _pendingProfileImageBytes = processedBytes;
        _pendingProfileImageFileName =
            '${selected.name.split('.').first}_avatar.jpg';
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to select image: $e')),
      );
    }
  }

  void _removeProfileImage() {
    setState(() {
      _pendingProfileImageBytes = null;
      _pendingProfileImageFileName = null;
      _profileImageUrl = null;
    });
  }

  Future<String?> _uploadPendingProfileImage() async {
    if (_pendingProfileImageBytes == null) {
      return _profileImageUrl;
    }

    setState(() {
      _isUploadingPhoto = true;
    });

    try {
      final extension = _pendingProfileImageFileName != null &&
              _pendingProfileImageFileName!.contains('.')
          ? _pendingProfileImageFileName!.split('.').last.toLowerCase()
          : 'jpg';
      final contentType = 'image/jpeg';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('staff_profiles')
          .child(
              '${widget.staff.id}_${DateTime.now().millisecondsSinceEpoch}.$extension');

      await storageRef.putData(
        _pendingProfileImageBytes!,
        SettableMetadata(contentType: contentType),
      );
      final downloadUrl = await storageRef.getDownloadURL();

      if (!mounted) {
        return downloadUrl;
      }

      setState(() {
        _profileImageUrl = downloadUrl;
        _pendingProfileImageBytes = null;
        _pendingProfileImageFileName = null;
      });

      return downloadUrl;
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
        });
      }
    }
  }

  Future<void> _showResetPinDialog() async {
    if (_isSaving) {
      return;
    }

    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    bool obscurePin = true;
    bool obscureConfirm = true;
    String? validationError;
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final dialogNavigator = Navigator.of(dialogContext);
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> submit() async {
              final pin = pinController.text.trim();
              final confirmPin = confirmController.text.trim();

              if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
                setDialogState(() {
                  validationError = 'PIN must be exactly 6 digits.';
                });
                return;
              }
              if (pin != confirmPin) {
                setDialogState(() {
                  validationError = 'PIN confirmation does not match.';
                });
                return;
              }

              setDialogState(() {
                validationError = null;
                isSubmitting = true;
              });

              try {
                await StaffMigrationService.setStaffPin(
                  staffId: widget.staff.id,
                  pin: pin,
                );

                if (!mounted) {
                  return;
                }

                setState(() {
                  _pinController.text = pin;
                });
                dialogNavigator.pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PIN reset successfully')),
                );
              } catch (e) {
                setDialogState(() {
                  validationError =
                      e.toString().replaceFirst('Exception: ', '');
                  isSubmitting = false;
                });
              }
            }

            return AlertDialog(
              title: const Text('Reset PIN'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Set a new 6-digit login PIN for $_displayName.',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: pinController,
                    obscureText: obscurePin,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    decoration: InputDecoration(
                      labelText: 'New PIN',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: isSubmitting
                            ? null
                            : () {
                                setDialogState(() {
                                  obscurePin = !obscurePin;
                                });
                              },
                        icon: Icon(
                          obscurePin ? Icons.visibility : Icons.visibility_off,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmController,
                    obscureText: obscureConfirm,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    onSubmitted: (_) => submit(),
                    decoration: InputDecoration(
                      labelText: 'Confirm PIN',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: isSubmitting
                            ? null
                            : () {
                                setDialogState(() {
                                  obscureConfirm = !obscureConfirm;
                                });
                              },
                        icon: Icon(
                          obscureConfirm
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                      ),
                    ),
                  ),
                  if (validationError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      validationError!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting ? null : submit,
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Reset PIN'),
                ),
              ],
            );
          },
        );
      },
    );

    pinController.dispose();
    confirmController.dispose();
  }

  Future<void> _showDeleteStaffConfirmation() async {
    if (_isSaving) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Staff'),
          content: Text(
            'Delete $_displayName permanently? This removes the staff record and login access.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _isSaving = true;
    });

    try {
      await context.read<StaffProvider>().deleteStaff(widget.staff.id);

      if (!mounted) {
        return;
      }

      navigator.pop();
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Staff deleted successfully')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Error deleting staff: $e')),
      );
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _toggleStaffActiveStatus() async {
    if (_isSaving) {
      return;
    }

    final targetIsActive = !_isActive;
    final actionLabel = targetIsActive ? 'reactivate' : 'deactivate';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(targetIsActive ? 'Reactivate Staff' : 'Deactivate Staff'),
          content: Text(
            'Do you want to $actionLabel $_displayName? This keeps the account data but ${targetIsActive ? 'restores' : 'removes'} sign-in access.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: targetIsActive
                    ? Colors.green.shade700
                    : Colors.orange.shade700,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(targetIsActive ? 'Reactivate' : 'Deactivate'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final staffProvider = context.read<StaffProvider>();
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _isSaving = true;
    });

    try {
      await staffProvider.updateStaff(
        widget.staff.copyWith(
          isActive: targetIsActive,
          profileImage: _profileImageUrl,
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isActive = targetIsActive;
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            targetIsActive
                ? 'Staff account reactivated successfully'
                : 'Staff account deactivated successfully',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Error updating staff status: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Widget _buildHeaderCard() {
    final initials = _displayName.isNotEmpty
        ? _displayName.substring(0, 1).toUpperCase()
        : 'S';
    final profileImage = _profileImageProvider();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: Colors.blue.shade100),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            colors: [
              Colors.blue.shade50,
              Colors.white,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.blue.shade600,
                      backgroundImage: profileImage,
                      child: profileImage == null
                          ? Text(
                              initials,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        elevation: 2,
                        child: IconButton(
                          onPressed: _isSaving || _isUploadingPhoto
                              ? null
                              : _showAvatarOptions,
                          icon: _isUploadingPhoto
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.camera_alt_outlined, size: 18),
                          tooltip: 'Edit profile photo',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _displayName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildInfoChip(
                            icon: Icons.badge_outlined,
                            label: _roleLabel(_selectedRole),
                            backgroundColor: Colors.blue.shade50,
                            foregroundColor: Colors.blue.shade800,
                          ),
                          _buildInfoChip(
                            icon: _isActive
                                ? Icons.check_circle
                                : Icons.pause_circle,
                            label: _isActive ? 'Active' : 'Inactive',
                            backgroundColor: _isActive
                                ? Colors.green.shade50
                                : Colors.orange.shade50,
                            foregroundColor: _isActive
                                ? Colors.green.shade800
                                : Colors.orange.shade800,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Employee ID: ${widget.staff.id}',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 6),
            Text(
              'Update contact details, employment settings, and access options for this staff member.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: _isSaving ? null : _showResetPinDialog,
                  icon: const Icon(Icons.lock_reset),
                  label: const Text('Reset PIN'),
                ),
                OutlinedButton.icon(
                  onPressed: _isSaving || _isUploadingPhoto
                      ? null
                      : _showAvatarOptions,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(
                    profileImage == null ? 'Add Photo' : 'Change Photo',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foregroundColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: foregroundColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      textCapitalization: TextCapitalization.words,
      decoration: _fieldDecoration(
        label: 'Full Name',
        icon: Icons.person_outline,
        hintText: 'Enter staff full name',
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter the staff member\'s name';
        }
        return null;
      },
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      decoration: _fieldDecoration(
        label: 'Email Address',
        icon: Icons.alternate_email,
        hintText: 'name@example.com',
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter an email address';
        }
        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value.trim())) {
          return 'Please enter a valid email address';
        }
        return null;
      },
    );
  }

  Widget _buildPhoneField() {
    return TextFormField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
        AustralianLocalPhoneInputFormatter(),
      ],
      decoration: _fieldDecoration(
        label: 'Phone Number',
        icon: Icons.phone_outlined,
        hintText: '(04) 1234 5678',
        helperText: 'Stored as +61 for login and messaging.',
      ),
      validator: _validateAustralianPhone,
    );
  }

  Widget _buildRoleDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedRole,
      decoration: _fieldDecoration(
        label: 'Role',
        icon: Icons.work_outline,
      ),
      items: _roleLabels.entries
          .map(
            (entry) => DropdownMenuItem<String>(
              value: entry.key,
              child: Text(entry.value),
            ),
          )
          .toList(),
      onChanged: _isSaving
          ? null
          : (value) {
              if (value == null) {
                return;
              }
              setState(() {
                _selectedRole = value;
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
      decoration: _fieldDecoration(
        label: 'Department',
        icon: Icons.apartment_outlined,
      ),
      items: _departmentOptions
          .map(
            (department) => DropdownMenuItem<String>(
              value: department,
              child: Text(_departmentLabel(department)),
            ),
          )
          .toList(),
      onChanged: _isSaving
          ? null
          : (value) {
              if (value == null) {
                return;
              }
              setState(() {
                _selectedDepartment = value;
              });
            },
      validator: (value) {
        if (value == null) {
          return 'Please select a department';
        }
        return null;
      },
    );
  }

  Widget _buildSalaryField() {
    return TextFormField(
      controller: _salaryController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: _fieldDecoration(
        label: 'Annual Salary',
        icon: Icons.payments_outlined,
        helperText: 'Used to estimate hourly rate for reporting.',
      ).copyWith(prefixText: 'A\$ '),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter a salary amount';
        }
        final parsed = double.tryParse(value.trim());
        if (parsed == null) {
          return 'Please enter a valid number';
        }
        if (parsed <= 0) {
          return 'Please enter a positive amount';
        }
        return null;
      },
    );
  }

  Widget _buildHireDatePicker() {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _isSaving
          ? null
          : () async {
              final picked = await showDatePicker(
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
        decoration: _fieldDecoration(
          label: 'Hire Date',
          icon: Icons.calendar_month_outlined,
        ),
        child: Text(
          _formatDate(_hireDate),
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildPinField() {
    return TextFormField(
      controller: _pinController,
      keyboardType: TextInputType.number,
      obscureText: _obscurePin,
      maxLength: 6,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      decoration: _fieldDecoration(
        label: 'Staff PIN',
        icon: Icons.lock_outline,
        hintText: 'Enter new 6-digit PIN',
        helperText: 'Leave blank to keep the current PIN unchanged.',
        suffixIcon: IconButton(
          onPressed: _isSaving
              ? null
              : () {
                  setState(() {
                    _obscurePin = !_obscurePin;
                  });
                },
          icon: Icon(
            _obscurePin
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
      ),
      validator: (value) {
        if (value != null && value.isNotEmpty) {
          if (!RegExp(r'^\d{6}$').hasMatch(value)) {
            return 'Please enter a valid 6-digit PIN';
          }
        }
        return null;
      },
    );
  }

  Widget _buildStatusCard() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: SwitchListTile.adaptive(
        value: _isActive,
        onChanged: _isSaving
            ? null
            : (value) {
                setState(() {
                  _isActive = value;
                });
              },
        title: const Text(
          'Staff Account Active',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          _isActive
              ? 'This staff member can sign in and appear in active lists.'
              : 'This staff member will be hidden from active login and operational flows.',
        ),
        secondary: Icon(
          _isActive ? Icons.verified_user_outlined : Icons.block_outlined,
          color: _isActive ? Colors.green.shade700 : Colors.orange.shade700,
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isSaving ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _isSaving ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Save Changes',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextButton.icon(
                onPressed: _isSaving ? null : _toggleStaffActiveStatus,
                icon: Icon(
                  _isActive
                      ? Icons.person_off_outlined
                      : Icons.person_add_alt_1,
                ),
                label:
                    Text(_isActive ? 'Deactivate Staff' : 'Reactivate Staff'),
                style: TextButton.styleFrom(
                  foregroundColor: _isActive
                      ? Colors.orange.shade700
                      : Colors.green.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextButton.icon(
                onPressed: _isSaving ? null : _showDeleteStaffConfirmation,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete Staff'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Edit Staff'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 860),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeaderCard(),
                        const SizedBox(height: 20),
                        _buildSectionCard(
                          icon: Icons.badge_outlined,
                          title: 'Contact Details',
                          subtitle:
                              'Update how this staff member is identified and contacted.',
                          children: [
                            _buildNameField(),
                            const SizedBox(height: 16),
                            _buildResponsivePair(
                              _buildEmailField(),
                              _buildPhoneField(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildSectionCard(
                          icon: Icons.workspaces_outline,
                          title: 'Employment Settings',
                          subtitle:
                              'Adjust role, department, salary, and hire date.',
                          children: [
                            _buildResponsivePair(
                              _buildRoleDropdown(),
                              _buildDepartmentDropdown(),
                            ),
                            const SizedBox(height: 16),
                            _buildResponsivePair(
                              _buildSalaryField(),
                              _buildHireDatePicker(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildSectionCard(
                          icon: Icons.security_outlined,
                          title: 'Access & Security',
                          subtitle:
                              'Control sign-in status and optionally replace the current PIN.',
                          children: [
                            _buildPinField(),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildStatusCard(),
                        const SizedBox(height: 24),
                        _buildActionButtons(),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _submitForm() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final staffProvider = context.read<StaffProvider>();
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
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

      final uploadedProfileImage = await _uploadPendingProfileImage();
      final salary = double.parse(_salaryController.text.trim());
      final updatedStaff = Staff(
        id: widget.staff.id,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: normalizedPhone,
        role: _selectedRole,
        department: _selectedDepartment,
        hourlyRate: salary / 2080,
        salary: salary,
        hireDate: _hireDate,
        isActive: _isActive,
        profileImage: uploadedProfileImage,
        emergencyContact: widget.staff.emergencyContact,
        address: widget.staff.address,
        workHoursPerWeek: widget.staff.workHoursPerWeek,
        shiftPreference: widget.staff.shiftPreference,
        workingHours: widget.staff.workingHours,
        skills: widget.staff.skills,
        lastCheckIn: widget.staff.lastCheckIn,
        lastCheckOut: widget.staff.lastCheckOut,
        totalHoursWorked: widget.staff.totalHoursWorked,
        shiftsCompleted: widget.staff.shiftsCompleted,
        pin: _pinController.text.trim().isEmpty
            ? null
            : _pinController.text.trim(),
      );

      await staffProvider.updateStaff(updatedStaff);

      if (!mounted) {
        return;
      }

      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Staff member updated successfully')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating staff: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}
