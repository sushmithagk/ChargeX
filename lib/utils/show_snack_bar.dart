import 'package:flutter/material.dart';

/*
  This is a simple helper function.
  It shows a "snackbar" (a little popup) at the bottom
  of the screen to show error messages.
*/
void showSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.redAccent,
      duration: const Duration(seconds: 3),
    ),
  );
}
