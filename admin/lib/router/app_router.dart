import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/supabase_service.dart';

// Screens
import '../screens/login_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/articles_screen.dart';
import '../screens/article_editor_screen.dart';
import '../screens/projects_screen.dart';
import '../screens/project_editor_screen.dart';
import '../screens/skills_screen.dart';
import '../screens/inbox_screen.dart';
import '../screens/placeholders.dart';

// Navigation
import '../widgets/admin_layout.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>();

final router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/admin/dashboard',
  redirect: (context, state) {
    final isLoggedIn = SupabaseService.isLoggedIn;
    final isGoingToLogin = state.matchedLocation == '/admin/login';

    if (!isLoggedIn && !isGoingToLogin) {
      // Redirect to login if not authenticated
      return '/admin/login?redirect=${state.uri.toString()}';
    }

    if (isLoggedIn && isGoingToLogin) {
      // Redirect to dashboard if already logged in
      final redirectPath = state.uri.queryParameters['redirect'];
      return redirectPath ?? '/admin/dashboard';
    }

    if (state.matchedLocation == '/' || state.matchedLocation == '/admin') {
      return '/admin/dashboard';
    }

    return null; // No redirect needed
  },
  routes: [
    GoRoute(
      path: '/admin/login',
      builder: (context, state) => const LoginScreen(),
    ),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return AdminLayout(child: child);
      },
      routes: [
        GoRoute(
          path: '/admin/dashboard',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/admin/articles',
          builder: (context, state) => const ArticlesScreen(),
        ),
        GoRoute(
          path: '/admin/articles/new',
          builder: (context, state) => const ArticleEditorScreen(),
        ),
        GoRoute(
          path: '/admin/articles/:id',
          builder: (context, state) => ArticleEditorScreen(id: state.pathParameters['id']),
        ),
        GoRoute(
          path: '/admin/projects',
          builder: (context, state) => const ProjectsScreen(),
        ),
        GoRoute(
          path: '/admin/projects/new',
          builder: (context, state) => const ProjectEditorScreen(),
        ),
        GoRoute(
          path: '/admin/projects/:id',
          builder: (context, state) => ProjectEditorScreen(id: state.pathParameters['id']),
        ),
        GoRoute(
          path: '/admin/skills',
          builder: (context, state) => const SkillsScreen(),
        ),
        GoRoute(
          path: '/admin/inbox',
          builder: (context, state) => const InboxScreen(),
        ),
        GoRoute(
          path: '/admin/blog',
          builder: (context, state) => const BlogScreen(),
        ),
        GoRoute(
          path: '/admin/portfolio',
          builder: (context, state) => const PortfolioScreen(),
        ),
        GoRoute(
          path: '/admin/about',
          builder: (context, state) => const AboutScreen(),
        ),
        GoRoute(
          path: '/admin/media',
          builder: (context, state) => const MediaScreen(),
        ),
        GoRoute(
          path: '/admin/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    ),
  ],
);
