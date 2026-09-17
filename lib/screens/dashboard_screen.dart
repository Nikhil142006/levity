import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class DashboardScreen extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const DashboardScreen({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentIndex = navigationShell.currentIndex;

    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.only(bottom: 16, left: 24, right: 24),
          height: 64,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.black.withOpacity(0.5) : Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                    width: 1,
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final itemWidth = constraints.maxWidth / 5;
                    return Stack(
                      children: [
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.fastOutSlowIn,
                          left: itemWidth * currentIndex,
                          top: 0,
                          bottom: 0,
                          width: itemWidth,
                          child: Center(
                            child: Container(
                              width: 48,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildNavItem(context, Icons.home_outlined, Icons.home, 0),
                            _buildNavItem(context, Icons.directions_run_outlined, Icons.directions_run, 1),
                            _buildNavItem(context, Icons.psychology_outlined, Icons.psychology, 2),
                            _buildNavItem(context, Icons.map_outlined, Icons.map, 3),
                            _buildNavItem(context, Icons.person_outline, Icons.person, 4),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, IconData outlineIcon, IconData filledIcon, int index) {
    final isSelected = navigationShell.currentIndex == index;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final unselectedColor = Theme.of(context).iconTheme.color?.withOpacity(0.5) ?? Colors.grey;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 48,
        height: 64,
        alignment: Alignment.center,
        child: Icon(
          isSelected ? filledIcon : outlineIcon,
          color: isSelected ? primaryColor : unselectedColor,
          size: 26,
        ),
      ),
    );
  }
}
