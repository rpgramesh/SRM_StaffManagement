import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order.dart' as restaurant_app;
import '../models/delivery_route.dart';
import '../models/notification.dart';
import '../config/app_config.dart';

class NotificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  // Singleton pattern
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();
  
  // Stream controllers for real-time notifications
  final Map<String, StreamSubscription> _subscriptions = {};
  
  // Initialize notification service
  Future<void> initialize() async {
    if (AppConfig.enableInAppNotifications) {
      await _setupOrderNotifications();
      await _setupDeliveryNotifications();
      // case DeliveryStatus.cancelled:;
      //   _notifyCustomer('Delivery cancelled', 'Your delivery has been cancelled');
      //   _notifyRestaurant('Delivery cancelled', 'Order #${route.orderId.substring(0, 8)} delivery was cancelled');
      //   break;
    }
  }
  
  // Setup order status change notifications
  Future<void> _setupOrderNotifications() async {
    final subscription = _db.collection('orders')
        .snapshots()
        .listen((snapshot) {
      for (var docChange in snapshot.docChanges) {
        if (docChange.type == DocumentChangeType.modified) {
          final order = restaurant_app.Order.fromFirestore(docChange.doc);
          _handleOrderStatusChange(order);
        }
      }
    });
    _subscriptions['orders'] = subscription;
  }
  
  // Setup delivery route change notifications
  Future<void> _setupDeliveryNotifications() async {
    final subscription = _db.collection('deliveryRoutes')
        .snapshots()
        .listen((snapshot) {
      for (var docChange in snapshot.docChanges) {
        if (docChange.type == DocumentChangeType.modified) {
          final route = DeliveryRoute.fromFirestore(docChange.doc);
          _handleDeliveryStatusChange(route);
        }
      }
    });
    _subscriptions['deliveryRoutes'] = subscription;
  }
  
  // Handle order status changes and notify relevant apps
  void _handleOrderStatusChange(restaurant_app.Order order) {
    switch (order.status) {
      case restaurant_app.OrderStatus.pending:
        _notifyRestaurant('New order received', 'Order #${order.id.substring(0, 8)} needs preparation');
        break;
      case restaurant_app.OrderStatus.confirmed:
        _notifyRestaurant('Order confirmed', 'Order #${order.id.substring(0, 8)} order confirmed');
        _notifyCustomer('Order confirmed', 'Your order has been confirmed');
        break;
      case restaurant_app.OrderStatus.preparing:
        _notifyCustomer('Order in preparation', 'Your order is being prepared');
        break;
      case restaurant_app.OrderStatus.readyForPickup:
        _notifyDasher('Pickup ready', 'Order #${order.id.substring(0, 8)} ready for pickup');
        _notifyCustomer('Order ready', 'Your order is ready for delivery');
        break;
      case restaurant_app.OrderStatus.outForDelivery:
        _notifyCustomer('Out for delivery', 'Your order is on the way');
        break;
      case restaurant_app.OrderStatus.delivered:
        _notifyCustomer('Order delivered', 'Your order has been delivered');
        _notifyRestaurant('Order completed', 'Order #${order.id.substring(0, 8)} has been delivered');
        break;
      case restaurant_app.OrderStatus.cancelled:
        _notifyCustomer('Order cancelled', 'Your order has been cancelled');
        _notifyRestaurant('Order cancelled', 'Order #${order.id.substring(0, 8)} was cancelled');
        break;
    }
  }
  
  // Handle delivery status changes
  void _handleDeliveryStatusChange(DeliveryRoute route) {
    switch (route.status) {
      case DeliveryStatus.cancelled:
        _notifyCustomer('Delivery cancelled', 'Your delivery has been cancelled');
        _notifyRestaurant('Delivery cancelled', 'Order #${route.orderId.substring(0, 8)} delivery was cancelled');
        break;
      case DeliveryStatus.assigned:
        _notifyDasher('New delivery assigned', 'You have a new delivery to pickup');
        break;
      case DeliveryStatus.pickedUp:
        _notifyCustomer('Order picked up', 'Your order has been picked up and is on the way');
        _notifyRestaurant('Order picked up', 'Order #${route.orderId.substring(0, 8)} picked up by dasher');
        break;
      case DeliveryStatus.inTransit:
        _notifyCustomer('Order in transit', 'Your order is being delivered');
        break;
      case DeliveryStatus.delivered:
        _notifyCustomer('Order delivered', 'Your order has arrived!');
        _notifyRestaurant('Delivery completed', 'Order #${route.orderId.substring(0, 8)} delivered successfully');
        break;
    }
  }
  
  // Notify customer app
  void _notifyCustomer(String title, String message) {
    _showInAppNotification(title, message, NotificationType.customer);
  }
  
  // Notify restaurant app
  void _notifyRestaurant(String title, String message) {
    _showInAppNotification(title, message, NotificationType.restaurant);
  }
  
  // Notify dasher app
  void _notifyDasher(String title, String message) {
    _showInAppNotification(title, message, NotificationType.dasher);
  }
  
  // Show in-app notification
  void _showInAppNotification(String title, String message, NotificationType type) {
    // In a real implementation, you would use a notification package
    // For this demo, we'll use print statements
    debugPrint('[$type] $title: $message');
    
    // You can also use OverlayEntry or a state management solution
    // to show notifications in the UI
  }
  
  // Manual notification methods for specific events
  Future<void> notifyOrderPlaced(restaurant_app.Order order) async {
    await _createNotificationRecord(
      type: NotificationType.restaurant,
      title: 'New Order Received',
      message: 'Order #${order.id.substring(0, 8)} from ${order.customerName}',
      orderId: order.id,
    );
  }
  
  Future<void> notifyDasherAssigned(DeliveryRoute route) async {
    await _createNotificationRecord(
      type: NotificationType.dasher,
      title: 'Delivery Assigned',
      message: 'New delivery route assigned',
      orderId: route.orderId,
      routeId: route.id,
    );
  }
  
  // Create notification record in Firestore
  Future<void> _createNotificationRecord({
    required NotificationType type,
    required String title,
    required String message,
    String? orderId,
    String? routeId,
  }) async {
    await _db.collection('notifications').add({
      'type': type.toString(),
      'title': title,
      'message': message,
      'orderId': orderId,
      'routeId': routeId,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    });
  }
  
  // Get notifications for a specific type
  Stream<List<Map<String, dynamic>>> getNotifications(NotificationType type) {
    return _db.collection('notifications')
        .where('type', isEqualTo: type.toString())
        .snapshots()
        .map((snapshot) {
          final notifications = snapshot.docs.map((doc) => {
                'id': doc.id,
                ...doc.data(),
              }).toList();
          
          // Sort by timestamp in descending order (most recent first)
          notifications.sort((a, b) {
            final aTime = a['timestamp'] as Timestamp?;
            final bTime = b['timestamp'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime);
          });
          
          // Apply limit after sorting
          return notifications.take(50).toList();
        });
  }
  
  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    await _db.collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }
  
  // Cleanup
  void dispose() {
    for (var subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }
}