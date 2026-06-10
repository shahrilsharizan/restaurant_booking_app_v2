import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/auth_session_provider.dart';
import 'auth_form_widgets.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({
    super.key,
    this.loginRoute = '/login',
    this.successRoute = '/packages',
  });

  final String loginRoute;
  final String successRoute;

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _repeatPasswordController = TextEditingController();

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _repeatPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authSessionProvider, (previous, next) {
      next.whenOrNull(
        data: (session) {
          if (session != null) {
            context.go(widget.successRoute);
          }
        },
        error: (error, _) => _showError(context, error),
      );
    });

    final sessionState = ref.watch(authSessionProvider);
    final isLoading = sessionState.isLoading;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _SignUpTitle(),
                    const SizedBox(height: 56),
                    AuthTextField(
                      controller: _fullNameController,
                      label: 'Full name',
                      hintText: 'Name Surname',
                      icon: Icons.badge_outlined,
                      textInputAction: TextInputAction.next,
                      validator: (value) => _required(value, 'Full name'),
                    ),
                    const SizedBox(height: 18),
                    AuthTextField(
                      controller: _emailController,
                      label: 'Enter your e-mail',
                      hintText: 'email@email.com',
                      icon: Icons.mail_outline,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: _validateEmail,
                    ),
                    const SizedBox(height: 18),
                    AuthTextField(
                      controller: _usernameController,
                      label: 'Create a username',
                      hintText: 'username',
                      icon: Icons.person_outline,
                      textInputAction: TextInputAction.next,
                      validator: (value) => _required(value, 'Username'),
                    ),
                    const SizedBox(height: 18),
                    AuthTextField(
                      controller: _passwordController,
                      label: 'Create your password',
                      hintText: '************',
                      icon: Icons.key,
                      obscureText: true,
                      textInputAction: TextInputAction.next,
                      validator: _validatePassword,
                    ),
                    const SizedBox(height: 18),
                    AuthTextField(
                      controller: _repeatPasswordController,
                      label: 'Repeat password',
                      hintText: '************',
                      icon: Icons.lock,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      validator: _validateRepeatedPassword,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 26),
                    AuthPrimaryButton(
                      label: 'Sign up',
                      isLoading: isLoading,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: isLoading
                          ? null
                          : () => context.go(widget.loginRoute),
                      child: const Text('Already have an account? Log in'),
                    ),
                    TextButton(
                      onPressed: isLoading ? null : _continueAsGuest,
                      child: const Text('Continue as guest'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    await ref
        .read(authSessionProvider.notifier)
        .signUp(
          fullName: _fullNameController.text,
          username: _usernameController.text,
          email: _emailController.text,
          password: _passwordController.text,
        );
  }

  void _continueAsGuest() {
    ref.read(authSessionProvider.notifier).continueAsGuest();
    context.go(widget.successRoute);
  }

  String? _validateRepeatedPassword(String? value) {
    final repeatedPassword = value ?? '';
    if (repeatedPassword.isEmpty) {
      return 'Repeat password is required';
    }
    if (repeatedPassword != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }
}

class _SignUpTitle extends StatelessWidget {
  const _SignUpTitle();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Sign up',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Create an account',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: Colors.black54),
        ),
      ],
    );
  }
}

String? _required(String? value, String label) {
  if ((value ?? '').trim().isEmpty) {
    return '$label is required';
  }
  return null;
}

String? _validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) {
    return 'Email is required';
  }
  if (!email.contains('@')) {
    return 'Enter a valid email';
  }
  return null;
}

String? _validatePassword(String? value) {
  if ((value ?? '').length < 6) {
    return 'Password must be at least 6 characters';
  }
  return null;
}

void _showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(error.toString())));
}
