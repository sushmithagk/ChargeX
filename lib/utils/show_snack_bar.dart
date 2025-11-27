import 'package:flutter/material.dart';

void showSnackBar(
    BuildContext context,
    String message, {
      bool isError = true, // 🔴 default red
    }) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: isError ? Colors.red : Colors.green, // 🟢 GREEN on success
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ),
  );
}
