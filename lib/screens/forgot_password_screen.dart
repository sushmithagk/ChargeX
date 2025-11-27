// lib/screens/forgot_password_screen.dart
import 'package:chargex/utils/show_snack_bar.dart';
import 'package:chargex/services/email_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'forgot_password_otp_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _isSending = false;

  Future<void> _sendOtp() async {
    String email = _emailController.text.trim();

    if (email.isEmpty) {
      showSnackBar(context, "Enter your email address.");
      return;
    }

    setState(() => _isSending = true);

    try {
      // 🔍 STEP 1: Check sign-in methods
      final methods = await FirebaseAuth.instance
          .fetchSignInMethodsForEmail(email);

      // ❌ Google account → block reset
      if (methods.contains("google.com")) {
        setState(() => _isSending = false);
        showSnackBar(
          context,
          "This account uses Google Sign-In.\nPassword reset is not available.",
          isError: true,
        );
        return;
      }

      // 🔍 If methods list is empty → no user exists
      if (methods.isEmpty) {
        setState(() => _isSending = false);
        showSnackBar(context, "No user found with this email.");
        return;
      }

      // STEP 2: Send OTP to email
      final otp = await EmailService.sendOtpEmail(email);

      setState(() => _isSending = false);

      if (otp == null) {
        showSnackBar(context, "Failed to send OTP. Try again.");
        return;
      }

      // STEP 3: Go to OTP verification screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ForgotPasswordOtpScreen(
            email: email,
            otp: otp,
          ),
        ),
      );
    } catch (e) {
      setState(() => _isSending = false);
      showSnackBar(context, "Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Forgot Password")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Enter your registered email.\nWe will send a 6-digit OTP.",
              style: TextStyle(fontSize: 16, color: Colors.white70),
            ),
            const SizedBox(height: 24),

            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "Email Address"),
              keyboardType: TextInputType.emailAddress,
            ),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: _isSending ? null : _sendOtp,
              child: _isSending
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Send OTP"),
            ),
          ],
        ),
      ),
    );
  }
}
