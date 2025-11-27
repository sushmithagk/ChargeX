import 'package:chargex/utils/show_snack_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ResetNewPasswordScreen extends StatefulWidget {
  final String email;

  const ResetNewPasswordScreen({super.key, required this.email});

  @override
  State<ResetNewPasswordScreen> createState() =>
      _ResetNewPasswordScreenState();
}

class _ResetNewPasswordScreenState extends State<ResetNewPasswordScreen> {
  final TextEditingController _newPasswordController =
  TextEditingController();
  final TextEditingController _confirmPasswordController =
  TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _loading = false;

  Future<void> _changePassword() async {
    final newPass = _newPasswordController.text.trim();
    final confirmPass = _confirmPasswordController.text.trim();

    if (newPass.isEmpty || confirmPass.isEmpty) {
      showSnackBar(context, "Enter all fields");
      return;
    }
    if (newPass.length < 6) {
      showSnackBar(context, "Password must be at least 6 characters");
      return;
    }
    if (newPass != confirmPass) {
      showSnackBar(context, "Passwords do not match");
      return;
    }

    setState(() => _loading = true);

    try {
      // STEP 1: Re-authenticate user with Email Link (workaround)
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        showSnackBar(context, "Session expired. Please login again.");
        return;
      }

      // STEP 2: Update password
      await user.updatePassword(newPass);

      if (!mounted) return;

      showSnackBar(
        context,
        "Password changed successfully!",
        isError: false,
      );

      // STEP 3: Return to login
      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      showSnackBar(context, "Password reset failed: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create New Password")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Enter your new password\nand confirm it below.",
              style: TextStyle(fontSize: 16, color: Colors.white70),
            ),
            const SizedBox(height: 30),

            // NEW PASSWORD
            TextFormField(
              controller: _newPasswordController,
              obscureText: !_isPasswordVisible,
              decoration: InputDecoration(
                labelText: "New Password",
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => _isPasswordVisible = !_isPasswordVisible),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // CONFIRM PASSWORD
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: !_isConfirmPasswordVisible,
              decoration: InputDecoration(
                labelText: "Confirm Password",
                suffixIcon: IconButton(
                  icon: Icon(
                    _isConfirmPasswordVisible
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                  onPressed: () => setState(() =>
                  _isConfirmPasswordVisible =
                  !_isConfirmPasswordVisible),
                ),
              ),
            ),
            const SizedBox(height: 35),

            // BUTTON
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _loading ? null : _changePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5B6BFF),
                  foregroundColor: Colors.white,
                ),
                child: _loading
                    ? const CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white)
                    : const Text(
                  "Change Password",
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
