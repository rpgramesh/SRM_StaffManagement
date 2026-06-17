# Firebase Collections Setup for Loyalty Points and Promo Codes

This document outlines the Firebase Firestore collections structure for the loyalty points and promo codes system.

## Collections Overview

### 1. loyalty_points
Stores individual loyalty point transactions for users.

**Collection Path:** `/loyalty_points`

**Document Structure:**
```json
{
  "id": "string (auto-generated)",
  "userId": "string (required)",
  "points": "number (required)",
  "type": "string (required) - 'earned' or 'redeemed'",
  "source": "string (required) - 'order', 'reward_redemption', 'bonus', etc.",
  "description": "string (required)",
  "orderId": "string (optional) - reference to order if applicable",
  "rewardId": "string (optional) - reference to reward if redeemed",
  "createdAt": "timestamp (required)",
  "expiresAt": "timestamp (optional) - for points that expire"
}
```

**Indexes:**
- `userId` (ascending)
- `userId, createdAt` (composite, descending on createdAt)
- `userId, type` (composite)
- `expiresAt` (ascending) - for cleanup of expired points

### 2. user_loyalty_data
Stores aggregated loyalty data for each user.

**Collection Path:** `/user_loyalty_data`

**Document ID:** `{userId}`

**Document Structure:**
```json
{
  "userId": "string (required)",
  "totalPoints": "number (required) - current available points",
  "totalEarned": "number (required) - lifetime earned points",
  "totalRedeemed": "number (required) - lifetime redeemed points",
  "tier": "string (required) - 'bronze', 'silver', 'gold', 'platinum'",
  "nextTierPoints": "number (optional) - points needed for next tier",
  "lastActivity": "timestamp (required)",
  "joinedAt": "timestamp (required)",
  "updatedAt": "timestamp (required)"
}
```

**Indexes:**
- `tier` (ascending)
- `totalPoints` (descending)
- `lastActivity` (descending)

### 3. loyalty_rewards
Stores available rewards that users can redeem with points.

**Collection Path:** `/loyalty_rewards`

**Document Structure:**
```json
{
  "id": "string (auto-generated)",
  "title": "string (required)",
  "description": "string (required)",
  "pointsCost": "number (required)",
  "category": "string (required) - 'food', 'discount', 'freebie'",
  "isActive": "boolean (required)",
  "availableQuantity": "number (optional) - null for unlimited",
  "usedQuantity": "number (required) - default 0",
  "validFrom": "timestamp (required)",
  "validUntil": "timestamp (optional)",
  "iconName": "string (required)",
  "color": "string (required)",
  "terms": "string (optional) - terms and conditions",
  "createdAt": "timestamp (required)",
  "updatedAt": "timestamp (required)"
}
```

**Indexes:**
- `isActive` (ascending)
- `category` (ascending)
- `pointsCost` (ascending)
- `validUntil` (ascending)

### 4. promo_codes
Stores available promo codes.

**Collection Path:** `/promo_codes`

**Document Structure:**
```json
{
  "id": "string (auto-generated)",
  "code": "string (required, unique)",
  "title": "string (required)",
  "description": "string (required)",
  "type": "string (required) - 'percentage', 'fixed_amount', 'free_delivery'",
  "value": "number (required) - discount percentage or fixed amount",
  "minOrderAmount": "number (optional)",
  "maxDiscountAmount": "number (optional)",
  "validFrom": "timestamp (required)",
  "validUntil": "timestamp (required)",
  "isActive": "boolean (required)",
  "usageLimit": "number (optional) - null for unlimited",
  "usageCount": "number (required) - default 0",
  "applicableCategories": "array of strings (optional)",
  "excludedItems": "array of strings (optional)",
  "isFirstOrderOnly": "boolean (required)",
  "iconName": "string (required)",
  "color": "string (required)",
  "createdAt": "timestamp (required)",
  "updatedAt": "timestamp (required)"
}
```

**Indexes:**
- `code` (ascending, unique)
- `isActive` (ascending)
- `validUntil` (ascending)
- `isFirstOrderOnly` (ascending)

