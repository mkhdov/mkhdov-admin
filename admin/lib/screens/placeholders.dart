import 'package:flutter/material.dart';
import '../widgets/admin_page_shell.dart';

class BlogScreen extends StatelessWidget {
  const BlogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminPageShell(
      title: 'Blog',
      child: Center(
        child: Text('Coming Soon'),
      ),
    );
  }
}

class PortfolioScreen extends StatelessWidget {
  const PortfolioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminPageShell(
      title: 'Portfolio',
      child: Center(
        child: Text('Coming Soon'),
      ),
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminPageShell(
      title: 'About',
      child: Center(
        child: Text('Coming Soon'),
      ),
    );
  }
}

class MediaScreen extends StatelessWidget {
  const MediaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminPageShell(
      title: 'Media',
      child: Center(
        child: Text('Coming Soon'),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminPageShell(
      title: 'Settings',
      child: Center(
        child: Text('Coming Soon'),
      ),
    );
  }
}
