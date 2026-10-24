import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_typography.dart';

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
      backgroundColor: AppColors.paper,
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
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      height: 68 + bottomInset,
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.line)),
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
              label: 'Plan',
              index: 1,
              currentIndex: currentIndex,
              onTap: () => context.go('/study-plan'),
            ),
          ),
          // Centre "Ask" tile
          Expanded(
            child: Semantics(
              button: true,
              selected: currentIndex == 2,
              label: 'Ask the study assistant',
              child: GestureDetector(
                onTap: () => context.go('/chat'),
                behavior: HitTestBehavior.opaque,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    width: 52,
                    height: 44,
                    decoration: BoxDecoration(
                      color: currentIndex == 2 ? AppColors.highlighter : AppColors.ink,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.ink, width: 1.5),
                      boxShadow: currentIndex == 2 ? AppShadows.hardSmall : null,
                    ),
                    child: Icon(
                      Icons.edit_note_rounded,
                      color: currentIndex == 2 ? AppColors.ink : AppColors.highlighter,
                      size: 26,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.description_outlined,
              activeIcon: Icons.description_rounded,
              label: 'Docs',
              index: 3,
              currentIndex: currentIndex,
              onTap: () => context.go('/documents'),
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.person_outline_rounded,
              activeIcon: Icons.person_rounded,
              label: 'Profile',
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
    final color = selected ? AppColors.ink : AppColors.textMuted;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? activeIcon : icon, color: color, size: 22),
            const SizedBox(height: 4),
            // Label sits on a highlighter stroke when active
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: selected ? AppColors.highlighter : Colors.transparent,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: AppTypography.bodySmall.copyWith(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
