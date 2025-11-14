import 'package:chargex/models/user_model.dart';
import 'package:chargex/screens/profile_screen.dart';
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

  /// BRAND / MODEL Controllers
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();

  String _vehicleType = '2-wheeler';
  String? _selectedBrand;
  String? _selectedModel;

  bool _isOtherBrand = false;
  bool _isOtherModel = false;

  GeoPoint? _location;
  bool _isLoading = false;
  bool _isLocating = false;

  // ---------------------------------------------------------------------
  // VEHICLE BRAND + MODEL DATA
  // ---------------------------------------------------------------------

  final Map<String, List<String>> vehicleBrands = {
    '2-wheeler': [
      'Ola Electric',
      'Ather Energy',
      'TVS Motor',
      'Bajaj',
      'Hero Electric',
      'Other'
    ],
    '4-wheeler': [
      'Tata Motors',
      'Mahindra',
      'MG Motor',
      'BYD',
      'Hyundai',
      'Kia',
      'Other'
    ],
  };

  final Map<String, List<String>> vehicleModels = {
    // 2-wheelers
    'Ola Electric': ['S1 Pro', 'S1 Pro+', 'S1 X', 'S1 Air'],
    'Ather Energy': ['450X', '450S', 'Rizta'],
    'TVS Motor': ['iQube', 'iQube S', 'iQube ST'],
    'Bajaj': ['Chetak Electric'],
    'Hero Electric': ['Vida VX2'],

    // 4-wheelers
    'Tata Motors': [
      'Nexon EV',
      'Tiago EV',
      'Punch EV',
      'Tigor EV',
      'Curvv EV',
      'Harrier EV'
    ],
    'Mahindra': ['BE 6', 'XUV 400', 'XEV 9e'],
    'MG Motor': ['ZS EV', 'Windsor EV'],
    'BYD': ['Atto 3', 'SEAL'],
    'Hyundai': ['Kona Electric', 'IONIQ 5'],
    'Kia': ['EV6'],
  };

  // ---------------------------------------------------------------------
  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _nameController.text = user.displayName ?? '';
      _emailController.text = user.email ?? '';
      _phoneController.text = user.phoneNumber ?? '';
    }
  }

  // ---------------------------------------------------------------------
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

  // ---------------------------------------------------------------------
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

      final brand =
      _isOtherBrand ? _brandController.text.trim() : _selectedBrand!;
      final model =
      _isOtherModel ? _modelController.text.trim() : _selectedModel!;

      final updatedUser = UserModel(
        uid: user.uid,
        displayName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        vehicleType: _vehicleType,
        vehicleBrand: brand,
        vehicleModel: model,
        lastKnownLocation: _location!,
        createdAt: Timestamp.now(),
      );

      await dbService.updateUser(updatedUser);

      if (mounted) {
        showSnackBar(context, "Profile updated successfully!");

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
        );
      }
    } catch (e) {
      showSnackBar(context, "Error updating profile: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Complete Your Profile")),
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

              // ---------------------------------------------------------------------
              // PERSONAL DETAILS
              // ---------------------------------------------------------------------

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
                decoration: const InputDecoration(
                    labelText: 'Phone Number *', prefixText: '+91 '),
                keyboardType: TextInputType.phone,
                validator: (v) =>
                v == null || v.length < 10 ? "Enter valid number" : null,
              ),

              // ---------------------------------------------------------------------
              // VEHICLE DETAILS
              // ---------------------------------------------------------------------

              const SizedBox(height: 24),
              const Text("Vehicle Details",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              // VEHICLE TYPE
              DropdownButtonFormField<String>(
                value: _vehicleType,
                items: ['2-wheeler', '4-wheeler']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _vehicleType = value!;
                    _selectedBrand = null;
                    _selectedModel = null;
                    _isOtherBrand = false;
                    _isOtherModel = false;
                  });
                },
                decoration: const InputDecoration(labelText: 'Vehicle Type *'),
              ),
              const SizedBox(height: 16),

              // BRAND DROPDOWN
              DropdownButtonFormField<String>(
                value: _selectedBrand,
                decoration: const InputDecoration(labelText: 'Vehicle Brand *'),
                items: vehicleBrands[_vehicleType]!
                    .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedBrand = value;
                    _isOtherBrand = value == 'Other';
                    _selectedModel = null;
                    _isOtherModel = false;
                  });
                },
                validator: (v) {
                  if (!_isOtherBrand && (v == null || v.isEmpty)) {
                    return "Select brand";
                  }
                  return null;
                },
              ),

              if (_isOtherBrand)
                TextFormField(
                  controller: _brandController,
                  decoration: const InputDecoration(labelText: 'Enter Brand *'),
                  validator: (v) =>
                  v == null || v.isEmpty ? "Brand required" : null,
                ),

              const SizedBox(height: 16),

              // MODEL DROPDOWN
              if (!_isOtherBrand)
                DropdownButtonFormField<String>(
                  value: _selectedModel,
                  decoration:
                  const InputDecoration(labelText: 'Vehicle Model *'),
                  items: (vehicleModels[_selectedBrand] ?? ['Other'])
                      .map((m) =>
                      DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedModel = value;
                      _isOtherModel = value == 'Other';
                    });
                  },
                  validator: (v) {
                    if (!_isOtherModel && (v == null || v.isEmpty)) {
                      return "Select model";
                    }
                    return null;
                  },
                ),

              if (_isOtherModel)
                TextFormField(
                  controller: _modelController,
                  decoration:
                  const InputDecoration(labelText: 'Enter Model *'),
                  validator: (v) =>
                  v == null || v.isEmpty ? "Model required" : null,
                ),

              // ---------------------------------------------------------------------
              // LOCATION
              // ---------------------------------------------------------------------

              const SizedBox(height: 24),
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

              // ---------------------------------------------------------------------
              // SAVE BUTTON
              // ---------------------------------------------------------------------

              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                child: _isLoading
                    ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                    : const Text("Save Profile"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
