import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chargex/services/auth_service.dart';
import 'package:chargex/services/database_service.dart';
import 'package:chargex/utils/show_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Import the location service
import 'package:chargex/services/location_service.dart';

// Import the geolocator package, but HIDE the conflicting class name
import 'package:geolocator/geolocator.dart'
    hide LocationServiceDisabledException;

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Form Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
  TextEditingController();
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  String _vehicleType = '2-wheeler'; // Default dropdown value
  GeoPoint? _location; // To store the user's location

  bool _isLoading = false;
  bool _isLocating = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  /// Asks for permission and gets the user's current location
  Future<void> _getUserLocation() async {
    setState(() {
      _isLocating = true;
    });

    final locationService =
    Provider.of<LocationService>(context, listen: false);

    try {
      // 1. Get location. This will throw an error if not enabled/permitted.
      final position = await locationService.getCurrentLocation();

      // 2. If successful, save it as a GeoPoint
      setState(() {
        _location = GeoPoint(position.latitude, position.longitude);
        _isLocating = false;
      });
      if (mounted) {
        showSnackBar(context, "Location captured!");
      }
    } on LocationServiceDisabledException {
      // 3. CATCH THE SPECIFIC ERROR from our location_service.dart
      if (mounted) {
        // And call the dialog function (which we added below)
        await _showEnableLocationDialog();
      }
    } catch (e) {
      // 4. Catch any other errors (like permission denied)
      if (mounted) {
        showSnackBar(context, e.toString());
      }
    } finally {
      // 5. Always stop the loading indicator
      if (mounted) {
        setState(() {
          _isLocating = false;
        });
      }
    }
  }

  /// Shows the dialog to enable location services
  Future<void> _showEnableLocationDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Location Services Disabled'),
        content: const Text(
            'Please enable location services to find nearby stations.'),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text('Open Settings',
                style: TextStyle(color: Colors.indigoAccent)),
            onPressed: () {
              Geolocator.openLocationSettings();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  /// Handles the entire sign-up process
  Future<void> _handleSignUp() async {
    // 1. Validate the form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 2. Check that location has been captured
    if (_location == null) {
      showSnackBar(context, "Please capture your location first.");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // 3. Get the Auth service
    final authService = Provider.of<AuthService>(context, listen: false);

    // 4. Create the Vehicle Data Map
    Map<String, dynamic> vehicleData = {
      'type': _vehicleType,
      'brand': _brandController.text.trim(),
      'model': _modelController.text.trim(),
    };

    // 5. Call the signUpWithEmail function
    String? error = await authService.signUpWithEmail(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      location: _location!, // We know _location is not null here
      vehicleData: vehicleData,
    );

    setState(() {
      _isLoading = false;
    });

    // 6. Handle the response
    if (error == null) {
      // Success!
      showSnackBar(context, "Account created successfully!");
      if (mounted) {
        // Pop back to the Login Screen
        Navigator.of(context).pop();
      }
    } else {
      // Failure
      if (mounted) {
        showSnackBar(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- Personal Details ---
                const Text('Personal Details',
                    style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Full Name *'),
                  validator: (value) =>
                  value == null || value.isEmpty ? 'Name is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email *'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Email is required';
                    }
                    if (!value.contains('@') || !value.contains('.')) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                      labelText: 'Phone Number *', prefixText: '+91 '),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Phone number is required';
                    }
                    if (value.length < 10) {
                      return 'Enter a valid 10-digit number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password (min. 6 chars) *',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                  ),
                  obscureText: !_isPasswordVisible,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password *',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isConfirmPasswordVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _isConfirmPasswordVisible =
                          !_isConfirmPasswordVisible;
                        });
                      },
                    ),
                  ),
                  obscureText: !_isConfirmPasswordVisible,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // --- Vehicle Details ---
                const Text('Vehicle Details',
                    style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _vehicleType,
                  decoration: const InputDecoration(labelText: 'Vehicle Type *'),
                  items: ['2-wheeler', '4-wheeler']
                      .map((type) => DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _vehicleType = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _brandController,
                  decoration: const InputDecoration(
                      labelText: 'Vehicle Brand (e.g., Tata, Ola) *'),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Brand is required'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _modelController,
                  decoration: const InputDecoration(
                      labelText: 'Vehicle Model (e.g., Nexon EV) *'),
                  validator: (value) =>
                  value == null || value.isEmpty ? 'Model is required' : null,
                ),
                const SizedBox(height: 24),

                // --- Location ---
                const Text('Your Location',
                    style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          _location == null
                              ? 'We need your location to find nearby stations.'
                              : 'Location captured successfully!',
                          style: TextStyle(
                            color: _location == null
                                ? Colors.grey[400]
                                : Colors.green[400],
                          ),
                        ),
                      ),
                      _isLocating
                          ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : IconButton(
                        icon: const Icon(Icons.my_location,
                            color: Colors.indigoAccent),
                        onPressed: _getUserLocation,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                // --- Create Account Button ---
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleSignUp,
                  child: _isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                      : const Text('Create Account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


