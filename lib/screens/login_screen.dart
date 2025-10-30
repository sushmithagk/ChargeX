import 'package:chargex/screens/signup_screen.dart';
import 'package:chargex/services/auth_service.dart';
import 'package:chargex/utils/show_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // This function handles the Email/Password Login
  void _handleEmailLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() { _isLoading = true; });

      // Get the AuthService from our Provider
      final authService = Provider.of<AuthService>(context, listen: false);

      // Try to sign in
      final error = await authService.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      // If there was an error, show it
      if (error != null) {
        // This is your "if not show invalid password" step
        if (mounted) showSnackBar(context, error);
      }
      // On success, the AuthWrapper will automatically navigate to ProfileScreen

      if (mounted) setState(() { _isLoading = false; });
    }
  }

  // TODO: This is where you will add Google Sign-In logic
  void _handleGoogleLogin() {
    showSnackBar(context, "Google Sign-In is not implemented yet.");
  }

  // TODO: This is where you will add Phone/OTP logic
  void _handlePhoneLogin() {
    showSnackBar(context, "Phone Sign-In is not implemented yet.");
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo and Title
                  const Icon(Icons.ev_station, size: 80, color: Colors.indigoAccent),
                  const SizedBox(height: 24),
                  const Text(
                    'Welcome to ChargeX',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to find your charge',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey[400]),
                  ),
                  const SizedBox(height: 40),

                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) =>
                    value!.isEmpty || !value.contains('@') ? 'Enter a valid email' : null,
                  ),
                  const SizedBox(height: 16),

                  // Password Field
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline)),
                    obscureText: true,
                    validator: (value) =>
                    value!.length < 6 ? 'Password must be 6+ chars' : null,
                  ),
                  const SizedBox(height: 24),

                  // Login Button
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                    onPressed: _handleEmailLogin,
                    child: const Text('Login'),
                  ),
                  const SizedBox(height: 24),

                  // "Or continue with"
                  const Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('OR', style: TextStyle(color: Colors.grey)),
                      ),
                      Expanded(child: Divider(color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Google and Phone Buttons (as you specified)
                  Row(
                    children: [
                      // Google Sign-In
                      Expanded(
                        child: OutlinedButton.icon(
                          // TODO: Replace this with a Google logo
                          icon: const Icon(Icons.g_mobiledata, size: 28),
                          label: const Text('Google'),
                          onPressed: _handleGoogleLogin, // Disabled for now
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: Colors.grey),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Phone Sign-In
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.phone),
                          label: const Text('Phone'),
                          onPressed: _handlePhoneLogin, // Disabled for now
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: Colors.grey),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Sign Up Link (as you specified)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account? "),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => const SignUpScreen()),
                          );
                        },
                        child: const Text(
                          'Sign Up',
                          style: TextStyle(
                            color: Colors.indigoAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
