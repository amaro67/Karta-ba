import 'package:flutter/material.dart';
import 'karta_logo.dart';
class AdminSidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  const AdminSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: const KartaLogo(
              fontSize: 20,
              showIcon: true,
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                _SidebarItem(
                  icon: Icons.dashboard_outlined,
                  selectedIcon: Icons.dashboard,
                  title: 'Dashboard',
                  isSelected: selectedIndex == 0,
                  onTap: () => onItemSelected(0),
                ),
                const SizedBox(height: 4),
                _SidebarItem(
                  icon: Icons.people_outline,
                  selectedIcon: Icons.people,
                  title: 'User Management',
                  isSelected: selectedIndex == 1,
                  onTap: () => onItemSelected(1),
                ),
                const SizedBox(height: 4),
                _SidebarItem(
                  icon: Icons.event_note_outlined,
                  selectedIcon: Icons.event_note,
                  title: 'Event Management',
                  isSelected: selectedIndex == 2,
                  onTap: () => onItemSelected(2),
                ),
                const SizedBox(height: 4),
                _SidebarItem(
                  icon: Icons.shopping_cart_outlined,
                  selectedIcon: Icons.shopping_cart,
                  title: 'Order Management',
                  isSelected: selectedIndex == 3,
                  onTap: () => onItemSelected(3),
                ),
                const SizedBox(height: 4),
                _SidebarItem(
                  icon: Icons.confirmation_number_outlined,
                  selectedIcon: Icons.confirmation_number,
                  title: 'Ticket Management',
                  isSelected: selectedIndex == 4,
                  onTap: () => onItemSelected(4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String title;
  final bool isSelected;
  final VoidCallback onTap;
  const _SidebarItem({
    required this.icon,
    required this.selectedIcon,
    required this.title,
    required this.isSelected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? Colors.grey.shade100 : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                isSelected ? selectedIcon : icon,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade700,
                size: 22,
              ),
              const SizedBox(width: 14),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? Colors.grey.shade900
                      : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}