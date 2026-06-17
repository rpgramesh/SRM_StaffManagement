import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:staff_management_app/models/delivery_route.dart';
import 'package:staff_management_app/models/dasher.dart';
import 'package:staff_management_app/models/staff.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Delivery Route Operations
  Future<void> addDeliveryRoute(DeliveryRoute route) async {
    await _db.collection('deliveryRoutes').add(route.toFirestore());
  }

  Stream<List<DeliveryRoute>> getDeliveryRoutesStream() {
    return _db.collection('deliveryRoutes').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => DeliveryRoute.fromFirestore(doc)).toList());
  }

  Stream<List<DeliveryRoute>> getDeliveryRoutesByOrderId(String orderId) {
    return _db
        .collection('deliveryRoutes')
        .where('orderId', isEqualTo: orderId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DeliveryRoute.fromFirestore(doc))
            .toList());
  }

  // Staff Operations
  Future<void> addStaff(Staff staff) async {
    await _db.collection('staff').add(staff.toFirestore());
  }

  Stream<List<Staff>> getStaffStream() {
    return _db.collection('staff').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Staff.fromFirestore(doc)).toList());
  }

  // Dasher Operations
  Stream<List<Dasher>> getDashers() {
    return _db.collection('dashers').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Dasher.fromJson(doc.data())).toList());
  }

  Future<void> addDasher(Dasher dasher) async {
    await _db.collection('dashers').add(dasher.toJson());
  }
}
