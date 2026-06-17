# Individual Table Ordering System

## Overview

This system allows waiters to take individual orders for customers sitting at the same table. Instead of combining all orders into one bill, each person can order separately while maintaining the table association.

## Key Features

### 1. **Seat-Based Ordering**
- Each table can have multiple seats (default: 4)
- Each seat can have a different customer name
- Individual orders are tracked per seat

### 2. **Flexible Ordering**
- **Individual Orders**: Each person orders their own items
- **Shared Orders**: Items can be shared among multiple people at the table
- **Split Billing**: Each person gets their own bill
- **Real-time Tracking**: Orders are tracked in real-time

### 3. **Order Management**
- **Status Tracking**: Orders go through different states (ordering → placed → preparing → ready → served → paid)
- **Order Editing**: Orders can be modified after placement
- **Kitchen Integration**: Orders flow to kitchen with seat identification

## System Components

### 1. **Models**

#### `IndividualOrder`
Represents a single person's order at a table:
- `tableNumber`: Which table this order belongs to
- `seatNumber`: Which seat (1-4 typically)
- `customerName`: Name of the person ordering
- `items`: List of menu items
- `totalAmount`: Total cost for this order
- `status`: Current order status
- `isShared`: Whether this order is shared with others
- `sharedWithSeats`: Which seats are sharing this order

#### `TableSession`
Represents an active dining session at a table:
- `tableNumber`: The table identifier
- `totalSeats`: Number of seats at the table
- `seatAssignments`: Maps seat numbers to customer names
- `sessionStartTime`: When the session started
- `waiterName`: Assigned waiter

### 2. **Services**

#### `TableOrderService`
Handles all table-based ordering operations:
- `createTableSession()`: Start a new table session
- `assignSeats()`: Assign customer names to seats
- `addIndividualOrder()`: Add order for a specific seat
- `getTableOrders()`: Get all orders for a table
- `getTableSummary()`: Get billing summary for the table

### 3. **Screens**

#### `TableOrderingScreen`
Main interface for waiters to manage table orders:
- **Seat Selection**: Visual representation of table seats
- **Customer Assignment**: Assign names to seats
- **Menu Interface**: Browse and add menu items
- **Order Tracking**: View all current orders for the table
- **Billing Summary**: Get per-seat and total billing information

## How to Use

### For Waiters

1. **Select a Table**
   - Tap on any table from the tables list
   - This opens the `TableOrderingScreen`

2. **Set Up Table Session**
   - The system automatically creates a new session
   - Or continues an existing active session

3. **Assign Seats**
   - Tap on seat numbers (1-4)
   - Enter customer names for each seat
   - Names are saved for the entire session

4. **Take Orders**
   - Select a seat to start ordering
   - Browse menu items
   - Tap items to add to the selected seat's order
   - Orders are automatically saved

5. **Manage Orders**
   - View all orders in the bottom panel
   - Track order status in real-time
   - Add more items to existing orders

6. **Close Session**
   - Use the receipt icon to view table summary
   - See individual seat totals and grand total
   - Close the table session when done

### For Kitchen Staff

Orders appear in the kitchen system with:
- Table number and seat number
- Customer name
- Individual order details
- Special instructions
- Order status tracking

## Data Structure

### Firestore Collections

#### `tableSessions`
```json
{
  "tableNumber": "1",
  "totalSeats": 4,
  "seatAssignments": {
    "1": "John Doe",
    "2": "Jane Smith",
    "3": "Bob Johnson",
    "4": "Alice Brown"
  },
  "sessionStartTime": "2024-01-15T10:30:00Z",
  "waiterName": "Sarah",
  "isActive": true
}
```

#### `individualOrders`
```json
{
  "tableNumber": "1",
  "seatNumber": 1,
  "customerName": "John Doe",
  "items": [
    {
      "id": "burger",
      "name": "Classic Burger",
      "price": 12.99,
      "quantity": 1
    }
  ],
  "totalAmount": 12.99,
  "status": "placed",
  "orderTime": "2024-01-15T10:45:00Z",
  "isShared": false,
  "sharedWithSeats": []
}
```

## Usage Scenarios

### Scenario 1: Individual Orders
Four friends want to order separately:
1. Seat 1: John orders burger and fries ($16.98)
2. Seat 2: Jane orders salad ($9.99)
3. Seat 3: Bob orders pizza to share with Alice ($18.99)
4. Seat 4: Alice orders drink ($4.99)

Bob's pizza is marked as shared with seat 4, so the cost is split between Bob and Alice.

### Scenario 2: Shared Items
A couple sharing appetizers:
- Seat 1: Mike orders steak ($24.99)
- Seat 2: Lisa orders pasta ($16.99)
- They share nachos ($12.99) - marked as shared between seats 1 and 2

Each pays their individual items plus half of shared items.

## Implementation Steps

### 1. Initialize the System
```dart
// Run this once to set up sample data
final initializer = TableOrderInitializer();
await initializer.initializeTableOrderSystem();
```

### 2. Use in Your App
```dart
// Navigate to table ordering
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => TableOrderingScreen(tableNumber: '1'),
  ),
);
```

### 3. Check System Status
```dart
final status = await TableOrderInitializer().checkSystemStatus();
print(status);
```

## Benefits

### For Customers
- **Privacy**: Individual bills for each person
- **Flexibility**: Can share items without confusion
- **Accuracy**: Orders are tracked per person
- **Fair Billing**: Shared items are automatically split

### For Restaurant
- **Efficiency**: Clear order tracking per table
- **Accuracy**: Reduced billing disputes
- **Flexibility**: Accommodates different group dynamics
- **Analytics**: Track individual vs group ordering patterns

### For Staff
- **Clarity**: Clear seat and customer identification
- **Organization**: Orders are grouped by table but tracked individually
- **Billing**: Automatic calculation of individual and shared costs
- **Communication**: Easy to communicate with customers about their specific orders

## Testing the System

### Quick Setup
1. Ensure tables are initialized in Firestore
2. Run the initializer: `TableOrderInitializer().initializeTableOrderSystem()`
3. Navigate to Tables → Select any table
4. Start assigning seats and taking orders

### Sample Data
The initializer creates:
- 2 active table sessions
- 4 sample individual orders
- Different order statuses
- Shared and individual items

### Clearing Data
```dart
// Clear all table order data
await TableOrderInitializer().clearTableOrderData();
```

## Next Steps

1. **Kitchen Integration**: Connect orders to kitchen display system
2. **Payment Processing**: Integrate with payment systems for individual billing
3. **Customer App**: Allow customers to view their individual orders
4. **Analytics**: Add reporting for table-based ordering patterns
5. **Customization**: Allow configuration of seat numbers per table
6. **Order History**: Track customer order history by name

## Support

For issues or questions about the individual ordering system, refer to:
- `TableOrderService` class for all ordering operations
- `TableOrderingScreen` for the user interface
- `TableOrderInitializer` for system setup
- Individual model classes for data structure reference