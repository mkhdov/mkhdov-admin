import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

class AdminBottomNav extends StatefulWidget {
  const AdminBottomNav({super.key});

  @override
  State<AdminBottomNav> createState() => _AdminBottomNavState();
}

class _AdminBottomNavState extends State<AdminBottomNav> {
  int _unreadInboxCount = 0;
  dynamic _inboxSubscription;

  final List<_NavItem> _navItems = [
    _NavItem('Dashboard', '/admin/dashboard', LucideIcons.layoutDashboard),
    _NavItem('Articles', '/admin/articles', LucideIcons.fileText),
    _NavItem('Blog', '/admin/blog', LucideIcons.bookOpen),
    _NavItem('Inbox', '/admin/inbox', LucideIcons.inbox),
    _NavItem('Projects', '/admin/projects', LucideIcons.briefcase),
    _NavItem('Skills', '/admin/skills', LucideIcons.code),
    _NavItem('Portfolio', '/admin/portfolio', LucideIcons.folderOpen),
    _NavItem('About', '/admin/about', LucideIcons.user),
    _NavItem('Media', '/admin/media', LucideIcons.image),
    _NavItem('Settings', '/admin/settings', LucideIcons.settings),
  ];

  @override
  void initState() {
    super.initState();
    _loadUnreadInboxCount();
    _subscribeToInboxUnread();
  }

  @override
  void dispose() {
    if (_inboxSubscription != null) {
      SupabaseService.removeChannel(_inboxSubscription!);
    }
    super.dispose();
  }

  Future<void> _loadUnreadInboxCount() async {
    try {
      final response = await SupabaseService.from('conversations')
          .select('id')
          .gt('unread_count_admin', 0)
          .count();
      
      if (mounted) {
        setState(() {
          _unreadInboxCount = response.count;
        });
      }
    } catch (e) {
      debugPrint('Error loading unread inbox count: $e');
    }
  }

  void _subscribeToInboxUnread() {
    _inboxSubscription = SupabaseService.channel('admin_nav_inbox_unread')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversations',
          callback: (payload) {
            _loadUnreadInboxCount();
          },
        )
        .subscribe();
  }

  Future<void> _signOut() async {
    await SupabaseService.signOut();
    if (mounted) {
      context.go('/admin/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;

    return Container(
      margin: const EdgeInsets.all(24).copyWith(top: 0),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.accentBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F1722), // rgba(15, 23, 34, 0.08)
            blurRadius: 32,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ..._navItems.map((item) {
                final isActive = location.startsWith(item.path);
                return _buildNavItem(
                  context: context,
                  item: item,
                  isActive: isActive,
                  hasUnread: item.path == '/admin/inbox' && _unreadInboxCount > 0,
                  onTap: () => context.go(item.path),
                );
              }),
              Container(
                width: 1,
                height: 32,
                color: AppColors.accentBorder,
                margin: const EdgeInsets.symmetric(horizontal: 4),
              ),
              _buildNavItem(
                context: context,
                item: _NavItem('Logout', '', LucideIcons.logOut),
                isActive: false,
                isDanger: true,
                onTap: _signOut,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required _NavItem item,
    required bool isActive,
    bool hasUnread = false,
    bool isDanger = false,
    required VoidCallback onTap,
  }) {
    Color getIconColor() {
      if (isActive) return AppColors.accent;
      if (isDanger) return AppColors.error;
      return AppColors.textBody;
    }

    Color getBgColor() {
      if (isActive) return AppColors.accent.withValues(alpha: 0.1);
      return Colors.transparent;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      hoverColor: isDanger
          ? AppColors.errorBg
          : AppColors.accent.withValues(alpha: 0.06),
      child: Container(
        constraints: const BoxConstraints(minWidth: 64),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: getBgColor(),
          borderRadius: BorderRadius.circular(16),
          border: isActive
              ? Border.all(color: AppColors.accentBorder)
              : Border.all(color: Colors.transparent),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  item.icon,
                  size: 22,
                  color: getIconColor(),
                ),
                if (hasUnread)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.errorBorder,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: getIconColor(),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final String path;
  final IconData icon;

  _NavItem(this.label, this.path, this.icon);
}
