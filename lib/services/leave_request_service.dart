import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:staff_management_app/models/leave_request.dart';

class LeaveRequestService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collection = 'leaveRequests';

  // Submit a new leave request
  Future<String> submitLeaveRequest(LeaveRequest leaveRequest) async {
    try {
      final docRef = await _db.collection(_collection).add(leaveRequest.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to submit leave request: $e');
    }
  }

  // Get leave request by ID
  Future<LeaveRequest?> getLeaveRequestById(String requestId) async {
    try {
      final doc = await _db.collection(_collection).doc(requestId).get();
      if (doc.exists && doc.data() != null) {
        return LeaveRequest.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get leave request: $e');
    }
  }

  // Get all leave requests for a specific staff member
  Stream<List<LeaveRequest>> getLeaveRequestsForStaff(String staffId) {
    return _db
        .collection(_collection)
        .where('staffId', isEqualTo: staffId)
        .snapshots()
        .map((snapshot) {
          final requests = snapshot.docs
              .map((doc) => LeaveRequest.fromMap(doc.data(), doc.id))
              .toList();
          
          // Sort by createdAt in descending order (most recent first)
          requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          
          return requests;
        });
  }

  // Get leave requests by status for a staff member
  Stream<List<LeaveRequest>> getLeaveRequestsByStatus(
    String staffId,
    LeaveStatus status,
  ) {
    return _db
        .collection(_collection)
        .where('staffId', isEqualTo: staffId)
        .where('status', isEqualTo: status.name)
        .snapshots()
        .map((snapshot) {
          final requests = snapshot.docs
              .map((doc) => LeaveRequest.fromMap(doc.data(), doc.id))
              .toList();
          
          // Sort by createdAt in descending order (most recent first)
          requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          
          return requests;
        });
  }

  // Get pending leave requests (for managers/admins)
  Stream<List<LeaveRequest>> getPendingLeaveRequests() {
    return _db
        .collection(_collection)
        .where('status', isEqualTo: LeaveStatus.pending.name)
        .snapshots()
        .map((snapshot) {
          final requests = snapshot.docs
              .map((doc) => LeaveRequest.fromMap(doc.data(), doc.id))
              .toList();
          
          // Sort by createdAt in ascending order (oldest first)
          requests.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          
          return requests;
        });
  }

  // Get all leave requests for a date range
  Stream<List<LeaveRequest>> getLeaveRequestsByDateRange(
    DateTime startDate,
    DateTime endDate,
    {String? staffId}
  ) {
    Query query = _db.collection(_collection);
    
    if (staffId != null) {
      query = query.where('staffId', isEqualTo: staffId);
    }
    
    return query
        .where('startDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('endDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .snapshots()
        .map((snapshot) {
          final leaveRequests = snapshot.docs
              .map((doc) => LeaveRequest.fromMap(doc.data() as Map<String, dynamic>, doc.id))
              .toList();
          
          // Sort by start date in ascending order
          leaveRequests.sort((a, b) => a.startDate.compareTo(b.startDate));
          
          return leaveRequests;
        });
  }

  // Approve leave request
  Future<void> approveLeaveRequest(
    String requestId,
    String approvedBy,
  ) async {
    try {
      await _db.collection(_collection).doc(requestId).update({
        'status': LeaveStatus.approved.name,
        'approvedBy': approvedBy,
        'approvedAt': Timestamp.fromDate(DateTime.now()),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Failed to approve leave request: $e');
    }
  }

  // Reject leave request
  Future<void> rejectLeaveRequest(
    String requestId,
    String rejectedBy,
    String rejectionReason,
  ) async {
    try {
      await _db.collection(_collection).doc(requestId).update({
        'status': LeaveStatus.rejected.name,
        'approvedBy': rejectedBy,
        'approvedAt': Timestamp.fromDate(DateTime.now()),
        'rejectionReason': rejectionReason,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Failed to reject leave request: $e');
    }
  }

  // Cancel leave request (by staff member)
  Future<void> cancelLeaveRequest(String requestId) async {
    try {
      await _db.collection(_collection).doc(requestId).update({
        'status': LeaveStatus.cancelled.name,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Failed to cancel leave request: $e');
    }
  }

  // Update leave request (only if pending)
  Future<void> updateLeaveRequest(
    String requestId,
    LeaveRequest updatedRequest,
  ) async {
    try {
      // First check if the request is still pending
      final currentRequest = await getLeaveRequestById(requestId);
      if (currentRequest?.status != LeaveStatus.pending) {
        throw Exception('Cannot update leave request that is not pending');
      }

      final updatedData = updatedRequest.copyWith(
        updatedAt: DateTime.now(),
      );
      
      await _db.collection(_collection).doc(requestId).update(updatedData.toMap());
    } catch (e) {
      throw Exception('Failed to update leave request: $e');
    }
  }

  // Check for leave conflicts
  Future<bool> hasLeaveConflict(
    String staffId,
    DateTime startDate,
    DateTime endDate,
    {String? excludeRequestId}
  ) async {
    try {
      Query query = _db
          .collection(_collection)
          .where('staffId', isEqualTo: staffId)
          .where('status', isEqualTo: LeaveStatus.approved.name);

      final snapshot = await query.get();
      
      for (final doc in snapshot.docs) {
        if (excludeRequestId != null && doc.id == excludeRequestId) {
          continue;
        }
        
        final leaveRequest = LeaveRequest.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        
        // Check for date overlap
        if (startDate.isBefore(leaveRequest.endDate.add(const Duration(days: 1))) && 
            endDate.isAfter(leaveRequest.startDate.subtract(const Duration(days: 1)))) {
          return true;
        }
      }
      
      return false;
    } catch (e) {
      throw Exception('Failed to check leave conflict: $e');
    }
  }

  // Get leave balance/statistics for a staff member
  Future<Map<String, dynamic>> getLeaveStats(
    String staffId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final snapshot = await _db
          .collection(_collection)
          .where('staffId', isEqualTo: staffId)
          .where('startDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('endDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      final leaveRequests = snapshot.docs
          .map((doc) => LeaveRequest.fromMap(doc.data(), doc.id))
          .toList();

      int totalRequests = leaveRequests.length;
      int approvedRequests = 0;
      int pendingRequests = 0;
      int rejectedRequests = 0;
      int totalDaysTaken = 0;
      Map<String, int> leaveTypeCounts = {};

      for (final request in leaveRequests) {
        switch (request.status) {
          case LeaveStatus.approved:
            approvedRequests++;
            totalDaysTaken += request.totalDays;
            break;
          case LeaveStatus.pending:
            pendingRequests++;
            break;
          case LeaveStatus.rejected:
            rejectedRequests++;
            break;
          case LeaveStatus.cancelled:
            // Don't count cancelled requests
            break;
        }
        
        final leaveTypeKey = request.leaveType.name;
        leaveTypeCounts[leaveTypeKey] = 
            (leaveTypeCounts[leaveTypeKey] ?? 0) + 1;
      }

      return {
        'totalRequests': totalRequests,
        'approvedRequests': approvedRequests,
        'pendingRequests': pendingRequests,
        'rejectedRequests': rejectedRequests,
        'totalDaysTaken': totalDaysTaken,
        'leaveTypeCounts': leaveTypeCounts,
      };
    } catch (e) {
      throw Exception('Failed to get leave statistics: $e');
    }
  }

  // Get upcoming approved leaves for a staff member
  Stream<List<LeaveRequest>> getUpcomingLeaves(String staffId) {
    final now = DateTime.now();
    
    return _db
        .collection(_collection)
        .where('staffId', isEqualTo: staffId)
        .where('status', isEqualTo: LeaveStatus.approved.name)
        .where('startDate', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
        .snapshots()
        .map((snapshot) {
          final leaves = snapshot.docs
              .map((doc) => LeaveRequest.fromMap(doc.data(), doc.id))
              .toList();
          
          // Sort by startDate in ascending order (earliest first)
          leaves.sort((a, b) => a.startDate.compareTo(b.startDate));
          
          return leaves;
        });
  }

  // Get current active leaves for a staff member
  Stream<List<LeaveRequest>> getCurrentLeaves(String staffId) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    return _db
        .collection(_collection)
        .where('staffId', isEqualTo: staffId)
        .snapshots()
        .map((snapshot) {
          final leaves = snapshot.docs
              .map((doc) => LeaveRequest.fromMap(doc.data(), doc.id))
              .where((leave) => 
                  leave.status == LeaveStatus.approved &&
                  leave.startDate.isBefore(today.add(Duration(days: 1))) &&
                  leave.endDate.isAfter(today.subtract(Duration(days: 1))))
              .toList();
          
          return leaves;
        });
  }
}