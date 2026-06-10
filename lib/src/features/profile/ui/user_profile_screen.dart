import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/application/auth_session_provider.dart';

class UserProfileScreen extends ConsumerStatefulWidget {
  const UserProfileScreen({super.key});

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  final _phoneController = TextEditingController();
  var _lastPhoneValue = '';
  var _isSavingPhone = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider).valueOrNull;
    final name = (session?.fullName.trim().isNotEmpty ?? false)
        ? session!.fullName
        : session?.username ?? 'Guest';
    final username = session?.isGuest ?? true
        ? '@Guest'
        : '@${session!.username}';
    final phoneNumber = session?.phoneNumber ?? '';

    if (phoneNumber != _lastPhoneValue && !_isSavingPhone) {
      _lastPhoneValue = phoneNumber;
      _phoneController.text = phoneNumber;
    }

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Back',
                  onPressed: () => context.go('/packages'),
                  icon: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: 6),
                Text(
                  'Profile',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 34),
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  foregroundImage:
                      (session?.profileImageUrl.trim().isNotEmpty ?? false)
                      ? NetworkImage(session!.profileImageUrl)
                      : null,
                  child: const Icon(Icons.person, size: 30),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        username,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 38),
            const Text(
              'Options',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 24),
            _InfoRow(label: 'Email', value: session?.email ?? ''),
            const SizedBox(height: 22),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 70,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Text(
                      'Phone',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _phoneController,
                    enabled: !(session?.isGuest ?? true) && !_isSavingPhone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      hintText: '+(60) 000 111 222 333',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Save phone number',
                  onPressed: (session?.isGuest ?? true) || _isSavingPhone
                      ? null
                      : _savePhoneNumber,
                  icon: _isSavingPhone
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                ),
              ],
            ),
            const SizedBox(height: 34),
            FilledButton(
              onPressed: () {
                ref.read(authSessionProvider.notifier).signOut();
                context.go('/login');
              },
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.outline,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Log out'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _savePhoneNumber() async {
    setState(() => _isSavingPhone = true);
    try {
      await ref
          .read(authSessionProvider.notifier)
          .updatePhoneNumber(_phoneController.text);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Phone number updated.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingPhone = false);
      }
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '-' : value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
