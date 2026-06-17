# Kitchen ⇄ Dasher Integration

## 1. Firestore Schema Extensions

### New Collections (`order_status_events`)
```
order_status_events/
  └── {event_id}/
      ├─ orderId: string
      ├─ oldStatus: string
      ├─ newStatus: string ("readyForPickup" triggers Dasher push)
      ├─ kitchenId: string
      ├─ kitchenName: string
      ├─ timestamp: timestamp
      ├─ triggeredNotification: boolean (auto-marked by cloud function)
```

## 2. Cloud Functions
Location: `functions/index.js`

### Trigger: Kitchen Order Ready → Dasher
```javascript
exports.notifyDasherOrderReady = functions.firestore
  .document('orders/{orderId}')
  .onUpdate((change, context) => {
    const newData = change.after.data();
    const oldData = change.before.data();
    
    if (oldData.status !== 'readyForPickup' && newData.status === 'readyForPickup') {
      return notifyAssignedDasher(context.params.orderId, newData);
    }
    return null;
  });

function notifyAssignedDasher(orderId, order) {
  // 1. Write order status event
  admin.firestore().collection('order_status_events').add({
    orderId: orderId,
    oldStatus: oldData.status,
    newStatus: 'readyForPickup',
    kitchenId: order.kitchenId,
    kitchenName: order.kitchenName,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    triggeredNotification: true
  });

  // 2. Push to assigned Dasher via FCM topic
  const payload = {
    notification: {
      title: "Order Ready!",
      body: `Order #${orderId.slice(-4)} is ready for pickup from ${order.kitchenName}`,
    },
    data: {
      orderId: orderId,
      customerName: order.customerName,
      customerAddress: order.customerAddress,
      pickupLocation: order.kitchenAddress,
      estimatedReadyTime: order.estimatedReadyTime?.toISOString() || '',
    },
    topic: `dasher_${order.dasherId}` // Only assigned Dasher gets push
  };

  return admin.messaging().send(payload);
}
```

## 3. Dasher App Integration

### FCM Subscription (Dasher App)
```dart
// lib/services/dasher_notification_service.dart
import 'package:firebase_messaging/firebase_messaging.dart';

class DasherNotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> subscribeToOrderNotifications(String dasherId) async {
    await _messaging.subscribeToTopic('dasher_$dasherId');
    
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.data['orderId'] != null) {
        _handleKitchenOrderReady(message.data);
      }
    });
  }

  void _handleKitchenOrderReady(Map<String, dynamic> data) {
    // Show pickup popup / navigation
    final order = OrderReadyForPickup.fromMap(data);
    Get.find<DasherMapController>().addPickupLocation(order);
  }
}
```

## 4. Real-time Flow
1. **Kitchen Marks Ready:** Kitchen app calls `orderService.updateStatus(orderId, 'readyForPickup')`
2. **Firestore Alert:** Cloud function sees status change → pushes FCM
3. **Dasher Device:** Receives push → auto-opens pickup navigation

## 5. Current Files Verified OK
- `customer_order_tracking_screen.dart` displays real-time status via existing `_loadDeliveryRoute()` - no changes needed
- `order_service.dart` already updates order status - only need new event log

## 6. Implementation Checklist
- [ ] Add `order_status_events` Firestore rules
- [ ] Deploy cloud function `notifyDasherOrderReady`
- [ ] Implement Dasher FCM subscription
- [ ] Add `kitchenAddress` field to orders collection
- [ ] Test complete flow: Kitchen ready → Dasher notification → pickup