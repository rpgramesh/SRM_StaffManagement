import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

// Run this script to set up sample loyalty data in Firebase
// Usage: dart run setup_loyalty_data.dart

void main() async {
  // Initialize Firebase
  await Firebase.initializeApp();
  
  final firestore = FirebaseFirestore.instance;
  
  print('Setting up loyalty rewards data...');
  
  // Sample loyalty rewards
  final rewards = [
    {
      'title': 'Free Appetizer',
      'description': 'Get any starter for free',
      'pointsCost': 500,
      'category': 'food',
      'isActive': true,
      'availableQuantity': null, // unlimited
      'usedQuantity': 0,
      'validFrom': Timestamp.now(),
      'validUntil': null, // no expiry
      'iconName': 'restaurant',
      'color': 'orange',
      'terms': 'Valid on all appetizers. Cannot be combined with other offers.',
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    },
    {
      'title': '10% Off Next Order',
      'description': 'Save 10% on your next purchase',
      'pointsCost': 750,
      'category': 'discount',
      'isActive': true,
      'availableQuantity': null,
      'usedQuantity': 0,
      'validFrom': Timestamp.now(),
      'validUntil': null,
      'iconName': 'percent',
      'color': 'green',
      'terms': 'Valid for 30 days from redemption. Minimum order ₹300.',
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    },
    {
      'title': 'Free Dessert',
      'description': 'Choose any dessert on the house',
      'pointsCost': 800,
      'category': 'food',
      'isActive': true,
      'availableQuantity': null,
      'usedQuantity': 0,
      'validFrom': Timestamp.now(),
      'validUntil': null,
      'iconName': 'cake',
      'color': 'orange',
      'terms': 'Valid on all desserts. Dine-in only.',
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    },
    {
      'title': 'Free Main Course',
      'description': 'Get any main course for free',
      'pointsCost': 1500,
      'category': 'food',
      'isActive': false, // locked for now
      'availableQuantity': null,
      'usedQuantity': 0,
      'validFrom': Timestamp.now(),
      'validUntil': null,
      'iconName': 'restaurant_menu',
      'color': 'grey',
      'terms': 'Valid on main courses up to ₹500. Dine-in only.',
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    },
    {
      'title': '20% Off Next Order',
      'description': 'Save 20% on your next purchase',
      'pointsCost': 2000,
      'category': 'discount',
      'isActive': false, // locked for now
      'availableQuantity': null,
      'usedQuantity': 0,
      'validFrom': Timestamp.now(),
      'validUntil': null,
      'iconName': 'percent',
      'color': 'grey',
      'terms': 'Valid for 30 days from redemption. Minimum order ₹500.',
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    },
  ];
  
  // Add rewards to Firestore
  final batch = firestore.batch();
  
  for (final reward in rewards) {
    final docRef = firestore.collection('loyalty_rewards').doc();
    batch.set(docRef, reward);
  }
  
  await batch.commit();
  
  print('✅ Successfully added ${rewards.length} loyalty rewards!');
  print('\nSample user loyalty data setup:');
  print('To test the loyalty screen, you can manually add a user_loyalty_data document:');
  print('Collection: user_loyalty_data');
  print('Document ID: [your_user_id]');
  print('Data: {');
  print('  "userId": "[your_user_id]",');
  print('  "totalPoints": 1250,');
  print('  "totalEarned": 1250,');
  print('  "totalRedeemed": 0,');
  print('  "tier": "bronze",');
  print('  "nextTierPoints": 750,');
  print('  "lastActivity": [current_timestamp],');
  print('  "joinedAt": [current_timestamp],');
  print('  "updatedAt": [current_timestamp]');
  print('}');
  
  print('\n🎉 Loyalty system setup complete!');
}