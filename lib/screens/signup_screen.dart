import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chargex/services/auth_service.dart';
import 'package:chargex/services/location_service.dart';
import 'package:chargex/utils/show_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart'; // <-- THIS IMPORT IS NEEDED
import 'package:provider/provider.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controllers for all your new fields
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _vehicleBrandController = TextEditingController();
  final _vehicleModelController = TextEditingController();

  String? _selectedVehicleType = '4-wheeler'; // Default value

  @override
  void dispose() {
    // Dispose all controllers to prevent memory leaks
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _vehicleBrandController.dispose();
    _vehicleModelController.dispose();
    super.dispose();
  }

  // --- NEW FUNCTION TO SHOW THE DIALOG ---
  void _showEnableLocationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Services Disabled'),
        content: const Text(
            'To continue, please enable location services on your device.'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text('Open Settings'),
            onPressed: () {
              // This opens the phone's location settings page
              Geolocator.openLocationSettings();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  // --- UPDATED SIGN UP FUNCTION ---
  void _handleSignUp() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      // Get all our services from Provider
      final authService = Provider.of<AuthService>(context, listen: false);
      final locationService =
      Provider.of<LocationService>(context, listen: false);

      try {
        // --- 1. Get User Location (as requested) ---
        final GeoPoint? location = await locationService.getCurrentLocation();
        if (location == null) {
          // This should not happen if permissions are granted, but as a fallback.
          throw Exception('Could not get your location.');
        }

        // --- 2. Create the Vehicle Data ---
        Map<String, dynamic> vehicleDetails = {
          'type': _selectedVehicleType,
          'brand': _vehicleBrandController.text.trim(),
          'model': _vehicleModelController.text.trim(),
        };

        // --- 3. Call AuthService to Sign Up ---
        final error = await authService.signUpWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          location: location,
          vehicleData: vehicleDetails,
        );

        // --- 4. Handle results ---
        if (error != null) {
          // Show Firebase error
          throw Exception(error);
        } else {
          // Success! Pop the screen to return to the Login page.
          // The AuthWrapper will then auto-navigate to the ProfileScreen.
          if (mounted) {
            showSnackBar(context, "Account created successfully!");
            Navigator.of(context).pop();
          }
        }
      } on LocationServiceDisabledException { // <-- CATCH THE SPECIFIC ERROR
        // This is what you wanted! Show the dialog instead of the snackbar.
        if (mounted) _showEnableLocationDialog();
      } catch (e) {
        // Show any other error (like "permission denied")
        if (mounted) showSnackBar(context, e.toString());
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Tell us about yourself',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),

                // --- User Details ---
                _buildSectionTitle('Account Details'),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Full Name'),
                  validator: (v) => v!.isEmpty ? 'Enter your name' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) =>
                  v!.isEmpty || !v.contains('@')
                      ? 'Enter a valid email'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                      labelText: 'Phone Number (e.g., +91...)'),
                  keyboardType: TextInputType.phone,
                  validator: (v) =>
                  v!.isEmpty ? 'Enter your phone number' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration:
                  const InputDecoration(labelText: 'Password (min. 6 chars)'),
                  obscureText: true,
                  validator: (v) =>
                  v!.length < 6 ? 'Password must be 6+ chars' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration:
                  const InputDecoration(labelText: 'Confirm Password'),
                  obscureText: true,
                  validator: (v) {
                    if (v != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // --- Vehicle Details (as requested) ---
                _buildSectionTitle('Vehicle Details'),
                DropdownButtonFormField<String>(
                  value: _selectedVehicleType,
                  decoration: const InputDecoration(labelText: 'Vehicle Type'),
                  items: ['2-wheeler', '4-wheeler']
                      .map((type) => DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedVehicleType = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _vehicleBrandController,
                  decoration: const InputDecoration(
                      labelText: 'Vehicle Brand (e.g., Tata, Ola)'),
                  validator: (v) => v!.isEmpty ? 'Enter vehicle brand' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _vehicleModelController,
                  decoration: const InputDecoration(
                      labelText: 'Vehicle Model (e.g., Nexon EV, S1 Pro)'),
                  validator: (v) => v!.isEmpty ? 'Enter vehicle model' : null,
                ),
                const SizedBox(height: 32),

                // --- Location Info (as requested) ---
                _buildSectionTitle('Location'),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.indigo.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.indigoAccent)),
                  child: const Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          color: Colors.indigoAccent),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'We need your location to find nearby stations. You will be asked for permission.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Sign Up Button
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                  onPressed: _handleSignUp,
                  child: const Text('Create Account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper widget to make section titles
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.indigoAccent),
      ),
    );
  }
}

