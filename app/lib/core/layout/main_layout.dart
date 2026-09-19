import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';


class MainLayout extends StatelessWidget {
  final Widget child;
  final int currentIndex;

  const MainLayout({
    super.key,
    required this.child,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0EEFF),
      body: child,
      bottomNavigationBar: _BottomNav(currentIndex: currentIndex),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  const _BottomNav({required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72 + MediaQuery.of(context).padding.bottom,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _NavItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label: 'Home',
              index: 0,
              currentIndex: currentIndex,
              onTap: () => context.go('/home'),
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.calendar_month_outlined,
              activeIcon: Icons.calendar_month_rounded,
              label: 'Schedule',
              index: 1,
              currentIndex: currentIndex,
              onTap: () => context.go('/study-plan'),
            ),
          ),
          // Centre FAB
          GestureDetector(
            onTap: () => context.go('/chat'),
            child: Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x558B5CF6),
                    blurRadius: 14,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(
                currentIndex == 2 ? Icons.auto_awesome : Icons.auto_awesome_outlined,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.description_outlined,
              activeIcon: Icons.description_rounded,
              label: 'Documents',
              index: 3,
              currentIndex: currentIndex,
              onTap: () => context.go('/documents'),
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.settings_outlined,
              activeIcon: Icons.settings_rounded,
              label: 'Settings',
              index: 4,
              currentIndex: currentIndex,
              onTap: () => context.go('/profile'),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final int currentIndex;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool selected = index == currentIndex;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? activeIcon : icon,
              color: selected ? AppColors.primary : AppColors.textMuted,
              size: 22,
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected ? AppColors.primary : AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
