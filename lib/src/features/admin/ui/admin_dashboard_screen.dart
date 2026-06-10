import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/application/auth_session_provider.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Colors.black,
        ),
        ),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => _confirmLogout(context, ref),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _AdminTile(
            icon: Icons.restaurant_menu,
            title: 'Manage Packages',
            subtitle: 'Create, edit, and remove restaurant menu packages.',
            onTap: () => context.go('/admin/packages'),
          ),
          _AdminTile(
            icon: Icons.people_outline,
            title: 'Manage Users',
            subtitle: 'View customer and administrator accounts.',
            onTap: () => context.go('/admin/users'),
          ),
          _AdminTile(
            icon: Icons.event_note_outlined,
            title: 'Manage Reservations',
            subtitle: 'View, update, and cancel customer bookings.',
            onTap: () => context.go('/admin/bookings'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Go Back'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(authSessionProvider.notifier).signOut();
              Navigator.of(dialogContext).pop();
              context.go('/admin-login');
            },
            child: const Text('Log out'),
          ),
        ],
      ),
    );
  }
}

class _AdminTile extends StatelessWidget {
  const _AdminTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(icon, color: const Color(0xFF6C2DDC)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
