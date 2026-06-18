import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/staff_migration_service.dart';
import '../../utils/australian_phone_number.dart';

class StaffMigrationScreen extends StatefulWidget {
  const StaffMigrationScreen({super.key});

  @override
  State<StaffMigrationScreen> createState() => _StaffMigrationScreenState();
}

class _StaffMigrationScreenState extends State<StaffMigrationScreen> {
  bool _isLoading = false;
  String _status = '';
  List<Map<String, dynamic>> _staffAccounts = [];

  @override
  void initState() {
    super.initState();
    _loadStaffAccounts();
  }

  Future<void> _loadStaffAccounts() async {
    try {
      final accounts = await StaffMigrationService.getAllStaffAccounts();
      setState(() {
        _staffAccounts = accounts;
      });
    } catch (e) {
      setState(() {
        _status = 'Error loading staff accounts: $e';
      });
    }
  }

  Future<void> _runMigration() async {
    setState(() {
      _isLoading = true;
      _status = 'Starting migration...';
    });

    try {
      await StaffMigrationService.migrateStaffToAccounts();
      setState(() {
        _status = 'Migration completed successfully!';
      });

      // Reload staff accounts
      await _loadStaffAccounts();
    } catch (e) {
      setState(() {
        _status = 'Migration failed: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showPinDialog(Map<String, dynamic> account) async {
    final pinController = TextEditingController();
    final confirmPinController = TextEditingController();
    String? validationError;
    bool isSaving = false;
    bool obscurePin = true;
    bool obscureConfirmPin = true;

    final bool hasPin = (account['pin'] ?? '').toString().trim().isNotEmpty;
    final String accountName = (account['name'] ?? 'Unknown').toString();
    final String accountPhone =
        (account['phone'] ?? account['phoneNumber'] ?? '').toString();
    final String? defaultPin =
        StaffMigrationService.generateDefaultPinFromPhone(accountPhone);

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submit() async {
              final pin = pinController.text.trim();
              final confirmPin = confirmPinController.text.trim();

              if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
                setDialogState(() {
                  validationError = 'PIN must be exactly 6 digits.';
                });
                return;
              }

              if (pin != confirmPin) {
                setDialogState(() {
                  validationError = 'PINs do not match.';
                });
                return;
              }

              setDialogState(() {
                isSaving = true;
                validationError = null;
              });

              try {
                await StaffMigrationService.setStaffPin(
                  staffId: account['id'].toString(),
                  pin: pin,
                  overwriteExisting: true,
                );

                if (!mounted || !context.mounted) {
                  return;
                }

                Navigator.of(context).pop();
                setState(() {
                  _status = hasPin
                      ? 'PIN reset successfully for $accountName.'
                      : 'PIN set successfully for $accountName.';
                });
                await _loadStaffAccounts();
              } catch (e) {
                setDialogState(() {
                  validationError =
                      e.toString().replaceFirst('Exception: ', '');
                  isSaving = false;
                });
              }
            }

            void applyDefaultPin() {
              if (defaultPin == null) {
                setDialogState(() {
                  validationError =
                      'A valid Australian phone number is required to generate a default PIN.';
                });
                return;
              }

              pinController.text = defaultPin;
              confirmPinController.text = defaultPin;
              setDialogState(() {
                validationError = null;
              });
            }

            return AlertDialog(
              title: Text(hasPin ? 'Reset PIN' : 'Set PIN'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Configure a 6-digit login PIN for $accountName.',
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: isSaving ? null : applyDefaultPin,
                        icon: const Icon(Icons.auto_fix_high),
                        label: const Text('Generate Default PIN'),
                      ),
                      if (defaultPin != null)
                        Text(
                          'Default: $defaultPin',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: pinController,
                    autofocus: true,
                    obscureText: obscurePin,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    decoration: InputDecoration(
                      labelText: 'PIN',
                      hintText: 'Enter 6-digit PIN',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: isSaving
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
                    controller: confirmPinController,
                    obscureText: obscureConfirmPin,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    onSubmitted: (_) => submit(),
                    decoration: InputDecoration(
                      labelText: 'Confirm PIN',
                      hintText: 'Re-enter PIN',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: isSaving
                            ? null
                            : () {
                                setDialogState(() {
                                  obscureConfirmPin = !obscureConfirmPin;
                                });
                              },
                        icon: Icon(
                          obscureConfirmPin
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                      ),
                    ),
                  ),
                  if (validationError != null) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(
                      validationError!,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed:
                      isSaving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : submit,
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(hasPin ? 'Reset PIN' : 'Set PIN'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteAccount(Map<String, dynamic> account) async {
    final String accountName = (account['name'] ?? 'Unknown').toString();
    final String accountId = (account['id'] ?? '').toString();
    if (accountId.isEmpty) {
      setState(() {
        _status = 'Error: missing account id for $accountName.';
      });
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Account'),
          content: Text(
            'Delete $accountName from the staff collection? This cannot be undone and will remove login access.',
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

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isLoading = true;
      _status = 'Deleting $accountName...';
    });

    try {
      await StaffMigrationService.deleteStaffAccount(accountId);
      setState(() {
        _status = 'Deleted $accountName successfully.';
      });
      await _loadStaffAccounts();
    } catch (e) {
      setState(() {
        _status = 'Failed to delete $accountName: $e';
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
      appBar: AppBar(
        title: const Text('Staff Migration'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Staff Account Migration',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This will add authentication PINs to existing staff members in the staff collection. Each staff member will get a default PIN based on their phone number.',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: _isLoading ? null : _runMigration,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Run Migration'),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: _loadStaffAccounts,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          child: const Text('Refresh'),
                        ),
                      ],
                    ),
                    if (_status.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _status.contains('Error') ||
                                  _status.contains('failed')
                              ? Colors.red[50]
                              : Colors.green[50],
                          border: Border.all(
                            color: _status.contains('Error') ||
                                    _status.contains('failed')
                                ? Colors.red
                                : Colors.green,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _status,
                          style: TextStyle(
                            color: _status.contains('Error') ||
                                    _status.contains('failed')
                                ? Colors.red[700]
                                : Colors.green[700],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Staff Accounts (${_staffAccounts.length})',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _staffAccounts.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No staff accounts found',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Run migration to create staff accounts',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _staffAccounts.length,
                      itemBuilder: (context, index) {
                        final account = _staffAccounts[index];
                        final hasPin =
                            (account['pin'] ?? '').toString().trim().isNotEmpty;
                        final hasPhone =
                            AustralianPhoneNumber.normalizeToStorageFormat(
                                  (account['phone'] ??
                                          account['phoneNumber'] ??
                                          '')
                                      .toString(),
                                ) !=
                                null;
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: Colors.blue,
                                      child: Text(
                                        account['name']
                                                ?.substring(0, 1)
                                                .toUpperCase() ??
                                            'S',
                                        style: const TextStyle(
                                            color: Colors.white),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            account['name'] ?? 'Unknown',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Phone: ${AustralianPhoneNumber.formatForDisplay((account['phone'] ?? account['phoneNumber'])?.toString(), emptyFallback: 'N/A')}',
                                          ),
                                          Text(
                                              'Role: ${account['role'] ?? 'N/A'}'),
                                          Text(
                                            'Department: ${account['department'] ?? 'N/A'}',
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            hasPin
                                                ? 'PIN configured'
                                                : 'No PIN configured',
                                            style: TextStyle(
                                              color: hasPin
                                                  ? Colors.green[700]
                                                  : Colors.orange[800],
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if (!hasPhone)
                                            Text(
                                              'Add a valid Australian phone number before setting a PIN.',
                                              style: TextStyle(
                                                color: Colors.red.shade700,
                                                fontSize: 12,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: account['isActive'] == true
                                            ? Colors.green[100]
                                            : Colors.red[100],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        account['isActive'] == true
                                            ? 'Active'
                                            : 'Inactive',
                                        style: TextStyle(
                                          color: account['isActive'] == true
                                              ? Colors.green[700]
                                              : Colors.red[700],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: [
                                      TextButton.icon(
                                        onPressed: _isLoading
                                            ? null
                                            : () => _deleteAccount(account),
                                        icon: const Icon(Icons.delete_outline),
                                        label: const Text('Delete Account'),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.red.shade700,
                                        ),
                                      ),
                                      if (hasPin)
                                        OutlinedButton.icon(
                                          onPressed: !_isLoading && hasPhone
                                              ? () => _showPinDialog(account)
                                              : null,
                                          icon: const Icon(Icons.lock_reset),
                                          label: const Text('Reset PIN'),
                                        )
                                      else
                                        ElevatedButton.icon(
                                          onPressed: !_isLoading && hasPhone
                                              ? () => _showPinDialog(account)
                                              : null,
                                          icon: const Icon(Icons.lock_outline),
                                          label: const Text('Set PIN'),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
