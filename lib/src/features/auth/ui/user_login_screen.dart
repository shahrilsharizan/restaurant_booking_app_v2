import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/auth_session_provider.dart';
import '../data/auth_repository.dart';
import 'auth_form_widgets.dart';

class UserLoginScreen extends ConsumerStatefulWidget {
  const UserLoginScreen({
    super.key,
    this.signUpRoute = '/sign-up',
    this.adminLoginRoute = '/admin-login',
    this.successRoute = '/packages',
  });

  final String signUpRoute;
  final String adminLoginRoute;
  final String successRoute;

  @override
  ConsumerState<UserLoginScreen> createState() => _UserLoginScreenState();
}

class _UserLoginScreenState extends ConsumerState<UserLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  var _rememberMe = true;
  var _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authSessionProvider, (previous, next) {
      next.whenOrNull(
        data: (session) {
          if (session != null && session.role == UserRole.user) {
            context.go(widget.successRoute);
          }
        },
        error: (error, _) => _showError(context, error),
      );
    });

    final sessionState = ref.watch(authSessionProvider);
    final isLoading = sessionState.isLoading;

    return Scaffold(
      backgroundColor: authPageBackground,
      body: Stack(
        children: [
          const AuthWaveHeader(height: 270),
          Align(
            alignment: Alignment.bottomCenter,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 120, 24, 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 34, 24, 28),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _LoginTitle(title: 'Login'),
                        const SizedBox(height: 46),
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
                          controller: _passwordController,
                          label: 'Enter your password',
                          hintText: '************',
                          icon: _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          obscureText: _obscurePassword,
                          onSuffixPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          textInputAction: TextInputAction.done,
                          validator: _validatePassword,
                          onFieldSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: 18),
                        _LoginOptionsRow(
                          rememberMe: _rememberMe,
                          onForgotPassword: _sendPasswordReset,
                          onRememberChanged: isLoading
                              ? null
                              : (value) {
                                  setState(() => _rememberMe = value ?? false);
                                },
                        ),
                        const SizedBox(height: 28),
                        AuthPrimaryButton(
                          label: 'Log in',
                          isLoading: isLoading,
                          onPressed: _submit,
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: isLoading
                              ? null
                              : () => context.go(widget.signUpRoute),
                          child: const Text('Join now'),
                        ),
                        TextButton(
                          onPressed: isLoading
                              ? null
                              : () => context.go(widget.adminLoginRoute),
                          child: const Text('Admin login'),
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
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    await ref
        .read(authSessionProvider.notifier)
        .signInAsUser(
          email: _emailController.text,
          password: _passwordController.text,
        );
  }

  void _continueAsGuest() {
    ref.read(authSessionProvider.notifier).continueAsGuest();
    context.go(widget.successRoute);
  }

  Future<void> _sendPasswordReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showError(context, 'Enter your email first.');
      return;
    }

    await ref.read(authSessionProvider.notifier).sendPasswordResetEmail(email);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent.')),
      );
    }
  }
}

class _LoginTitle extends StatelessWidget {
  const _LoginTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Enter your details to continue',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w800, color: Colors.black),
        ),
      ],
    );
  }
}

class _LoginOptionsRow extends StatelessWidget {
  const _LoginOptionsRow({
    required this.rememberMe,
    required this.onForgotPassword,
    required this.onRememberChanged,
  });

  final bool rememberMe;
  final VoidCallback onForgotPassword;
  final ValueChanged<bool?>? onRememberChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Checkbox(
          value: rememberMe,
          activeColor: Colors.grey,
          onChanged: onRememberChanged,
        ),
        const Text(
          'Remember me',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
        ),
        const Spacer(),
        TextButton(
          onPressed: onForgotPassword,
          child: const Text(
            'Forgot password',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
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