### 5. user_promo_usage
Stores promo code usage history for users.

**Collection Path:** `/user_promo_usage`

**Document Structure:**
```json
{
  "id": "string (auto-generated)",
  "userId": "string (required)",
  "promoCodeId": "string (required)",
  "promoCode": "string (required)",
  "usedAt": "timestamp (required)",
  "orderId": "string (required)",
  "discountAmount": "number (required)",
  "orderAmount": "number (required)"
}
```

**Indexes:**
- `userId` (ascending)
- `userId, usedAt` (composite, descending on usedAt)
- `promoCodeId` (ascending)
- `orderId` (ascending)

## Security Rules

Add these rules to your `firestore.rules` file:

```javascript
// Loyalty Points Rules
match /loyalty_points/{pointId} {
  allow read: if request.auth != null && request.auth.uid == resource.data.userId;
  allow write: if false; // Only server-side operations
}

match /user_loyalty_data/{userId} {
  allow read: if request.auth != null && request.auth.uid == userId;
  allow write: if false; // Only server-side operations
}

match /loyalty_rewards/{rewardId} {
  allow read: if request.auth != null;
  allow write: if false; // Only admin operations
}

// Promo Codes Rules
match /promo_codes/{promoId} {
  allow read: if request.auth != null;
  allow write: if false; // Only admin operations
}

match /user_promo_usage/{usageId} {
  allow read: if request.auth != null && request.auth.uid == resource.data.userId;
  allow write: if false; // Only server-side operations
}
```

## Sample Data

### Sample Loyalty Rewards
```json
[
  {
    "title": "Free Appetizer",
    "description": "Get any starter for free",
    "pointsCost": 500,
    "category": "food",
    "isActive": true,
    "iconName": "restaurant",
    "color": "orange"
  },
  {
    "title": "10% Off Next Order",
    "description": "Save 10% on your next purchase",
    "pointsCost": 750,
    "category": "discount",
    "isActive": true,
    "iconName": "percent",
    "color": "green"
  },
  {
    "title": "Free Dessert",
    "description": "Choose any dessert on the house",
    "pointsCost": 800,
    "category": "food",
    "isActive": true,
    "iconName": "cake",
    "color": "orange"
  }
]
```

### Sample Promo Codes
```json
[
  {
    "code": "FIRST20",
    "title": "20% Off First Order",
    "description": "Get 20% discount on your first order. Valid for new customers only.",
    "type": "percentage",
    "value": 20,
    "minOrderAmount": 500,
    "isActive": true,
    "isFirstOrderOnly": true,
    "iconName": "percent",
    "color": "green"
  },
  {
    "code": "SAVE150",
    "title": "₹150 Off on Orders Above ₹800",
    "description": "Save ₹150 on orders above ₹800. Maximum discount ₹150.",
    "type": "fixed_amount",
    "value": 150,
    "minOrderAmount": 800,
    "maxDiscountAmount": 150,
    "isActive": true,
    "isFirstOrderOnly": false,
    "iconName": "currency_rupee",
    "color": "orange"
  },
  {
    "code": "FLAT100",
    "title": "Flat ₹100 Off",
    "description": "Get flat ₹100 off on orders above ₹600",
    "type": "fixed_amount",
    "value": 100,
    "minOrderAmount": 600,
    "isActive": true,
    "isFirstOrderOnly": false,
    "iconName": "currency_rupee",
    "color": "blue"
  }
]
```

## Implementation Notes

1. **Transactions**: Use Firestore transactions when updating user loyalty data to ensure consistency.

2. **Cloud Functions**: Consider using Cloud Functions for:
   - Automatically awarding points when orders are completed
   - Updating user loyalty tiers based on total points
   - Cleaning up expired points
   - Validating promo code usage

3. **Caching**: Implement local caching for frequently accessed data like available rewards and active promo codes.

4. **Analytics**: Track usage patterns for rewards and promo codes to optimize the loyalty program.

5. **Notifications**: Send push notifications when users earn points, reach new tiers, or when new rewards are available.