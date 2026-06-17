import 'package:google_maps_flutter/google_maps_flutter.dart';

class Dasher {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String vehicleType;
  final String vehicleNumber;
  final double rating;
  final bool isAvailable;
  final LatLng? currentLocation;
  final String? currentDeliveryId;
  final DateTime createdAt;
  final DateTime lastActiveAt;
  final int totalDeliveries;
  final double totalEarnings;

  const Dasher({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.vehicleType,
    required this.vehicleNumber,
    required this.rating,
    required this.isAvailable,
    this.currentLocation,
    this.currentDeliveryId,
    required this.createdAt,
    required this.lastActiveAt,
    required this.totalDeliveries,
    required this.totalEarnings,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'vehicleType': vehicleType,
      'vehicleNumber': vehicleNumber,
      'rating': rating,
      'isAvailable': isAvailable,
      'currentLocation': currentLocation != null
          ? {
              'latitude': currentLocation!.latitude,
              'longitude': currentLocation!.longitude,
            }
          : null,
      'currentDeliveryId': currentDeliveryId,
      'createdAt': createdAt.toIso8601String(),
      'lastActiveAt': lastActiveAt.toIso8601String(),
      'totalDeliveries': totalDeliveries,
      'totalEarnings': totalEarnings,
    };
  }

  factory Dasher.fromJson(Map<String, dynamic> json) {
    return Dasher(
      id: json['id'],
      name: json['name'],
      phone: json['phone'],
      email: json['email'],
      vehicleType: json['vehicleType'],
      vehicleNumber: json['vehicleNumber'],
      rating: json['rating']?.toDouble() ?? 0.0,
      isAvailable: json['isAvailable'] ?? false,
      currentLocation: json['currentLocation'] != null
          ? LatLng(
              json['currentLocation']['latitude']?.toDouble() ?? 0.0,
              json['currentLocation']['longitude']?.toDouble() ?? 0.0,
            )
          : null,
      currentDeliveryId: json['currentDeliveryId'],
      createdAt: DateTime.parse(json['createdAt']),
      lastActiveAt: DateTime.parse(json['lastActiveAt']),
      totalDeliveries: json['totalDeliveries'] ?? 0,
      totalEarnings: json['totalEarnings']?.toDouble() ?? 0.0,
    );
  }

  Dasher copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? vehicleType,
    String? vehicleNumber,
    double? rating,
    bool? isAvailable,
    LatLng? currentLocation,
    String? currentDeliveryId,
    DateTime? createdAt,
    DateTime? lastActiveAt,
    int? totalDeliveries,
    double? totalEarnings,
  }) {
    return Dasher(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      vehicleType: vehicleType ?? this.vehicleType,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      rating: rating ?? this.rating,
      isAvailable: isAvailable ?? this.isAvailable,
      currentLocation: currentLocation ?? this.currentLocation,
      currentDeliveryId: currentDeliveryId ?? this.currentDeliveryId,
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      totalDeliveries: totalDeliveries ?? this.totalDeliveries,
      totalEarnings: totalEarnings ?? this.totalEarnings,
    );
  }

  @override
  String toString() {
    return 'Dasher(id: $id, name: $name, rating: $rating, isAvailable: $isAvailable)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Dasher && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}