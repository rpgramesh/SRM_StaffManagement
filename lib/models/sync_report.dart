import 'package:cloud_firestore/cloud_firestore.dart';
import 'attendance.dart';

/// Enumeration for synchronization status
enum SyncStatus {
  inProgress,
  completed,
  completedWithErrors,
  failed,
}

/// Main synchronization report model
class SyncReport {
  final String id;
  final DateTime startTime;
  DateTime? endTime;
  Duration? duration;
  SyncStatus status;
  final bool dryRun;
  String? error;
  int totalRecordsScanned;
  List<DataConflict> conflictsFound;
  List<DataDiscrepancy> discrepancies;
  List<ResolvedConflict> conflictsResolved;
  List<DataUpdate> updatesApplied;
  List<ValidationError> validationErrors;
  List<ValidationWarning> validationWarnings;

  SyncReport({
    required this.id,
    required this.startTime,
    this.endTime,
    this.duration,
    required this.status,
    this.dryRun = false,
    this.error,
    this.totalRecordsScanned = 0,
    List<DataConflict>? conflictsFound,
    List<DataDiscrepancy>? discrepancies,
    List<ResolvedConflict>? conflictsResolved,
    List<DataUpdate>? updatesApplied,
    List<ValidationError>? validationErrors,
    List<ValidationWarning>? validationWarnings,
  }) : conflictsFound = conflictsFound ?? [],
       discrepancies = discrepancies ?? [],
       conflictsResolved = conflictsResolved ?? [],
       updatesApplied = updatesApplied ?? [],
       validationErrors = validationErrors ?? [],
       validationWarnings = validationWarnings ?? [];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'duration': duration?.inSeconds,
      'status': status.toString(),
      'dryRun': dryRun,
      'error': error,
      'totalRecordsScanned': totalRecordsScanned,
      'conflictsFound': conflictsFound.map((c) => c.toMap()).toList(),
      'discrepancies': discrepancies.map((d) => d.toMap()).toList(),
      'conflictsResolved': conflictsResolved.map((r) => r.toMap()).toList(),
      'updatesApplied': updatesApplied.map((u) => u.toMap()).toList(),
      'validationErrors': validationErrors.map((e) => e.toMap()).toList(),
      'validationWarnings': validationWarnings.map((w) => w.toMap()).toList(),
    };
  }

  factory SyncReport.fromMap(Map<String, dynamic> map, String id) {
    return SyncReport(
      id: id,
      startTime: (map['startTime'] as Timestamp).toDate(),
      endTime: map['endTime'] != null ? (map['endTime'] as Timestamp).toDate() : null,
      duration: map['duration'] != null ? Duration(seconds: map['duration']) : null,
      status: SyncStatus.values.firstWhere(
        (s) => s.toString() == map['status'],
        orElse: () => SyncStatus.failed,
      ),
      dryRun: map['dryRun'] ?? false,
      error: map['error'],
      totalRecordsScanned: map['totalRecordsScanned'] ?? 0,
      conflictsFound: (map['conflictsFound'] as List<dynamic>?)
          ?.map((c) => DataConflict.fromMap(c))
          .toList() ?? [],
      discrepancies: (map['discrepancies'] as List<dynamic>?)
          ?.map((d) => DataDiscrepancy.fromMap(d))
          .toList() ?? [],
      conflictsResolved: (map['conflictsResolved'] as List<dynamic>?)
          ?.map((r) => ResolvedConflict.fromMap(r))
          .toList() ?? [],
      updatesApplied: (map['updatesApplied'] as List<dynamic>?)
          ?.map((u) => DataUpdate.fromMap(u))
          .toList() ?? [],
      validationErrors: (map['validationErrors'] as List<dynamic>?)
          ?.map((e) => ValidationError.fromMap(e))
          .toList() ?? [],
      validationWarnings: (map['validationWarnings'] as List<dynamic>?)
          ?.map((w) => ValidationWarning.fromMap(w))
          .toList() ?? [],
    );
  }
}

/// Represents a conflict between two data sources
class DataConflict {
  final String key;
  final Attendance primaryRecord;
  final Attendance legacyRecord;
  final List<FieldConflict> conflicts;

  DataConflict({
    required this.key,
    required this.primaryRecord,
    required this.legacyRecord,
    required this.conflicts,
  });

  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'primaryRecord': primaryRecord.toMap(),
      'legacyRecord': legacyRecord.toMap(),
      'conflicts': conflicts.map((c) => c.toMap()).toList(),
    };
  }

  factory DataConflict.fromMap(Map<String, dynamic> map) {
    return DataConflict(
      key: map['key'],
      primaryRecord: Attendance.fromMap(map['primaryRecord'], map['primaryRecord']['id']),
      legacyRecord: Attendance.fromMap(map['legacyRecord'], map['legacyRecord']['id']),
      conflicts: (map['conflicts'] as List<dynamic>)
          .map((c) => FieldConflict.fromMap(c))
          .toList(),
    );
  }
}

