import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chargex/utils/show_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chargex/services/location_service.dart';
import 'package:chargex/services/email_service.dart';
import 'package:chargex/screens/otp_verification_screen.dart';
import 'package:geolocator/geolocator.dart'
    hide LocationServiceDisabledException;

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Text Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
  TextEditingController();

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
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  // ------------------ VEHICLE BRAND + MODEL DATA ------------------

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
    // 2 wheelers
    'Ola Electric': ['S1 Pro', 'S1 Pro+', 'S1 X', 'S1 Air'],
    'Ather Energy': ['450X', '450S', 'Rizta'],
    'TVS Motor': ['iQube', 'iQube S', 'iQube ST'],
    'Bajaj': ['Chetak Electric'],
    'Hero Electric': ['Vida VX2'],

    // 4 wheelers
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

  // ------------------ LOCATION LOGIC ------------------
  Future<void> _getUserLocation() async {
    setState(() => _isLocating = true);

    final locationService =
    Provider.of<LocationService>(context, listen: false);

    try {
      final pos = await locationService.getCurrentLocation();
      setState(() {
        _location = GeoPoint(pos.latitude, pos.longitude);
        _isLocating = false;
      });
      if (mounted) showSnackBar(context, "Location captured!");
    } on LocationServiceDisabledException {
      if (mounted) await _showEnableLocationDialog();
    } catch (e) {
      if (mounted) showSnackBar(context, e.toString());
    } finally {
      setState(() => _isLocating = false);
    }
  }

  Future<void> _showEnableLocationDialog() async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Location Services Disabled"),
        content: const Text("Please enable location services."),
        actions: [
          TextButton(
            child: const Text("Cancel",
                style: TextStyle(color: Colors.white70)),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text("Open Settings",
                style: TextStyle(color: Colors.indigoAccent)),
            onPressed: () {
              Geolocator.openLocationSettings();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  // ------------------ SIGNUP BUTTON ------------------
  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    if (_location == null) {
      showSnackBar(context, "Please capture your location");
      return;
    }

    setState(() => _isLoading = true);

    final brand =
    _isOtherBrand ? _brandController.text.trim() : _selectedBrand!;
    final model =
    _isOtherModel ? _modelController.text.trim() : _selectedModel!;

    Map<String, dynamic> vehicleData = {
      'type': _vehicleType,
      'brand': brand,
      'model': model,
    };

    final otp = await EmailService.sendOtpEmail(_emailController.text.trim());

    setState(() => _isLoading = false);

    if (otp == null) {
      showSnackBar(context, "Failed to send OTP. Try again.");
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OtpVerificationScreen(
          email: _emailController.text.trim(),
          otp: otp,
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          password: _passwordController.text.trim(),
          location: _location!,
          vehicleData: vehicleData,
        ),
      ),
    );
  }

  // ----------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Account"),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ------------------ PERSONAL DETAILS ------------------

              const Text("Personal Details",
                  style:
                  TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Full Name *"),
                validator: (v) =>
                v == null || v.isEmpty ? "Enter name" : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: "Email *"),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.isEmpty) return "Enter email";
                  if (!v.contains("@")) return "Enter valid email";
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: "Phone Number *",
                  prefixText: "+91 ",
                ),
                keyboardType: TextInputType.phone,
                validator: (v) =>
                v == null || v.length != 10 ? "Enter valid number" : null,
              ),
              const SizedBox(height: 16),

              // PASSWORD ------------------

              TextFormField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  labelText: "Password *",
                  suffixIcon: IconButton(
                    icon: Icon(_isPasswordVisible
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () =>
                        setState(() => _isPasswordVisible = !_isPasswordVisible),
                  ),
                ),
                validator: (v) =>
                v == null || v.length < 6 ? "Min 6 characters" : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _confirmPasswordController,
                obscureText: !_isConfirmPasswordVisible,
                decoration: InputDecoration(
                  labelText: "Confirm Password *",
                  suffixIcon: IconButton(
                    icon: Icon(_isConfirmPasswordVisible
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () => setState(() =>
                    _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                  ),
                ),
                validator: (v) =>
                v != _passwordController.text
                    ? "Passwords do not match"
                    : null,
              ),

              // ------------------ VEHICLE DETAILS ------------------
              const SizedBox(height: 24),
              const Text("Vehicle Details",
                  style:
                  TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              // VEHICLE TYPE
              DropdownButtonFormField<String>(
                value: _vehicleType,
                decoration:
                const InputDecoration(labelText: "Vehicle Type *"),
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
              ),
              const SizedBox(height: 16),

              // BRAND DROPDOWN
              DropdownButtonFormField<String>(
                value: _selectedBrand,
                decoration:
                const InputDecoration(labelText: "Vehicle Brand *"),
                items: vehicleBrands[_vehicleType]!
                    .map((b) =>
                    DropdownMenuItem(value: b, child: Text(b)))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedBrand = value;
                    _isOtherBrand = value == "Other";
                    _selectedModel = null;
                    _isOtherModel = false;
                  });
                },
                validator: (v) {
                  if (!_isOtherBrand && v == null) return "Select brand";
                  return null;
                },
              ),

              if (_isOtherBrand)
                TextFormField(
                  controller: _brandController,
                  decoration:
                  const InputDecoration(labelText: "Enter Brand *"),
                  validator: (v) =>
                  v == null || v.isEmpty ? "Enter brand" : null,
                ),
              const SizedBox(height: 16),

              // MODEL
              if (!_isOtherBrand)
                DropdownButtonFormField<String>(
                  value: _selectedModel,
                  decoration:
                  const InputDecoration(labelText: "Vehicle Model *"),
                  items: (vehicleModels[_selectedBrand] ?? ['Other'])
                      .map((m) =>
                      DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedModel = value;
                      _isOtherModel = value == "Other";
                    });
                  },
                  validator: (v) {
                    if (!_isOtherModel && v == null) {
                      return "Select model";
                    }
                    return null;
                  },
                ),

              if (_isOtherModel)
                TextFormField(
                  controller: _modelController,
                  decoration:
                  const InputDecoration(labelText: "Enter Model *"),
                  validator: (v) =>
                  v == null || v.isEmpty ? "Enter model" : null,
                ),

              // ------------------ LOCATION ------------------
              const SizedBox(height: 24),
              const Text("Location",
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
                            ? "Tap to capture location"
                            : "Location captured",
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
                      child: CircularProgressIndicator(
                          strokeWidth: 2),
                    )
                        : IconButton(
                      icon: const Icon(Icons.my_location,
                          color: Colors.indigoAccent),
                      onPressed: _getUserLocation,
                    ),
                  ],
                ),
              ),

              // ------------------ SIGNUP BUTTON ------------------
              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSignUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5B6BFF),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                      : const Text("Create Account"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
