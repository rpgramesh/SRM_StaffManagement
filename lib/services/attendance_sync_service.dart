import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/attendance.dart';
import '../models/sync_report.dart';
import 'auth_service.dart';

/// Comprehensive attendance data synchronization service
/// Handles synchronization between primary and legacy attendance collections
/// with conflict resolution, validation, and audit logging
class AttendanceSyncService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Collection names
  static const String _primaryCollection = 'staff_attendance';
  static const String _legacyCollection = 'attendance';
  static const String _syncLogsCollection = 'sync_logs';
  static const String _syncReportsCollection = 'sync_reports';
  
  /// Performs comprehensive synchronization between all attendance data sources
  static Future<SyncReport> synchronizeAttendanceData({
    DateTime? startDate,
    DateTime? endDate,
    List<String>? staffIds,
    bool dryRun = false,
  }) async {
    final syncId = _generateSyncId();
    final startTime = DateTime.now();
    
    try {
      // Validate permissions
      final hasPermission = await _validateSyncPermissions();
      if (!hasPermission) {
        throw Exception('Insufficient permissions to perform synchronization');
      }
      
      // Initialize sync report
      final report = SyncReport(
        id: syncId,
        startTime: startTime,
        status: SyncStatus.inProgress,
        dryRun: dryRun,
      );
      
      // Log sync start
      await _logSyncEvent(syncId, 'sync_started', {
        'startDate': startDate?.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'staffIds': staffIds,
        'dryRun': dryRun,
      });
      
      // Step 1: Identify data sources and fetch records
      final primaryRecords = await _fetchPrimaryRecords(startDate, endDate, staffIds);
      final legacyRecords = await _fetchLegacyRecords(startDate, endDate, staffIds);
      
      report.totalRecordsScanned = primaryRecords.length + legacyRecords.length;
      
      // Step 2: Compare and identify discrepancies
      final comparisonResult = await _compareRecords(primaryRecords, legacyRecords);
      report.conflictsFound = comparisonResult.conflicts;
      report.discrepancies = comparisonResult.discrepancies;
      
      // Step 3: Resolve conflicts and prepare updates
      final resolutionResult = await _resolveConflicts(
        comparisonResult.conflicts,
        dryRun: dryRun,
      );
      report.conflictsResolved = resolutionResult.resolved;
      report.updatesApplied = resolutionResult.updates;
      
      // Step 4: Validate data integrity
      final validationResult = await _validateDataIntegrity(
        primaryRecords,
        legacyRecords,
        resolutionResult.updates,
      );
      report.validationErrors = validationResult.errors;
      report.validationWarnings = validationResult.warnings;
      
      // Step 5: Apply updates (if not dry run)
      if (!dryRun && resolutionResult.updates.isNotEmpty) {
        await _applyUpdates(resolutionResult.updates, syncId);
      }
      
      // Complete sync report
      report.endTime = DateTime.now();
      report.duration = report.endTime!.difference(report.startTime);
      report.status = report.validationErrors.isEmpty 
          ? SyncStatus.completed 
          : SyncStatus.completedWithErrors;
      
      // Save sync report
      await _saveSyncReport(report);
      
      // Log sync completion
      await _logSyncEvent(syncId, 'sync_completed', {
        'status': report.status.toString(),
        'duration': report.duration?.inSeconds ?? 0,
        'recordsProcessed': report.totalRecordsScanned,
        'conflictsResolved': report.conflictsResolved.length,
      });
      
      return report;
      
    } catch (e) {
      // Log sync error
      await _logSyncEvent(syncId, 'sync_error', {
        'error': e.toString(),
        'stackTrace': StackTrace.current.toString(),
      });
      
      return SyncReport(
        id: syncId,
        startTime: startTime,
        endTime: DateTime.now(),
        status: SyncStatus.failed,
        error: e.toString(),
        dryRun: dryRun,
      );
    }
  }
  
  /// Fetches records from primary collection
  static Future<List<Attendance>> _fetchPrimaryRecords(
    DateTime? startDate,
    DateTime? endDate,
    List<String>? staffIds,
  ) async {
    Query query = _firestore.collection(_primaryCollection);
    
    if (staffIds != null && staffIds.isNotEmpty) {
      query = query.where('staffId', whereIn: staffIds);
    }
    
    if (startDate != null) {
      query = query.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }
    
    if (endDate != null) {
      query = query.where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    }
    
    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => Attendance.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }
  
  /// Fetches records from legacy collection
  static Future<List<Attendance>> _fetchLegacyRecords(
    DateTime? startDate,
    DateTime? endDate,
    List<String>? staffIds,
  ) async {
    try {
      Query query = _firestore.collection(_legacyCollection);
      
      if (staffIds != null && staffIds.isNotEmpty) {
        query = query.where('staffId', whereIn: staffIds);
      }
      
      if (startDate != null) {
        query = query.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      
      if (endDate != null) {
        query = query.where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }
      
      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => Attendance.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      // Legacy collection might not exist or be accessible
      debugPrint('Warning: Could not fetch legacy records: $e');
      return [];
    }
  }
  
  /// Compares records between collections and identifies conflicts
  static Future<ComparisonResult> _compareRecords(
    List<Attendance> primaryRecords,
    List<Attendance> legacyRecords,
  ) async {
    final conflicts = <DataConflict>[];
    final discrepancies = <DataDiscrepancy>[];
    
    // Create lookup maps for efficient comparison
    final primaryMap = <String, Attendance>{};
    final legacyMap = <String, Attendance>{};
    
    for (final record in primaryRecords) {
      final key = '${record.staffId}_${_formatDate(record.date)}';
      primaryMap[key] = record;
    }
    
    for (final record in legacyRecords) {
      final key = '${record.staffId}_${_formatDate(record.date)}';
      legacyMap[key] = record;
    }
    
    // Find conflicts and discrepancies
    final allKeys = {...primaryMap.keys, ...legacyMap.keys};
    
    for (final key in allKeys) {
      final primaryRecord = primaryMap[key];
      final legacyRecord = legacyMap[key];
      
      if (primaryRecord != null && legacyRecord != null) {
        // Both records exist - check for conflicts
        final recordConflicts = _compareAttendanceRecords(primaryRecord, legacyRecord);
        if (recordConflicts.isNotEmpty) {
          conflicts.add(DataConflict(
            key: key,
            primaryRecord: primaryRecord,
            legacyRecord: legacyRecord,
            conflicts: recordConflicts,
          ));
        }
      } else if (primaryRecord != null && legacyRecord == null) {
        // Record only in primary
        discrepancies.add(DataDiscrepancy(
          key: key,
          type: DiscrepancyType.missingInLegacy,
          record: primaryRecord,
          description: 'Record exists in primary but missing in legacy collection',
        ));
      } else if (primaryRecord == null && legacyRecord != null) {
        // Record only in legacy
        discrepancies.add(DataDiscrepancy(
          key: key,
          type: DiscrepancyType.missingInPrimary,
          record: legacyRecord,
          description: 'Record exists in legacy but missing in primary collection',
        ));
      }
    }
    
    return ComparisonResult(
      conflicts: conflicts,
      discrepancies: discrepancies,
    );
  }
  
  /// Compares two attendance records and returns list of field conflicts
  static List<FieldConflict> _compareAttendanceRecords(
    Attendance primary,
    Attendance legacy,
  ) {
    final conflicts = <FieldConflict>[];
    
    // Compare check-in times
    if (_timestampsDiffer(primary.checkInTime, legacy.checkInTime)) {
      conflicts.add(FieldConflict(
        field: 'checkInTime',
        primaryValue: primary.checkInTime?.toIso8601String(),
        legacyValue: legacy.checkInTime?.toIso8601String(),
      ));
    }
    
    // Compare check-out times
    if (_timestampsDiffer(primary.checkOutTime, legacy.checkOutTime)) {
      conflicts.add(FieldConflict(
        field: 'checkOutTime',
        primaryValue: primary.checkOutTime?.toIso8601String(),
        legacyValue: legacy.checkOutTime?.toIso8601String(),
      ));
    }
    
    // Compare duration (with tolerance for rounding differences)
    if ((primary.duration - legacy.duration).abs() > 0.02) {
      conflicts.add(FieldConflict(
        field: 'duration',
        primaryValue: primary.duration.toString(),
        legacyValue: legacy.duration.toString(),
      ));
    }
    
    // Compare status
    if (primary.status != legacy.status) {
      conflicts.add(FieldConflict(
        field: 'status',
        primaryValue: primary.status,
        legacyValue: legacy.status,
      ));
    }
    
    // Compare geofence status
    if (primary.isWithinGeofence != legacy.isWithinGeofence) {
      conflicts.add(FieldConflict(
        field: 'isWithinGeofence',
        primaryValue: primary.isWithinGeofence?.toString(),
        legacyValue: legacy.isWithinGeofence?.toString(),
      ));
    }
    
    return conflicts;
  }
  
  /// Resolves conflicts using predefined resolution strategies
  static Future<ResolutionResult> _resolveConflicts(
    List<DataConflict> conflicts, {
    bool dryRun = false,
  }) async {
    final resolved = <ResolvedConflict>[];
    final updates = <DataUpdate>[];
    
    for (final conflict in conflicts) {
      final resolution = await _resolveConflict(conflict);
      resolved.add(resolution);
      
      if (resolution.updateRequired && !dryRun) {
        updates.add(DataUpdate(
          collection: resolution.targetCollection,
          documentId: resolution.targetDocumentId,
          updates: resolution.resolvedValues,
          reason: resolution.resolutionReason,
        ));
      }
    }
    
    return ResolutionResult(
      resolved: resolved,
      updates: updates,
    );
  }
  
  /// Resolves a single conflict using business rules
  static Future<ResolvedConflict> _resolveConflict(DataConflict conflict) async {
    final resolvedValues = <String, dynamic>{};
    final reasons = <String>[];
    
    // Resolution strategy: Primary collection takes precedence for most fields
    // but use most recent timestamp for time-sensitive data
    
    for (final fieldConflict in conflict.conflicts) {
      switch (fieldConflict.field) {
        case 'checkInTime':
        case 'checkOutTime':
          // Use the earlier check-in time or later check-out time (more conservative)
          final primaryTime = fieldConflict.field == 'checkInTime' 
              ? conflict.primaryRecord.checkInTime
              : conflict.primaryRecord.checkOutTime;
          final legacyTime = fieldConflict.field == 'checkInTime'
              ? conflict.legacyRecord.checkInTime
              : conflict.legacyRecord.checkOutTime;
          
          if (primaryTime != null && legacyTime != null) {
            final useEarlier = fieldConflict.field == 'checkInTime';
            final selectedTime = useEarlier
                ? (primaryTime.isBefore(legacyTime) ? primaryTime : legacyTime)
                : (primaryTime.isAfter(legacyTime) ? primaryTime : legacyTime);
            
            resolvedValues[fieldConflict.field] = Timestamp.fromDate(selectedTime);
            reasons.add('${fieldConflict.field}: Used ${useEarlier ? "earlier" : "later"} timestamp');
          }
          break;
          
        case 'duration':
          // Recalculate duration based on resolved timestamps
          final checkIn = resolvedValues['checkInTime'] as Timestamp?;
          final checkOut = resolvedValues['checkOutTime'] as Timestamp?;
          
          if (checkIn != null && checkOut != null) {
            final duration = checkOut.toDate().difference(checkIn.toDate()).inMinutes / 60.0;
            resolvedValues['duration'] = duration;
            reasons.add('duration: Recalculated from resolved timestamps');
          } else {
            // Use primary collection value as fallback
            resolvedValues['duration'] = conflict.primaryRecord.duration;
            reasons.add('duration: Used primary collection value');
          }
          break;
          
        case 'status':
          // Use primary collection status (current system)
          resolvedValues['status'] = conflict.primaryRecord.status;
          reasons.add('status: Used primary collection value');
          break;
          
        case 'isWithinGeofence':
          // Use primary collection geofence status
          resolvedValues['isWithinGeofence'] = conflict.primaryRecord.isWithinGeofence;
          reasons.add('isWithinGeofence: Used primary collection value');
          break;
          
        default:
          // Default to primary collection value
          resolvedValues[fieldConflict.field] = fieldConflict.primaryValue;
          reasons.add('${fieldConflict.field}: Used primary collection value (default)');
      }
    }
    
    return ResolvedConflict(
      conflictKey: conflict.key,
      targetCollection: _primaryCollection,
      targetDocumentId: conflict.primaryRecord.id,
      resolvedValues: resolvedValues,
      resolutionReason: reasons.join('; '),
      updateRequired: resolvedValues.isNotEmpty,
    );
  }
  
  /// Validates data integrity after synchronization
  static Future<ValidationResult> _validateDataIntegrity(
    List<Attendance> primaryRecords,
    List<Attendance> legacyRecords,
    List<DataUpdate> updates,
  ) async {
    final errors = <ValidationError>[];
    final warnings = <ValidationWarning>[];
    
    // Validate timestamp consistency
    for (final record in primaryRecords) {
      if (record.checkInTime != null && record.checkOutTime != null) {
        if (record.checkOutTime!.isBefore(record.checkInTime!)) {
          errors.add(ValidationError(
            recordId: record.id,
            field: 'timestamps',
            message: 'Check-out time is before check-in time',
          ));
        }
        
        // Validate duration calculation
        final calculatedDuration = record.checkOutTime!
            .difference(record.checkInTime!)
            .inMinutes / 60.0;
        
        if ((calculatedDuration - record.duration).abs() > 0.02) {
          warnings.add(ValidationWarning(
            recordId: record.id,
            field: 'duration',
            message: 'Duration mismatch: calculated=$calculatedDuration, stored=${record.duration}',
          ));
        }
      }
    }
    
    return ValidationResult(
      errors: errors,
      warnings: warnings,
    );
  }
  
  /// Applies updates to the database
  static Future<void> _applyUpdates(List<DataUpdate> updates, String syncId) async {
    final batch = _firestore.batch();
    
    for (final update in updates) {
      final docRef = _firestore.collection(update.collection).doc(update.documentId);
      
      // Add audit information
      final auditData = {
        ...update.updates,
        'lastSyncId': syncId,
        'lastSyncTime': Timestamp.now(),
        'syncReason': update.reason,
      };
      
      batch.update(docRef, auditData);
    }
    
    await batch.commit();
  }
  
  /// Validates user permissions for synchronization
  static Future<bool> _validateSyncPermissions() async {
    try {
      final role = await AuthService().getCurrentUserRole();
      return role == 'admin' || role == 'manager';
    } catch (e) {
      return false;
    }
  }
  
  /// Logs synchronization events for audit trail
  static Future<void> _logSyncEvent(
    String syncId,
    String eventType,
    Map<String, dynamic> data,
  ) async {
    try {
      final user = AuthService.getCurrentUser();
      await _firestore.collection(_syncLogsCollection).add({
        'syncId': syncId,
        'eventType': eventType,
        'timestamp': Timestamp.now(),
        'userId': user?.uid,
        'userEmail': user?.email,
        'data': data,
      });
    } catch (e) {
      debugPrint('Warning: Failed to log sync event: $e');
    }
  }
  
  /// Saves synchronization report
  static Future<void> _saveSyncReport(SyncReport report) async {
    try {
      await _firestore.collection(_syncReportsCollection).doc(report.id).set(report.toMap());
    } catch (e) {
      debugPrint('Warning: Failed to save sync report: $e');
    }
  }
  
  /// Retrieves synchronization reports
  static Future<List<SyncReport>> getSyncReports({int limit = 20}) async {
    try {
      final snapshot = await _firestore
          .collection(_syncReportsCollection)
          .orderBy('startTime', descending: true)
          .limit(limit)
          .get();
      
      return snapshot.docs
          .map((doc) => SyncReport.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('Error fetching sync reports: $e');
      return [];
    }
  }
  
  /// Helper methods
  static String _generateSyncId() {
    return 'sync_${DateTime.now().millisecondsSinceEpoch}';
  }
  
  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
  
  static bool _timestampsDiffer(DateTime? a, DateTime? b) {
    if (a == null && b == null) return false;
    if (a == null || b == null) return true;
    return a.difference(b).abs().inSeconds > 1; // 1-second tolerance
  }
}