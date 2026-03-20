import 'dart:math';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';


class EmailService {
  // 🔹 Replace these with your actual EmailJS credentials
  static String get _serviceId => dotenv.env['EMAILJS_SERVICE_ID']!;
  static String get _templateId => dotenv.env['EMAILJS_TEMPLATE_ID']!;
  static String get _publicKey => dotenv.env['EMAILJS_PUBLIC_KEY']!;

  /// Sends OTP email and returns the generated OTP
  static Future<String?> sendOtpEmail(String email) async {
    try {
      final otp = (100000 + Random().nextInt(900000)).toString();

      final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
      final response = await http.post(
        url,
        headers: {
          'origin': 'http://localhost',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'service_id': _serviceId,
          'template_id': _templateId,
          'user_id': _publicKey,
          'template_params': {
            'to_email': email,
            'otp': otp,
          },
        }),
      );

      if (response.statusCode == 200) {
        print('✅ OTP sent to $email');
        return otp;
      } else {
        print('❌ Failed to send OTP: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error sending OTP: $e');
      return null;
    }
  }
}
