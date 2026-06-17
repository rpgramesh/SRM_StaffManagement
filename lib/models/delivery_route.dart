import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

enum DeliveryStatus {
  assigned,
  pickedUp,
  inTransit,
  delivered,
  cancelled,
}

class DeliveryRoute {
  final String id;
  final String orderId;
  final String dasherId;
  final LatLng pickupLocation;
  final LatLng deliveryLocation;
  final DeliveryStatus status;
  final DateTime assignedTime;
  final DateTime? pickedUpTime;
  final DateTime? deliveredTime;

  DeliveryRoute({
    required this.id,
    required this.orderId,
    required this.dasherId,
    required this.pickupLocation,
    required this.deliveryLocation,
    this.status = DeliveryStatus.assigned,
    required this.assignedTime,
    this.pickedUpTime,
    this.deliveredTime,
  });

  factory DeliveryRoute.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return DeliveryRoute(
      id: doc.id,
      orderId: data['orderId'] ?? '',
      dasherId: data['dasherId'] ?? '',
      pickupLocation: LatLng(
        (data['pickupLocation']['latitude'] ?? 0.0).toDouble(),
        (data['pickupLocation']['longitude'] ?? 0.0).toDouble(),
      ),
      deliveryLocation: LatLng(
        (data['deliveryLocation']['latitude'] ?? 0.0).toDouble(),
        (data['deliveryLocation']['longitude'] ?? 0.0).toDouble(),
      ),
      status: DeliveryStatus.values.firstWhere(
          (e) => e.toString().split('.').last == data['status'].toString().split('.').last,
          orElse: () => DeliveryStatus.assigned),
      assignedTime: (data['assignedTime'] as Timestamp).toDate(),
      pickedUpTime: (data['pickedUpTime'] as Timestamp?)?.toDate(),
      deliveredTime: (data['deliveredTime'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'orderId': orderId,
      'dasherId': dasherId,
      'pickupLocation': GeoPoint(pickupLocation.latitude, pickupLocation.longitude),
      'deliveryLocation': GeoPoint(deliveryLocation.latitude, deliveryLocation.longitude),
      'status': status.toString().split('.').last,
      'assignedTime': Timestamp.fromDate(assignedTime),
      'pickedUpTime': pickedUpTime != null ? Timestamp.fromDate(pickedUpTime!) : null,
      'deliveredTime': deliveredTime != null ? Timestamp.fromDate(deliveredTime!) : null,
    };
  }

  DeliveryRoute copyWith({
    String? id,
    String? orderId,
    String? dasherId,
    LatLng? pickupLocation,
    LatLng? deliveryLocation,
    DeliveryStatus? status,
    DateTime? assignedTime,
    DateTime? pickedUpTime,
    DateTime? deliveredTime,
  }) {
    return DeliveryRoute(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      dasherId: dasherId ?? this.dasherId,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      deliveryLocation: deliveryLocation ?? this.deliveryLocation,
      status: status ?? this.status,
      assignedTime: assignedTime ?? this.assignedTime,
      pickedUpTime: pickedUpTime ?? this.pickedUpTime,
      deliveredTime: deliveredTime ?? this.deliveredTime,
    );
  }

  void where(bool Function(dynamic r) param0) {}
}