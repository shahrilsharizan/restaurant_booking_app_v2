import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/data/auth_repository.dart';

const _purple = Color(0xFF6C2DDC);
const _panelGrey = Color(0xFFEFEFEF);

class AdminUserDirectoryScreen extends ConsumerStatefulWidget {
  const AdminUserDirectoryScreen({super.key});

  @override
  ConsumerState<AdminUserDirectoryScreen> createState() =>
      _AdminUserDirectoryScreenState();
}

class _AdminUserDirectoryScreenState
    extends ConsumerState<AdminUserDirectoryScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usersState = ref.watch(usersStreamProvider);

    return Scaffold(
      body: SafeArea(
        child: usersState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              _Message(title: 'Unable to load users', message: '$error'),
          data: (users) {
            final query = _searchController.text.trim().toLowerCase();
            final filteredUsers = query.isEmpty
                ? users
                : users
                      .where((user) {
                        final role = user.role == UserRole.admin
                            ? 'admin'
                            : 'user';
                        return user.fullName.toLowerCase().contains(query) ||
                            user.username.toLowerCase().contains(query) ||
                            user.email.toLowerCase().contains(query) ||
                            role.contains(query);
                      })
                      .toList(growable: false);

            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
              children: [
                _PageTitle(
                  title: 'User Directory',
                  onBack: () => context.go('/admin'),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: query.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear search',
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.close),
                                ),
                          hintText: 'Search by email, name, or role...',
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'User List',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                if (users.isEmpty)
                  const _Message(
                    title: 'No users',
                    message: 'Users added in Firebase will appear here.',
                  )
                else if (filteredUsers.isEmpty)
                  const _Message(
                    title: 'No matching users',
                    message: 'Try another search.',
                  )
                else
                  ...filteredUsers.map((user) => _UserCard(user: user)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final title = user.fullName.trim().isEmpty ? user.email : user.fullName;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black54),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          const CircleAvatar(radius: 24, child: Icon(Icons.person)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(user.email),
                Text(user.role == UserRole.admin ? 'Admin' : 'User'),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit user',
            onPressed: () => context.go('/admin/users/${user.documentId}/edit'),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
    );
  }
}

class AdminAddUserScreen extends StatelessWidget {
  const AdminAddUserScreen({super.key});

  @override
  Widget build(BuildContext context) => const _UserFormScreen();
}

class AdminEditUserScreen extends ConsumerWidget {
  const AdminEditUserScreen({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersState = ref.watch(usersStreamProvider);
    return usersState.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        body: _Message(title: 'Unable to load user', message: '$error'),
      ),
      data: (users) {
        AppUser? user;
        for (final candidate in users) {
          if (candidate.documentId == uid || candidate.uid == uid) {
            user = candidate;
            break;
          }
        }
        if (user == null) {
          return const _MissingUserScreen();
        }
        return _UserFormScreen(user: user);
      },
    );
  }
}

class _UserFormScreen extends ConsumerStatefulWidget {
  const _UserFormScreen({this.user});

  final AppUser? user;

  @override
  ConsumerState<_UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends ConsumerState<_UserFormScreen> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  var _role = UserRole.user;
  var _isSaving = false;
  var _isDeleting = false;

  bool get _isEditing => widget.user != null;

  @override
  void initState() {
    super.initState();
    final user = widget.user;
    if (user == null) return;
    _fullNameController.text = user.fullName;
    _emailController.text = user.email;
    _usernameController.text = user.username;
    _phoneController.text = user.phoneNumber;
    _role = user.role == UserRole.admin ? UserRole.admin : UserRole.user;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
          children: [
            _PageTitle(
              title: _isEditing ? 'Edit User' : 'Add User',
              onBack: () => context.go('/admin/users'),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _panelGrey,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  if (!_isEditing)
                    _Field(label: 'Full Name', controller: _fullNameController),
                  if (!_isEditing)
                    _Field(
                      label: 'Email',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                    ),
                  _Field(label: 'Username', controller: _usernameController),
                  _Field(
                    label: 'Phone Number',
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                  ),
                  _RoleOption(
                    label: 'Regular User',
                    selected: _role == UserRole.user,
                    onTap: () => setState(() => _role = UserRole.user),
                  ),
                  _RoleOption(
                    label: 'Admin',
                    selected: _role == UserRole.admin,
                    onTap: () => setState(() => _role = UserRole.admin),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSaving || _isDeleting ? null : _saveUser,
              style: FilledButton.styleFrom(
                backgroundColor: _purple,
                minimumSize: const Size.fromHeight(52),
              ),
              child: Text(_isEditing ? 'Save User' : 'Add User'),
            ),
            if (_isEditing) ...[
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _isSaving || _isDeleting ? null : _confirmDeleteUser,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                  minimumSize: const Size.fromHeight(52),
                ),
                child: Text(_isDeleting ? 'Deleting...' : 'Delete User'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _saveUser() async {
    setState(() => _isSaving = true);
    try {
      final repository = ref.read(authRepositoryProvider);
      if (_isEditing) {
        await repository.updateUserProfile(
          documentId: widget.user!.documentId,
          username: _usernameController.text,
          phoneNumber: _phoneController.text,
          role: _role,
        );
      } else {
        await repository.createUserProfile(
          fullName: _fullNameController.text,
          username: _usernameController.text,
          email: _emailController.text,
          phoneNumber: _phoneController.text,
          role: _role,
        );
      }

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Success!'),
          content: Text(
            _isEditing ? 'User successfully edited' : 'A new user is added',
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.go('/admin/users');
              },
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmDeleteUser() async {
    final user = widget.user;
    if (user == null) return;

    final title = user.fullName.trim().isEmpty ? user.email : user.fullName;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete user?'),
        content: Text('Delete $title? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Go Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      await ref.read(authRepositoryProvider).deleteUserProfile(user.documentId);

      if (!mounted) return;
      context.go('/admin/users');
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('User deleted.')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }
}

class _MissingUserScreen extends StatelessWidget {
  const _MissingUserScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
          child: Column(
            children: [
              _PageTitle(
                title: 'Edit User',
                onBack: () => context.go('/admin/users'),
              ),
              const Expanded(
                child: _Message(
                  title: 'User not found',
                  message: 'Choose another user.',
                ),
              ),
              FilledButton(
                onPressed: () => context.go('/admin/users'),
                style: FilledButton.styleFrom(
                  backgroundColor: _purple,
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text('Back to User Directory'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? _purple : Colors.black54,
            ),
            const SizedBox(width: 12),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class _PageTitle extends StatelessWidget {
  const _PageTitle({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back)),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
