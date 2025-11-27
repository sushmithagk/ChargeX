// lib/screens/edit_profile_screen.dart
import 'package:chargex/models/user_model.dart';
import 'package:chargex/services/auth_service.dart';
import 'package:chargex/services/database_service.dart';
import 'package:chargex/services/location_service.dart';
import 'package:chargex/utils/show_snack_bar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart'
    hide LocationServiceDisabledException;
import 'package:provider/provider.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController(); // read-only
  final TextEditingController _phoneController = TextEditingController();

  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();

  String _vehicleType = '2-wheeler';
  String? _selectedBrand;
  String? _selectedModel;

  bool _isOtherBrand = false;
  bool _isOtherModel = false;

  GeoPoint? _location;
  bool _isLocating = false;
  bool _isSaving = false;
  bool _isLoadingUser = true;

  UserModel? _existingUser;

  // ---------------- VEHICLE DATA (same as signup) ----------------

  final Map<String, List<String>> vehicleBrands = {
    '2-wheeler': [
      'Ola Electric',
      'Ather Energy',
      'TVS Motor',
      'Bajaj',
      'Hero Electric',
      'Other',
    ],
    '4-wheeler': [
      'Tata Motors',
      'Mahindra',
      'MG Motor',
      'BYD',
      'Hyundai',
      'Kia',
      'Other',
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
      'Harrier EV',
    ],
    'Mahindra': ['BE 6', 'XUV 400', 'XEV 9e'],
    'MG Motor': ['ZS EV', 'Windsor EV'],
    'BYD': ['Atto 3', 'SEAL'],
    'Hyundai': ['Kona Electric', 'IONIQ 5'],
    'Kia': ['EV6'],
  };

  @override
  void initState() {
    super.initState();
    // Load user + auto capture location AFTER widget is built
    Future.microtask(_initScreen);
  }

  Future<void> _initScreen() async {
    try {
      final auth = context.read<AuthService>();
      final db = context.read<DatabaseService>();
      final user = auth.currentUser;

      if (user == null) {
        if (mounted) {
          showSnackBar(context, "No logged-in user found.");
          Navigator.pop(context);
        }
        return;
      }

      final userModel = await db.getUser(user.uid);
      if (!mounted) return;

      if (userModel == null) {
        showSnackBar(context, "User data not found.");
        Navigator.pop(context);
        return;
      }

      _existingUser = userModel;

      // Prefill fields from Firestore
      _nameController.text = userModel.displayName;
      _emailController.text = userModel.email;
      _phoneController.text = userModel.phoneNumber;

      _vehicleType = userModel.vehicleType.isNotEmpty
          ? userModel.vehicleType
          : '2-wheeler';

      // Vehicle brand & model handling with "Other"
      _setupBrandModelFromUser(userModel);

      // Existing saved location (if any)
      _location = userModel.lastKnownLocation;

      setState(() {
        _isLoadingUser = false;
      });

      // Auto capture current location (overwrites old)
      await _getUserLocation();
    } catch (e) {
      if (mounted) {
        showSnackBar(context, "Failed to load profile: $e");
        Navigator.pop(context);
      }
    }
  }

  void _setupBrandModelFromUser(UserModel user) {
    final savedBrand = user.vehicleBrand;
    final savedModel = user.vehicleModel;

    // BRAND
    final brandsForType = vehicleBrands[_vehicleType] ?? [];
    if (brandsForType.contains(savedBrand)) {
      _selectedBrand = savedBrand;
      _isOtherBrand = false;
    } else if (savedBrand.isNotEmpty) {
      _selectedBrand = 'Other';
      _isOtherBrand = true;
      _brandController.text = savedBrand;
    } else {
      _selectedBrand = null;
      _isOtherBrand = false;
    }

    // MODEL
    if (!_isOtherBrand && savedBrand.isNotEmpty) {
      final modelsForBrand = vehicleModels[savedBrand] ?? [];
      if (modelsForBrand.contains(savedModel)) {
        _selectedModel = savedModel;
        _isOtherModel = false;
      } else if (savedModel.isNotEmpty) {
        _selectedModel = 'Other';
        _isOtherModel = true;
        _modelController.text = savedModel;
      } else {
        _selectedModel = null;
        _isOtherModel = false;
      }
    } else if (_isOtherBrand && savedModel.isNotEmpty) {
      // Brand is "Other", model we already put in controller
      _isOtherModel = true;
    }
  }

  // --------------- LOCATION (auto + manual retry) -----------------

  Future<void> _getUserLocation() async {
    setState(() => _isLocating = true);
    final locationService = context.read<LocationService>();

    try {
      final Position pos = await locationService.getCurrentLocation();
      setState(() {
        _location = GeoPoint(pos.latitude, pos.longitude);
      });
      if (mounted) {
        showSnackBar(context, "Location updated automatically.", isError: false);

      }
    } on LocationServiceDisabledException {
      if (mounted) await _showEnableLocationDialog();
    } catch (e) {
      if (mounted) {
        showSnackBar(context, "Error fetching location: $e");
      }
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  Future<void> _showEnableLocationDialog() async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Location Services Disabled'),
        content: const Text('Please enable location services for better results.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
            const Text('Cancel', style: TextStyle(color: Colors.white70)),
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

  // --------------- SAVE PROFILE -----------------

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (_location == null) {
      showSnackBar(context, "Location not available. Please retry.");
      return;
    }

    setState(() => _isSaving = true);

    try {
      final auth = context.read<AuthService>();
      final db = context.read<DatabaseService>();
      final user = auth.currentUser;

      if (user == null) {
        showSnackBar(context, "No logged-in user.");
        return;
      }

      final brand =
      _isOtherBrand ? _brandController.text.trim() : (_selectedBrand ?? '');
      final model =
      _isOtherModel ? _modelController.text.trim() : (_selectedModel ?? '');

      if (brand.isEmpty || model.isEmpty) {
        showSnackBar(context, "Please select brand and model.");
        return;
      }

      final existingCreatedAt =
          _existingUser?.createdAt ?? Timestamp.now();

      final updatedUser = UserModel(
        uid: user.uid,
        displayName: _nameController.text.trim(),
        email: _emailController.text.trim(), // read-only but stored
        phoneNumber: _phoneController.text.trim(),
        vehicleType: _vehicleType,
        vehicleBrand: brand,
        vehicleModel: model,
        lastKnownLocation: _location!,
        createdAt: existingCreatedAt,
      );

      await db.updateUser(updatedUser);

      if (!mounted) return;
      showSnackBar(
        context,
        "Profile updated successfully!",
        isError: false,
      );

      Navigator.pop(context); // back to ProfileScreen
    } catch (e) {
      if (mounted) {
        showSnackBar(context, "Error updating profile: $e");
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // --------------- UI -----------------

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingUser) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Profile"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Update your details to keep your ChargeX profile accurate.",
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
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Email (not editable)',
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number *',
                  prefixText: '+91 ',
                ),
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
                value: _vehicleType,
                decoration:
                const InputDecoration(labelText: 'Vehicle Type *'),
                items: ['2-wheeler', '4-wheeler']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (val) {
                  if (val == null) return;
                  setState(() {
                    _vehicleType = val;
                    _selectedBrand = null;
                    _selectedModel = null;
                    _isOtherBrand = false;
                    _isOtherModel = false;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Brand
              DropdownButtonFormField<String>(
                value: _isOtherBrand ? 'Other' : _selectedBrand,
                decoration:
                const InputDecoration(labelText: 'Vehicle Brand *'),
                items: (vehicleBrands[_vehicleType] ?? [])
                    .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedBrand = val;
                    _isOtherBrand = val == 'Other';
                    _selectedModel = null;
                    _isOtherModel = false;
                    if (!_isOtherBrand) _brandController.clear();
                  });
                },
                validator: (v) {
                  if (!_isOtherBrand && (v == null || v.isEmpty)) {
                    return "Select brand";
                  }
                  return null;
                },
              ),
              if (_isOtherBrand) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _brandController,
                  decoration:
                  const InputDecoration(labelText: 'Enter Brand *'),
                  validator: (v) =>
                  v == null || v.isEmpty ? "Enter brand" : null,
                ),
              ],
              const SizedBox(height: 16),

              // Model
              if (!_isOtherBrand)
                DropdownButtonFormField<String>(
                  value: _isOtherModel ? 'Other' : _selectedModel,
                  decoration:
                  const InputDecoration(labelText: 'Vehicle Model *'),
                  items: (vehicleModels[_selectedBrand] ?? ['Other'])
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedModel = val;
                      _isOtherModel = val == 'Other';
                      if (!_isOtherModel) _modelController.clear();
                    });
                  },
                  validator: (v) {
                    if (!_isOtherModel && (v == null || v.isEmpty)) {
                      return "Select model";
                    }
                    return null;
                  },
                ),
              if (_isOtherModel) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _modelController,
                  decoration:
                  const InputDecoration(labelText: 'Enter Model *'),
                  validator: (v) =>
                  v == null || v.isEmpty ? "Enter model" : null,
                ),
              ],
              const SizedBox(height: 24),

              // --- Location ---
              const Text("Location",
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
                            : "Location captured automatically.",
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
                      CircularProgressIndicator(strokeWidth: 2),
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

              // --- Save Button ---
              ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                child: _isSaving
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
                    : const Text("Save Changes"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
