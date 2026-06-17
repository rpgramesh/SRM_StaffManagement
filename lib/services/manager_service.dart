import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ManagerService {  
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ==================== RESTAURANT MANAGEMENT ====================

  /// Get all restaurants in the system
  Stream<List<Map<String, dynamic>>> getRestaurants() {
    return _db.collection('restaurants').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => {'id': doc.id, ...doc.data() ?? {}}).toList());
  }

  /// Get restaurant details
  Future<Map<String, dynamic>?> getRestaurantDetails(String restaurantId) async {
    final doc = await _db.collection('restaurants').doc(restaurantId).get();
    return doc.exists ? {'id': doc.id, ...doc.data() ?? {}} : null;
  }

  /// Update restaurant status (active/inactive)
  Future<void> updateRestaurantStatus(String restaurantId, bool isActive) async {
    await _db.collection('restaurants').doc(restaurantId).update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Add new restaurant
  Future<void> addRestaurant(Map<String, dynamic> restaurantData) async {
    await _db.collection('restaurants').add({
      ...restaurantData,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Update restaurant details
  Future<void> updateRestaurant(String restaurantId, Map<String, dynamic> restaurantData) async {
    await _db.collection('restaurants').doc(restaurantId).update({
      ...restaurantData,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ==================== DASHER MANAGEMENT ====================

  /// Get all dashers (delivery drivers)
  Stream<List<Map<String, dynamic>>> getDashers() {
    return _db.collection('dashers').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  /// Get dasher details
  Future<Map<String, dynamic>?> getDasherDetails(String dasherId) async {
    final doc = await _db.collection('dashers').doc(dasherId).get();
    return doc.exists ? {'id': doc.id, ...doc.data()!} : null;
  }

  /// Update dasher online status
  Future<void> updateDasherStatus(String dasherId, bool isOnline) async {
    await _db.collection('dashers').doc(dasherId).update({
      'isOnline': isOnline,
      'lastOnline': FieldValue.serverTimestamp(),
    });
  }

  /// Update dasher availability
  Future<void> updateDasherAvailability(String dasherId, bool available) async {
    await _db.collection('dashers').doc(dasherId).update({
      'isAvailable': available,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ==================== MANAGEMENT DASHBOARD ====================

  /// Get overall dashboard statistics
  Stream<Map<String, dynamic>> getDashboardStats() async* {
    yield* _db
        .collection('analytics')
        .doc('dashboard')
        .snapshots()
        .asyncMap((doc) async => doc.exists ? doc.data()! : await _initializeDashboardStats());
  }

  /// Get real-time active restaurants count
  Stream<int> getActiveRestaurantsCount() {
    return _db
        .collection('restaurants')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Get real-time active dashers count
  Stream<int> getActiveDashersCount() {
    return _db
        .collection('dashers')
        .where('isOnline', isEqualTo: true)
        .where('isAvailable', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Get active restaurants list
  Stream<List<Map<String, dynamic>>> getActiveRestaurants() {
    return _db
        .collection('restaurants')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => {'id': doc.id, ...doc.data() ?? {}}).toList());
  }

  /// Get active dashers list
  Stream<List<Map<String, dynamic>>> getActiveDashers() {
    return _db
        .collection('dashers')
        .where('isOnline', isEqualTo: true)
        .where('isAvailable', isEqualTo: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => {'id': doc.id, ...doc.data() ?? {}}).toList());
  }

  /// Get real-time total orders count
  Stream<int> getTotalOrdersCount() {
    return _db
        .collection('orders')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Get real-time total revenue
  Stream<double> getTotalRevenue() {
    return _db
        .collection('orders')
        .where('status', isEqualTo: 'delivered')
        .snapshots()
        .map((snapshot) => 
            snapshot.docs.fold(0.0, (sum, doc) => 
                sum + ((doc.data()['totalAmount'] as num?)?.toDouble() ?? 0.0)));
  }

  /// Get comprehensive real-time dashboard data
  Stream<Map<String, dynamic>> getRealTimeDashboardData() {
    return _db
        .collection('orders')
        .snapshots()
        .asyncMap((ordersSnapshot) async {
      
      // Calculate total orders and revenue
      int totalOrders = ordersSnapshot.docs.length;
      double totalRevenue = ordersSnapshot.docs.fold(0.0, (sum, doc) {
        final data = doc.data();
        if (data['status'] == 'delivered') {
          return sum + ((data['totalAmount'] as num?)?.toDouble() ?? 0.0);
        }
        return sum;
      });

      // Get active restaurants
      final activeRestaurantsSnapshot = await _db
          .collection('restaurants')
          .where('isActive', isEqualTo: true)
          .get();
      int activeRestaurants = activeRestaurantsSnapshot.docs.length;

      // Get active dashers
      final activeDashersSnapshot = await _db
          .collection('dashers')
          .where('isOnline', isEqualTo: true)
          .where('isAvailable', isEqualTo: true)
          .get();
      int activeDashers = activeDashersSnapshot.docs.length;

      return {
        'activeRestaurants': activeRestaurants,
        'activeDashers': activeDashers,
        'totalOrders': totalOrders,
        'totalRevenue': totalRevenue,
        'lastUpdated': DateTime.now(),
      };
    });
  }

  /// Get today's specific orders and revenue data
  Stream<Map<String, dynamic>> getTodayDashboardData() {
    return _db.collection('orders').snapshots().asyncMap((snapshot) async {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      // Get today's orders
      final todayOrdersSnapshot = await _db
          .collection('orders')
          .where('createdAt', isGreaterThanOrEqualTo: startOfDay)
          .where('createdAt', isLessThanOrEqualTo: endOfDay)
          .get();

      final todayOrders = todayOrdersSnapshot.docs.length;
      final todayRevenue = todayOrdersSnapshot.docs.fold(0.0, (sum, doc) {
        final orderData = doc.data();
        return sum + (orderData['totalAmount'] as double? ?? 0.0);
      });

      // Get today's completed orders
      final completedToday = todayOrdersSnapshot.docs.where((doc) {
        final data = doc.data();
        return data['status'] == 'delivered';
      }).length;

      // Get active restaurants today
      final activeRestaurantsSnapshot = await _db
          .collection('restaurants')
          .where('isActive', isEqualTo: true)
          .get();
      int activeRestaurants = activeRestaurantsSnapshot.docs.length;

      // Get active dashers today
      final activeDashersSnapshot = await _db
          .collection('dashers')
          .where('isOnline', isEqualTo: true)
          .where('isAvailable', isEqualTo: true)
          .get();
      int activeDashers = activeDashersSnapshot.docs.length;

      return {
        'todayOrders': todayOrders,
        'todayRevenue': todayRevenue,
        'completedToday': completedToday,
        'activeRestaurants': activeRestaurants,
        'activeDashers': activeDashers,
        'lastUpdated': DateTime.now(),
      };
    });
  }

  Future<Map<String, dynamic>> _initializeDashboardStats() async {
    final today = DateTime.now();
    final weekAgo = today.subtract(const Duration(days: 7));

    final ordersSnapshot = await _db
        .collection('orders')
        .where('createdAt', isGreaterThanOrEqualTo: weekAgo)
        .get();

    final stats = {
      'totalOrders': ordersSnapshot.docs.length,
      'totalRevenue': ordersSnapshot.docs.fold(0.0, (sum, doc) {
        final orderData = doc.data();
        return sum + (orderData['totalAmount'] as double? ?? 0.0);
      }),
      'activeUsers': 0, // Will be calculated from user sessions
      'completedOrders': ordersSnapshot.docs.where((doc) {
        final data = doc.data();
        return data['status'] == 'delivered';
      }).length,
    };
    await _db.collection('analytics').doc('dashboard').set(stats);
    return stats;
  }

  // Helper method to get orders snapshot
  Future<QuerySnapshot> _getOrdersSnapshot() async {
    return await _db.collection('orders').get();
  }

  /// Add a new dasher to the system
  Future<void> addDasher(Map<String, dynamic> dasherData) async {
    await _db.collection('dashers').add({
      ...dasherData,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Update dasher information
  Future<void> updateDasher(String dasherId, Map<String, dynamic> dasherData) async {
    await _db.collection('dashers').doc(dasherId).update({
      ...dasherData,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ==================== ANALYTICS ====================

  /// Get restaurant performance metrics
  Stream<Map<String, dynamic>> getRestaurantAnalytics(String restaurantId) {
    return _db
        .collection('restaurants')
        .doc(restaurantId)
        .snapshots()
        .map((doc) => doc.exists ? {'id': restaurantId, ...doc.data() ?? <String, dynamic>{}} : <String, dynamic>{});
  }

  /// Get dasher performance metrics
  Stream<Map<String, dynamic>> getDasherAnalytics(String dasherId) {
    return _db
        .collection('analytics')
        .doc('dashers')
        .collection(dasherId)
        .doc('performance')
        .snapshots()
        .map((doc) => doc.exists ? doc.data()! : <String, dynamic>{});
  }

  /// Get daily sales report
  Stream<List<Map<String, dynamic>>> getDailySales(DateTime startDate, DateTime endDate) {
    return _db
        .collection('orders')
        .where('orderTime', isGreaterThanOrEqualTo: startDate)
        .where('orderTime', isLessThanOrEqualTo: endDate)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  // ==================== ORDER MANAGEMENT ====================

  /// Get all orders with filtering capabilities
  Stream<List<Map<String, dynamic>>> getOrders(
      {DateTime? startDate,
      DateTime? endDate,
      String? restaurantId,
      String? status}) {
    Query query = _db.collection('orders');

    if (startDate != null) {
      query = query.where('orderTime', isGreaterThanOrEqualTo: startDate);
    }
    if (endDate != null) {
      query = query.where('orderTime', isLessThanOrEqualTo: endDate);
    }
    if (restaurantId != null && restaurantId.isNotEmpty) {
      query = query.where('restaurantId', isEqualTo: restaurantId);
    }
    if (status != null && status != 'all') {
      query = query.where('status', isEqualTo: status);
    }

    return query.snapshots().map((snapshot) {
      final orders = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>?;
        return <String, dynamic>{'id': doc.id, ...?data};
      }).toList();
      
      // Sort by orderTime in descending order (most recent first)
      orders.sort((a, b) {
        final aTime = a['orderTime'] as Timestamp?;
        final bTime = b['orderTime'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });
      
      return orders;
    });
  }

  /// Update order status
  Future<void> updateOrderStatus(String orderId, String status) async {
    await _db.collection('orders').doc(orderId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Log manager action
    await _logManagerAction('update_order_status', {
      'orderId': orderId,
      'newStatus': status,
      'managerId': _auth.currentUser?.uid,
    });
  }

  // ==================== MANAGER AUTHENTICATION ====================

  /// Check if user has manager permissions
  Future<bool> hasManagerAccess() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final managerDoc = await _db.collection('managers').doc(user.uid).get();
    return managerDoc.exists && managerDoc.data()?['isActive'] == true;
  }

  /// Create new manager account
  Future<String> createManagerAccount({
    required String email,
    required String name,
    required String role,
    required bool hasFullAccess,
    List<String>? allowedRestaurants,
  }) async {
    final existingUser = await _db
        .collection('managers')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (existingUser.docs.isNotEmpty) {
      throw Exception('Manager with this email already exists');
    }

    final docRef = await _db.collection('managers').add({
      'email': email,
      'name': name,
      'role': role,
      'hasFullAccess': hasFullAccess,
      'allowedRestaurants': allowedRestaurants ?? [],
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  // ==================== MANAGER LOGGING ====================

  Future<void> _logManagerAction(String actionType, Map<String, dynamic> data) async {
    await _db.collection('manager_logs').add({
      'managerId': _auth.currentUser?.uid,
      'actionType': actionType,
      'data': data,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
    // ==================== SETTINGS & CONFIG

  /// Get today's specific orders and revenue data
  Stream<Map<String, dynamic>> getTodayDashboardData() {
    return FirebaseFirestore.instance.collection('orders').snapshots().asyncMap((snapshot) async {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

      // Get today's orders
      final todayOrdersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('orderTime', isGreaterThanOrEqualTo: startOfDay)
          .where('orderTime', isLessThanOrEqualTo: endOfDay)
          .get();

      final todayOrders = todayOrdersSnapshot.docs.length;
      final todayRevenue = todayOrdersSnapshot.docs.fold(0.0, (sum, doc) {
        final orderData = doc.data();
        return sum + (orderData['totalAmount'] as double? ?? 0.0);
      });

      // Get today's completed orders
      final completedToday = todayOrdersSnapshot.docs.where((doc) {
        final data = doc.data();
        return data['status'] == 'delivered';
      }).length;

      // Get active restaurants today
      final activeRestaurantsSnapshot = await FirebaseFirestore.instance
          .collection('restaurants')
          .where('isActive', isEqualTo: true)
          .get();
      int activeRestaurants = activeRestaurantsSnapshot.docs.length;

      // Get active dashers today
      final activeDashersSnapshot = await FirebaseFirestore.instance
          .collection('dashers')
          .where('isOnline', isEqualTo: true)
          .where('isAvailable', isEqualTo: true)
          .get();
      int activeDashers = activeDashersSnapshot.docs.length;

      return {
        'todayOrders': todayOrders,
        'todayRevenue': todayRevenue,
        'completedToday': completedToday,
        'activeRestaurants': activeRestaurants,
        'activeDashers': activeDashers,
        'lastUpdated': DateTime.now(),
      };
    });
  }