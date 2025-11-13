import 'package:chargex/models/user_model.dart';
import 'package:chargex/services/auth_service.dart';
import 'package:chargex/services/database_service.dart';
import 'package:chargex/services/location_service.dart';
import 'package:chargex/utils/show_snack_bar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' hide LocationServiceDisabledException;
import 'package:provider/provider.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();

  String _vehicleType = '2-wheeler';
  GeoPoint? _location;

  bool _isLoading = false;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();

    // Prefill details from Firebase user (if available)
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _nameController.text = user.displayName ?? '';
      _emailController.text = user.email ?? '';
      _phoneController.text = user.phoneNumber ?? '';
    }
  }

  Future<void> _getUserLocation() async {
    setState(() => _isLocating = true);

    final locationService = context.read<LocationService>();

    try {
      final position = await locationService.getCurrentLocation();
      setState(() {
        _location = GeoPoint(position.latitude, position.longitude);
        _isLocating = false;
      });
      showSnackBar(context, "Location captured successfully!");
    } on LocationServiceDisabledException {
      await _showEnableLocationDialog();
    } catch (e) {
      showSnackBar(context, "Error fetching location: $e");
    } finally {
      setState(() => _isLocating = false);
    }
  }

  Future<void> _showEnableLocationDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Location Services Disabled'),
        content:
        const Text('Please enable location services to update your profile.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              Geolocator.openLocationSettings();
              Navigator.pop(context);
            },
            child: const Text('Open Settings',
                style: TextStyle(color: Colors.indigoAccent)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (_location == null) {
      showSnackBar(context, "Please capture your location first.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = context.read<AuthService>();
      final dbService = context.read<DatabaseService>();
      final user = authService.currentUser;

      if (user == null) {
        showSnackBar(context, "No logged-in user found.");
        return;
      }

      // Create an updated user model
      final updatedUser = UserModel(
        uid: user.uid,
        displayName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        vehicleType: _vehicleType,
        vehicleBrand: _brandController.text.trim(),
        vehicleModel: _modelController.text.trim(),
        lastKnownLocation: _location!,
        createdAt: Timestamp.now(),
      );

      // Save to Firestore
      await dbService.updateUser(updatedUser);

      if (mounted) {
        showSnackBar(context, "Profile updated successfully!");
        Navigator.pop(context); // Go back to profile screen
      }
    } catch (e) {
      showSnackBar(context, "Error updating profile: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Complete Your Profile"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "We need a few more details to personalize your experience.",
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 20),

              // --- Personal Info ---
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full Name *'),
                validator: (v) =>
                v == null || v.isEmpty ? "Name is required" : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email *'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.isEmpty) return "Email is required";
                  if (!v.contains('@')) return "Enter a valid email";
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _phoneController,
                decoration:
                const InputDecoration(labelText: 'Phone Number *', prefixText: '+91 '),
                keyboardType: TextInputType.phone,
                validator: (v) =>
                v == null || v.length < 10 ? "Enter valid number" : null,
              ),
              const SizedBox(height: 24),

              // --- Vehicle Info ---
              const Text("Vehicle Details",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                initialValue: _vehicleType,
                items: ['2-wheeler', '4-wheeler']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (val) => setState(() => _vehicleType = val!),
                decoration: const InputDecoration(labelText: 'Vehicle Type *'),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _brandController,
                decoration:
                const InputDecoration(labelText: 'Vehicle Brand *'),
                validator: (v) =>
                v == null || v.isEmpty ? "Brand is required" : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _modelController,
                decoration:
                const InputDecoration(labelText: 'Vehicle Model *'),
                validator: (v) =>
                v == null || v.isEmpty ? "Model is required" : null,
              ),
              const SizedBox(height: 24),

              // --- Location ---
              const Text("Your Location",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
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
                            ? "Location not captured yet."
                            : "Location captured!",
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
                        child:
                        CircularProgressIndicator(strokeWidth: 2))
                        : IconButton(
                      icon: const Icon(Icons.my_location,
                          color: Colors.indigoAccent),
                      onPressed: _getUserLocation,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // --- Save Button ---
              ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                child: _isLoading
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
                    : const Text("Save Profile"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}