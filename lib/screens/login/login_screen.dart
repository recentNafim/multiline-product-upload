import 'package:flutter/material.dart';

import '../../services/auth_session.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await AuthSession.instance.login(
      id: _idController.text,
      password: _passwordController.text,
    );
    // Never retain password after an authentication attempt.
    if (mounted) _passwordController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final session = AuthSession.instance;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F3FB),
      body: Center(child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Card(elevation: 3, child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Form(key: _formKey, child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.inventory_2_outlined, size: 56, color: Color(0xFF614B8D)),
                const SizedBox(height: 14),
                Text('MLIL Product Upload',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text('Sign in with your HRIS User ID and password',
                  textAlign: TextAlign.center),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _idController,
                  autofillHints: const [AutofillHints.username],
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'User ID / Staff ID',
                    prefixIcon: Icon(Icons.badge_outlined),
                    border: OutlineInputBorder()),
                  validator: (value) => (int.tryParse((value ?? '').trim()) ?? 0) <= 0
                      ? 'Enter your numeric User ID' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_showPassword,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => session.busy ? null : _submit(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      tooltip: _showPassword ? 'Hide password' : 'Show password',
                      icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _showPassword = !_showPassword)),
                    border: const OutlineInputBorder()),
                  validator: (value) => (value ?? '').isEmpty ? 'Enter your password' : null,
                ),
                if (session.error != null) ...[
                  const SizedBox(height: 14),
                  Text(session.error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: session.busy ? null : _submit,
                  icon: session.busy ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.login),
                  label: Text(session.busy ? 'Signing in...' : 'Sign In'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                ),
                const SizedBox(height: 12),
                const Text('Your HRIS password is never saved in this browser.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 12,
                  color: Colors.black54)),
              ],
            )),
          )),
        ),
      )),
    );
  }
}
