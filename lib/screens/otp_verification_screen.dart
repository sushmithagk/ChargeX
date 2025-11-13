import 'package:chargex/services/auth_service.dart';
import 'package:chargex/utils/show_snack_bar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chargex/screens/login_screen.dart';


class OtpVerificationScreen extends StatefulWidget {
  final String email;
  final String otp;
  final String name;
  final String phone;
  final String password;
  final GeoPoint location;
  final Map<String, dynamic> vehicleData;

  const OtpVerificationScreen({
    super.key,
    required this.email,
    required this.otp,
    required this.name,
    required this.phone,
    required this.password,
    required this.location,
    required this.vehicleData,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.trim() != widget.otp) {
      showSnackBar(context, "Invalid OTP. Try again.");
      return;
    }

    setState(() => _isLoading = true);

    final authService = context.read<AuthService>();

    // Step 1️⃣ Create user in Firebase Auth
    String? error = await authService.signUpWithEmail(
      email: widget.email,
      password: widget.password,
      name: widget.name,
      phone: widget.phone,
      location: widget.location,
      vehicleData: widget.vehicleData,
    );

    setState(() => _isLoading = false);

    // Step 2️⃣ If signup failed
    if (error != null) {
      showSnackBar(context, error);
      return;
    }

    // Step 3️⃣ ✅ Success → redirect to LoginScreen
    if (mounted) {
      showSnackBar(context, "Account created successfully! Please log in.");
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false, // Removes all previous routes
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Verify Email OTP")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Enter the OTP sent to your Gmail",
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Enter 6-digit OTP",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _isLoading ? null : _verifyOtp,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Verify & Create Account"),
            ),
          ],
        ),
      ),
    );
  }
}
