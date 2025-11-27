import 'dart:async';
import 'package:chargex/utils/show_snack_bar.dart';
import 'package:flutter/material.dart';
import 'reset_new_password_screen.dart';

class ForgotPasswordOtpScreen extends StatefulWidget {
  final String email;
  final String otp;

  const ForgotPasswordOtpScreen({
    super.key,
    required this.email,
    required this.otp,
  });

  @override
  State<ForgotPasswordOtpScreen> createState() =>
      _ForgotPasswordOtpScreenState();
}

class _ForgotPasswordOtpScreenState extends State<ForgotPasswordOtpScreen> {
  List<TextEditingController> otpControllers =
  List.generate(6, (_) => TextEditingController());

  int remainingSeconds = 45;
  Timer? countdownTimer;
  bool canResend = false;
  String? newOtp;

  @override
  void initState() {
    super.initState();
    startTimer();
  }

  void startTimer() {
    remainingSeconds = 45;
    canResend = false;

    countdownTimer?.cancel();
    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingSeconds == 0) {
        timer.cancel();
        setState(() => canResend = true);
      } else {
        setState(() => remainingSeconds--);
      }
    });
  }

  String getEnteredOtp() {
    return otpControllers.map((controller) => controller.text).join();
  }

  Future<void> _verifyOtp() async {
    String enteredOtp = getEnteredOtp();

    if (enteredOtp.length != 6) {
      showSnackBar(context, "Enter all 6 digits");
      return;
    }

    final validOtp = newOtp ?? widget.otp;

    if (enteredOtp != validOtp) {
      showSnackBar(context, "Invalid OTP");
      return;
    }

    // OTP Verified → Go to Reset Password screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResetNewPasswordScreen(email: widget.email),
      ),
    );
  }

  Future<void> _resendOtp() async {
    if (!canResend) return;

    // Generate new OTP:
    newOtp = (100000 + (DateTime.now().millisecondsSinceEpoch % 900000))
        .toString();

    // TODO: Send OTP through EmailService (you already have this):
    // await EmailService.sendOtpEmail(widget.email);

    showSnackBar(
      context,
      "OTP resent successfully!",
      isError: false,
    );

    startTimer();
  }

  Widget _otpBox(int index) {
    return SizedBox(
      width: 48,
      height: 55,
      child: TextField(
        controller: otpControllers[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          counterText: "",
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.white30),
            borderRadius: BorderRadius.circular(10),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.blueAccent),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onChanged: (value) {
          if (value.isNotEmpty && index < 5) {
            FocusScope.of(context).nextFocus();
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    countdownTimer?.cancel();
    for (var c in otpControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Verify OTP")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              "Enter the 6-digit OTP sent to\n${widget.email}",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.white70),
            ),
            const SizedBox(height: 24),

            // OTP BOXES
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(6, (i) => _otpBox(i)),
            ),

            const SizedBox(height: 20),

            Text(
              canResend
                  ? "Didn’t receive OTP?"
                  : "Resend in 00:${remainingSeconds.toString().padLeft(2, '0')}",
              style: const TextStyle(color: Colors.white70),
            ),

            TextButton(
              onPressed: canResend ? _resendOtp : null,
              child: Text(
                "Resend OTP",
                style: TextStyle(
                  color: canResend ? Colors.blueAccent : Colors.grey,
                  fontSize: 16,
                ),
              ),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _verifyOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5B6BFF),
                  foregroundColor: Colors.white,
                ),
                child: const Text(
                  "Verify OTP",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
