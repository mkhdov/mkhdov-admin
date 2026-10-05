import 'package:flutter/material.dart';

class AdminPageShell extends StatelessWidget {
  final String title;
  final Widget child;

  const AdminPageShell({
    super.key,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.displayLarge,
        ),
        const SizedBox(height: 24),
        Expanded(child: child),
      ],
    );
  }
}
