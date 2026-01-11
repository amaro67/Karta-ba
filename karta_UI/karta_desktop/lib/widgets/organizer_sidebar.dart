import 'package:flutter/material.dart';
import 'karta_logo.dart';
class OrganizerSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  const OrganizerSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(
            color: Colors.grey.shade200,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            alignment: Alignment.centerLeft,
            child: const KartaLogo(
              fontSize: 18,
              showIcon: true,
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _SidebarItem(
                  icon: Icons.dashboard_outlined,
                  selectedIcon: Icons.dashboard,
                  title: 'Dashboard',
                  isSelected: selectedIndex == 0,
                  onTap: () => onItemSelected(0),
                ),
                const SizedBox(height: 6),
                _SidebarItem(
                  icon: Icons.event_note_outlined,
                  selectedIcon: Icons.event_note,
                  title: 'My Events',
                  isSelected: selectedIndex == 1,
                  onTap: () => onItemSelected(1),
                ),
                const SizedBox(height: 6),
                _SidebarItem(
                  icon: Icons.qr_code_scanner_outlined,
                  selectedIcon: Icons.qr_code_scanner,
                  title: 'Scanners',
                  isSelected: selectedIndex == 2,
                  onTap: () => onItemSelected(2),
                ),
                const SizedBox(height: 6),
                _SidebarItem(
                  icon: Icons.trending_up_outlined,
                  selectedIcon: Icons.trending_up,
                  title: 'Sales',
                  isSelected: selectedIndex == 3,
                  onTap: () => onItemSelected(3),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                isSelected ? selectedIcon : icon,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade700,
              ),
              const SizedBox(width: 14),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.grey.shade900 : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}