# Firebase Firestore Collections for Manager App Integration

## Restaurant Management Collection Structure

### restaurants Collection
```javascript
{
  name: "string",
  address: "string",
  phone: "string",
  email: "string",
  cuisine_type: "string",
  opening_hours: {
    monday: { open: "09:00", close: "22:00" },
    tuesday: { open: "09:00", close: "22:00" },
    ...
  },
  isActive: "boolean",
  createdAt: "timestamp",
  updatedAt: "timestamp",
  managerId: "string", // Reference to managers collection
  geoLocation: {
    latitude: "number",
    longitude: "number"
  },
  delivery_radius: "number", // in kilometers
  minimum_order: "number",
  delivery_fee: "number",
  tax_rate: "number",
  payment_methods: ["string"],
  rating: "number",
  total_reviews: "number"
}
```

### dashers Collection
```javascript
{
  name: "string",
  email: "string",
  phone: "string",
  license_number: "string",
  vehicle_type: "string", // bike, car, scooter
  isOnline: "boolean",
  isAvailable: "boolean",
  currentLocation: {
    latitude: "number",
    longitude: "number"
  },
  total_orders: "number",
  completion_rate: "number",
  rating: "number",
  earnings: "number",
  createdAt: "timestamp",
  updatedAt: "timestamp",
  vehicle_details: {
    make: "string",
    model: "string",
    year: "number",
    color: "string",
    license_plate: "string"
  },
  documents: {
    license_image: "string", // URL to storage
    insurance_image: "string",
    vehicle_image: "string"
  },
  background_check_complete: "boolean",
  active_orders: [ "order_id" ],
  assigned_orders: [ "order_id" ]
}
```

### managers Collection
```javascript
{
  email: "string",
  name: "string",
  role: "string", // owner | manager | supervisor
  hasFullAccess: "boolean",
  allowedRestaurants: [ "restaurant_id" ], // Array of restaurant IDs they can access
  isActive: "boolean",
  createdAt: "timestamp",
  updatedAt: "timestamp",
  lastLogin: "timestamp",
  permissions: {
    can_view_analytics: "boolean",
    can_manage_restaurants: "boolean",
    can_manage_dashers: "boolean",
    can_manage_orders: "boolean",
    can_manage_users: "boolean",
    can_update_system_settings: "boolean",
    can_create_reports: "boolean"
  },
  notifications_settings: {
    email_notifications: "boolean",
    push_notifications: "boolean",
    new_order_alerts: "boolean",
    dasher_issues: "boolean",
    restaurant_issues: "boolean"
  }
}
```

### analytics Collection
```javascript
{
  totalRevenue: "number",
  totalOrders: "number",
  activeUsers: "number",
  completedOrders: "number",
  cancelledOrders: "number",
  averageOrderValue: "number",
  topSellingItems: [ { itemId: "string", count: "number" } ],
  restaurantPerformance: {
    [restaurantId]: {
      totalRevenue: "number",
      totalOrders: "number",
      averageRating: "number",
      orderCompletionRate: "number"
    }
  },
  dasherPerformance: {
    [dasherId]: {
      totalDeliveries: "number",
      averageRating: "number",
      completionRate: "number",
      earnings: "number"
    }
  },
  dailyStats: [ {
    date: "date",
    revenue: "number",
    orders: "number",
    newUsers: "number"
  } ],
  lastUpdated: "timestamp"
}
```

### manager_activity_logs Collection
```javascript
{
  managerId: "string",
  actionType: "string", // LOGIN | LOGOUT | ORDER_UPDATE | RESTAURANT_UPDATE | DASHER_UPDATE
  actionDetails: "map",
  ipAddress: "string",
  userAgent: "string",
  timestamp: "timestamp"
}
```

## Security Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Allow public read access to active staff for login
    match /staff/{staffId} {
      allow read: if resource.data.isActive == true;
      allow write: if request.auth != null && 
        (request.auth.uid == staffId || 
         get(/databases/$(database)/documents/staff/$(request.auth.uid)).data.role == 'manager');
      allow create: if request.auth != null && 
        get(/databases/$(database)/documents/staff/$(request.auth.uid)).data.role == 'manager';
    }
    // Managers only
    match /managers/{managerId} {
      allow read: if isManager() && (request.auth.uid == managerId || hasFullAccess());
      allow write: if isManager() && hasFullAccess();
    }
    
    // Restaurants
    match /restaurants/{restaurantId} {
      allow read: if isManager();
      allow write: if isManager() && (hasFullAccess() || canAccessRestaurant(restaurantId));
    }
    
    // Dashers
    match /dashers/{dasherId} {
      allow read: if isManager();
      allow write: if isManager() && (hasFullAccess() || canManageDashers());
    }
    
    // Analytics
    match /analytics/{document=**} {
      allow read: if isManager();
      allow write: if isManager() && hasFullAccess();
    }
    
    // Manager Activity Logs
    match /manager_activity_logs/{logId} {
      allow read: if isManager();
      allow write: if isManager();
    }
    
    // Orders (for viewing)
    match /orders/{orderId} {
      allow read: if isManager();
      allow write: if false; // Manager view only, can't modify orders
    }
    
    // Helper Functions
    function isManager() {
      return request.auth != null && exists(/databases/$(database)/documents/managers/$(request.auth.uid));
    }
    
    function hasFullAccess() {
      return request.auth != null && get(/databases/$(database)/documents/managers/$(request.auth.uid)).data.hasFullAccess == true;
    }
    
    function canAccessRestaurant(restaurantId) {
      return request.auth != null && 
             restaurantId in get(/databases/$(database)/documents/managers/$(request.auth.uid)).data.allowedRestaurants;
    }
    
    function canManageDashers() {
      return request.auth != null && 
             (get(/databases/$(database)/documents/managers/$(request.auth.uid)).data.hasFullAccess == true ||
              get(/databases/$(database)/documents/managers/$(request.auth.uid)).data.permissions.can_manage_dashers == true);
    }
  }
}
```

## Setup Instructions
1. Create collections in Firebase Console
2. Import sample data (optional)
3. Set up security rules
4. Initialize manager accounts
5. Configure app settings
6. Test manager permissions

## Environment Setup
```json
{
  "firestore": {
    "indexes": [
      {
        "collectionGroup": "managers",
        "queryScope": "COLLECTION",
        "fields": [
          {"fieldPath": "isActive", "order": "ASCENDING"},
          {"fieldPath": "role", "order": "ASCENDING"}
        ]
      },
      {
        "collectionGroup": "restaurants",
        "queryScope": "COLLECTION",
        "fields": [
          {"fieldPath": "isActive", "order": "ASCENDING"},
          {"fieldPath": "rating", "order": "DESCENDING"}
        ]
      },
      {
        "collectionGroup": "dashers",
        "queryScope": "COLLECTION",
        "fields": [
          {"fieldPath": "isAvailable", "order": "ASCENDING"},
          {"fieldPath": "isOnline", "order": "ASCENDING"}
        ]
      }
    ]
  }
}
```