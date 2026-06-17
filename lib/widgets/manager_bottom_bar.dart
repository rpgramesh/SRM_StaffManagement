import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/manager_service.dart';

class ManagerBottomBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const ManagerBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildBottomBarItem(
              context,
              index: 0,
              icon: Icons.restaurant,
              label: 'Restaurants',
              stream: Provider.of<ManagerService>(context).getActiveRestaurantsCount(),
            ),
            _buildBottomBarItem(
              context,
              index: 1,
              icon: Icons.motorcycle,
              label: 'Dashers',
              stream: Provider.of<ManagerService>(context).getActiveDashersCount(),
            ),
            _buildBottomBarItem(
              context,
              index: 2,
              icon: Icons.analytics,
              label: 'Analytics',
              stream: Provider.of<ManagerService>(context).getTotalOrdersCount(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBarItem(
    BuildContext context, {
    required int index,
    required IconData icon,
    required String label,
    required Stream<int> stream,
  }) {
    final isSelected = currentIndex == index;
    
    return GestureDetector(
      onTap: () => onTap(index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.topRight,
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: isSelected ? Colors.deepPurple : Colors.grey,
                ),
                StreamBuilder<int>(
                  stream: stream,
                  builder: (context, snapshot) {
                    final count = snapshot.data ?? 0;
                    return Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        count.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.deepPurple : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}