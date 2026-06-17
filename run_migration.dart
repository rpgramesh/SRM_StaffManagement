import 'package:flutter/material.dart';
import 'lib/services/staff_migration_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('Starting staff migration to add PINs...');
  
  try {
    await StaffMigrationService.migrateStaffToAccounts();
    print('Migration completed successfully!');
  } catch (e) {
    print('Migration failed: $e');
  }
}