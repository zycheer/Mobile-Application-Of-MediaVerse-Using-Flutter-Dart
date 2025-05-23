import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RegisterPage extends StatefulWidget {
  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _showCourierFields = false;

  // Base user fields
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController middleNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController phoneNumberController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  // Courier-specific fields
  final TextEditingController vehicleTypeController = TextEditingController();
  final TextEditingController licensePlateController = TextEditingController();
  final TextEditingController idNumberController = TextEditingController();
  final TextEditingController serviceAreaController = TextEditingController();

  String? _selectedGender;
  List<String> _genders = ['Male', 'Female', 'Other'];

  String? _selectedRole;
  List<String> _roles = ['User', 'Courier'];

  // Vehicle types for dropdown
  String? _selectedVehicleType;
  List<String> _vehicleTypes = ['Motorcycle', 'Car', 'Bicycle', 'Van/Small Truck'];

  Future<void> registerUser() async {
    // Basic form validation
    if (passwordController.text.length < 6) {
      _showError("Password must be at least 6 characters long.");
      return;
    }

    // Validate courier fields if courier role is selected
    if (_selectedRole == 'Courier') {
      if (_selectedVehicleType == null || 
          licensePlateController.text.isEmpty ||
          idNumberController.text.isEmpty ||
          serviceAreaController.text.isEmpty) {
        _showError("Please fill in all courier information fields.");
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    var url = Uri.parse('http://192.168.0.21:5000/submit_form');

    // Prepare base user data
    var body = {
      'Name': '${firstNameController.text} ${middleNameController.text} ${lastNameController.text}'.trim(),
      'Email': emailController.text,
      'Password': passwordController.text,
      'Gender': _selectedGender?.toLowerCase() ?? '',
      'Role': _selectedRole ?? 'User',
      'PhoneNumber': phoneNumberController.text,
      'PhysicalAddress': addressController.text,
    };

    // Add courier-specific fields if courier role is selected
    if (_selectedRole == 'Courier') {
      body.addAll({
        'VehicleType': _selectedVehicleType ?? '',
        'LicensePlate': licensePlateController.text,
        'IDNumber': idNumberController.text,
        'ServiceArea': serviceAreaController.text,
      });
    }

    try {
      var response = await http.post(url, body: body);

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);

        if (data['message'] != null) {
          _showSuccess(data['message']);
          Future.delayed(Duration(seconds: 2), () {
            Navigator.pop(context);
          });
        } else if (data['error'] != null) {
          _showError(data['error']);
        }
      } else {
        _showError("Failed to register, please try again.");
      }
    } catch (e) {
      _showError("An error occurred: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Widget _styledInput(String hint, TextEditingController controller, {bool required = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: _inputDecoration(),
        child: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: required ? "$hint *" : hint,
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }

  Widget _styledPassword(String hint, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: _inputDecoration(),
        child: TextField(
          controller: controller,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            hintText: "$hint *",
            border: InputBorder.none,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: const Color(0xFF63C5DA),
              ),
              onPressed: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _inputDecoration() {
    return BoxDecoration(
      color: Colors.white,
      border: Border.all(color: Colors.grey.shade300),
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF63C5DA).withOpacity(0.1),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Widget _buildDropdown<T>(String hint, List<T> items, T? selectedValue, ValueChanged<T?> onChanged, {bool required = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: _inputDecoration(),
        child: DropdownButtonFormField<T>(
          value: selectedValue,
          decoration: InputDecoration(
            hintText: required ? "$hint *" : hint,
            border: InputBorder.none,
          ),
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(item.toString()),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildCourierFields() {
    if (!_showCourierFields) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Divider(color: Colors.grey),
        const SizedBox(height: 10),
        const Text(
          "Courier Information",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF63C5DA),
          ),
        ),
        const SizedBox(height: 15),
        _buildDropdown<String>(
          "Vehicle Type",
          _vehicleTypes,
          _selectedVehicleType,
          (value) {
            setState(() {
              _selectedVehicleType = value;
            });
          },
        ),
        _styledInput("License Plate Number", licensePlateController),
        _styledInput("ID/License Number", idNumberController),
        _styledInput("Service Area", serviceAreaController),
      ],
    );
  }

  Widget _buildRegisterButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : registerUser,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF63C5DA),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text("Register", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildLoginRedirect(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Already have an account? ", style: TextStyle(color: Colors.grey)),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Text("Login", style: TextStyle(color: Color(0xFF63C5DA), fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            colors: [Color(0xFF63C5DA), Color(0xFF63C5DA)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: 80),
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                "Create Account",
                style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(60),
                    topRight: Radius.circular(60),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(30),
                  child: SingleChildScrollView(
                    child: Column(
                      children: <Widget>[
                        const SizedBox(height: 20),
                        const Text(
                          "Register",
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF63C5DA)),
                        ),
                        const SizedBox(height: 30),
                        _styledInput("First Name", firstNameController),
                        _styledInput("Middle Name", middleNameController, required: false),
                        _styledInput("Last Name", lastNameController),
                        _buildDropdown<String>(
                          "Select Gender",
                          _genders,
                          _selectedGender,
                          (value) {
                            setState(() {
                              _selectedGender = value;
                            });
                          },
                        ),
                        _buildDropdown<String>(
                          "Account Type",
                          _roles,
                          _selectedRole,
                          (value) {
                            setState(() {
                              _selectedRole = value;
                              _showCourierFields = value == 'Courier';
                            });
                          },
                        ),
                        _styledInput("Address", addressController),
                        _styledInput("Phone Number", phoneNumberController),
                        _styledInput("Email", emailController),
                        _styledPassword("Password", passwordController),
                        
                        // Courier fields (shown/hidden based on selection)
                        _buildCourierFields(),
                        
                        const SizedBox(height: 20),
                        _buildRegisterButton(),
                        const SizedBox(height: 15),
                        _buildLoginRedirect(context),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}