/// Represents a field-level conflict
class FieldConflict {
  final String field;
  final String? primaryValue;
  final String? legacyValue;

  FieldConflict({
    required this.field,
    this.primaryValue,
    this.legacyValue,
  });

  Map<String, dynamic> toMap() {
    return {
      'field': field,
      'primaryValue': primaryValue,
      'legacyValue': legacyValue,
    };
  }

  factory FieldConflict.fromMap(Map<String, dynamic> map) {
    return FieldConflict(
      field: map['field'],
      primaryValue: map['primaryValue'],
      legacyValue: map['legacyValue'],
    );
  }
}

/// Enumeration for discrepancy types
enum DiscrepancyType {
  missingInPrimary,
  missingInLegacy,
  duplicateRecord,
}

/// Represents a data discrepancy
class DataDiscrepancy {
  final String key;
  final DiscrepancyType type;
  final Attendance record;
  final String description;

  DataDiscrepancy({
    required this.key,
    required this.type,
    required this.record,
    required this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'type': type.toString(),
      'record': record.toMap(),
      'description': description,
    };
  }

  factory DataDiscrepancy.fromMap(Map<String, dynamic> map) {
    return DataDiscrepancy(
      key: map['key'],
      type: DiscrepancyType.values.firstWhere(
        (t) => t.toString() == map['type'],
        orElse: () => DiscrepancyType.duplicateRecord,
      ),
      record: Attendance.fromMap(map['record'], map['record']['id']),
      description: map['description'],
    );
  }
}

/// Represents a resolved conflict
class ResolvedConflict {
  final String conflictKey;
  final String targetCollection;
  final String targetDocumentId;
  final Map<String, dynamic> resolvedValues;
  final String resolutionReason;
  final bool updateRequired;

  ResolvedConflict({
    required this.conflictKey,
    required this.targetCollection,
    required this.targetDocumentId,
    required this.resolvedValues,
    required this.resolutionReason,
    required this.updateRequired,
  });

  Map<String, dynamic> toMap() {
    return {
      'conflictKey': conflictKey,
      'targetCollection': targetCollection,
      'targetDocumentId': targetDocumentId,
      'resolvedValues': resolvedValues,
      'resolutionReason': resolutionReason,
      'updateRequired': updateRequired,
    };
  }

  factory ResolvedConflict.fromMap(Map<String, dynamic> map) {
    return ResolvedConflict(
      conflictKey: map['conflictKey'],
      targetCollection: map['targetCollection'],
      targetDocumentId: map['targetDocumentId'],
      resolvedValues: Map<String, dynamic>.from(map['resolvedValues']),
      resolutionReason: map['resolutionReason'],
      updateRequired: map['updateRequired'] ?? false,
    );
  }
}

/// Represents a data update to be applied
class DataUpdate {
  final String collection;
  final String documentId;
  final Map<String, dynamic> updates;
  final String reason;

  DataUpdate({
    required this.collection,
    required this.documentId,
    required this.updates,
    required this.reason,
  });

  Map<String, dynamic> toMap() {
    return {
      'collection': collection,
      'documentId': documentId,
      'updates': updates,
      'reason': reason,
    };
  }

  factory DataUpdate.fromMap(Map<String, dynamic> map) {
    return DataUpdate(
      collection: map['collection'],
      documentId: map['documentId'],
      updates: Map<String, dynamic>.from(map['updates']),
      reason: map['reason'],
    );
  }
}

/// Represents a validation error
class ValidationError {
  final String recordId;
  final String field;
  final String message;

  ValidationError({
    required this.recordId,
    required this.field,
    required this.message,
  });

  Map<String, dynamic> toMap() {
    return {
      'recordId': recordId,
      'field': field,
      'message': message,
    };
  }

  factory ValidationError.fromMap(Map<String, dynamic> map) {
    return ValidationError(
      recordId: map['recordId'],
      field: map['field'],
      message: map['message'],
    );
  }
}

/// Represents a validation warning
class ValidationWarning {
  final String recordId;
  final String field;
  final String message;

  ValidationWarning({
    required this.recordId,
    required this.field,
    required this.message,
  });

  Map<String, dynamic> toMap() {
    return {
      'recordId': recordId,
      'field': field,
      'message': message,
    };
  }

  factory ValidationWarning.fromMap(Map<String, dynamic> map) {
    return ValidationWarning(
      recordId: map['recordId'],
      field: map['field'],
      message: map['message'],
    );
  }
}

/// Result of record comparison
class ComparisonResult {
  final List<DataConflict> conflicts;
  final List<DataDiscrepancy> discrepancies;

  ComparisonResult({
    required this.conflicts,
    required this.discrepancies,
  });
}

/// Result of conflict resolution
class ResolutionResult {
  final List<ResolvedConflict> resolved;
  final List<DataUpdate> updates;

  ResolutionResult({
    required this.resolved,
    required this.updates,
  });
}

/// Result of data validation
class ValidationResult {
  final List<ValidationError> errors;
  final List<ValidationWarning> warnings;

  ValidationResult({
    required this.errors,
    required this.warnings,
  });
}