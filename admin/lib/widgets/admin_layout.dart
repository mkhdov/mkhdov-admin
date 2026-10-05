import 'package:flutter/material.dart';
import 'admin_bottom_nav.dart';
import '../theme/app_theme.dart';

class AdminLayout extends StatelessWidget {
  final Widget child;

  const AdminLayout({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          // Background gradient similar to web
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFFFFFF),
                  Color(0xFFF8FAFC), // at 44% in web
                  Color(0xFFFFFFFF),
                ],
                stops: [0.0, 0.44, 1.0],
              ),
            ),
          ),
          
          // Main content area
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: 120, // Space for bottom nav
              ),
              child: child,
            ),
          ),
          
          // Floating bottom navigation
          const Align(
            alignment: Alignment.bottomCenter,
            child: AdminBottomNav(),
          ),
        ],
      ),
    );
  }
}
