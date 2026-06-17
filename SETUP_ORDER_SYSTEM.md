# Order System Setup Guide

## Firestore Collections Setup

To use the order-taking functionality, you need to set up the following collections in Firestore:

### 1. Tables Collection
Create a collection named `tables` with documents for each table:

```javascript
// Document ID: auto-generated
{
  "tableNumber": 1,
  "capacity": 4,
  "status": "available", // available, occupied, reserved
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-01T00:00:00Z"
}
```

### 2. Categories Collection
Create a collection named `categories` with documents for menu categories:

```javascript
// Document ID: auto-generated
{
  "name": "Starters",
  "order": 1,
  "isActive": true
}
```

### 3. Menu Items Collection
The menu items should already be populated, but ensure each has:
- `category` field matching one of the categories
- `price` as a number
- `isAvailable` as boolean (optional)

### 4. Orders Collection
This will be created automatically when orders are placed.

## Quick Setup Commands

### Add Sample Tables (10 tables)
```javascript
// Run this in Firestore console or use the Firebase Admin SDK
const tables = [];
for (let i = 1; i <= 10; i++) {
  tables.push({
    tableNumber: i,
    capacity: i <= 5 ? 4 : 6, // Tables 1-5: 4 seats, Tables 6-10: 6 seats
    status: 'available',
    createdAt: new Date(),
    updatedAt: new Date()
  });
}
```

### Add Sample Categories
```javascript
const categories = [
  { name: 'Starters', order: 1, isActive: true },
  { name: 'Main Course', order: 2, isActive: true },
  { name: 'Rice', order: 3, isActive: true },
  { name: 'Breads', order: 4, isActive: true },
  { name: 'Desserts', order: 5, isActive: true }
];
```

## Testing the System

1. **Navigate to Waiter App** → Click "Take Order" button
2. **Select Table** → Choose an available table and enter number of guests
3. **Browse Menu** → Select items from different categories
4. **Review Cart** → Check items, add special instructions
5. **Process Payment** → Choose payment method and complete transaction

## Features Implemented

- **Table Selection**: Visual table status display (available/occupied)
- **Guest Count**: Input for number of people at the table
- **Menu Browsing**: Category tabs with item cards
- **Cart Management**: Add/remove items, quantity adjustment, special notes
- **Payment Processing**: Cash, credit card, and digital wallet options
- **Order Tracking**: Real-time updates to Firestore

## Dependencies

The system uses existing dependencies:
- `cloud_firestore` for database operations
- `provider` for state management
- `flutter_svg` for menu item images

No additional dependencies are required.