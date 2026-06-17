import 'package:flutter/material.dart';
import '../utils/table_order_initializer.dart';

class TableOrderDemo extends StatelessWidget {
  const TableOrderDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Table Order Demo'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 20,
          children: [
            const Text(
              'Table Individual Ordering System',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Test the new seat-based ordering system',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: const Text('Initialize Demo Data'),
              onPressed: () => _initializeDemo(context),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.cleaning_services),
              label: const Text('Clear All Data'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => _clearDemo(context),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.info),
              label: const Text('Check System Status'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              onPressed: () => _checkStatus(context),
            ),
            const SizedBox(height: 40),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text('Demo Instructions:', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text('1. Initialize demo data'),
                    Text('2. Go to Tables screen'),
                    Text('3. Select any table'),
                    Text('4. Try seat-based ordering'),
                    Text('5. Check individual bills'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _initializeDemo(BuildContext context) async {
    try {
      await TableOrderInitializer().initializeTableOrderSystem();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Demo data initialized successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _clearDemo(BuildContext context) async {
    try {
      await TableOrderInitializer().clearTableOrderData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All table order data cleared!'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _checkStatus(BuildContext context) async {
    try {
      final status = await TableOrderInitializer().checkSystemStatus();
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('System Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Table Sessions: ${status['tableSessions']}'),
              Text('Individual Orders: ${status['individualOrders']}'),
              const SizedBox(height: 8),
              Text('Status: ${status['status'] ?? 'Unknown'}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error checking status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}