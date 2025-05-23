import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const String baseApiUrl = 'http://192.168.0.21:5000';

class AccountSettingsPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const AccountSettingsPage({Key? key, required this.userData}) : super(key: key);

  @override
  _AccountSettingsPageState createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  late String name;
  late String email;
  late String address;
  late String phoneNumber;
  String? profilePicturePath;
  bool isLoading = false;
  bool isPasswordVisible = false;
  
  // Controllers for account settings form
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  
  // Controllers for change password form
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize with user data
    name = widget.userData['name'] ?? 'User';
    email = widget.userData['email'] ?? 'No Email';
    address = widget.userData['physical_address'] ?? '';
    phoneNumber = widget.userData['phone_number'] ?? '';
    profilePicturePath = widget.userData['profilePicture'] ?? 'assets/kim.jpg';
    
    // Set initial values for the controllers
    _nameController.text = name;
    _emailController.text = email;
    _addressController.text = address;
    _phoneController.text = phoneNumber;
  }

  @override
  void dispose() {
    // Dispose all controllers
    _nameController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Method to determine the image provider for profile picture
  ImageProvider _getImageProvider() {
    // If path is null or empty, use default image
    if (profilePicturePath == null || profilePicturePath!.isEmpty) {
      return const AssetImage('assets/kim.jpg');
    }
    
    try {
      // Check if it's an asset path
      if (profilePicturePath!.startsWith('assets/')) {
        return AssetImage(profilePicturePath!);
      } 
      // Check if it's a network image
      else if (profilePicturePath!.startsWith('http://') || 
              profilePicturePath!.startsWith('https://')) {
        return NetworkImage(profilePicturePath!);
      } 
      // Otherwise treat as file path
      else {
        final file = File(profilePicturePath!);
        // Check if file exists before using it
        if (file.existsSync()) {
          return FileImage(file);
        } else {
          print('File does not exist: $profilePicturePath');
          return const AssetImage('assets/kim.jpg');
        }
      }
    } catch (e) {
      print('Error loading profile image: $e');
      // Fallback to default image on any error
      return const AssetImage('assets/kim.jpg');
    }
  }

  // Method to save account information
  Future<void> _saveAccountInfo() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Update the local state first
      setState(() {
        name = _nameController.text;
        address = _addressController.text;
        phoneNumber = _phoneController.text;
      });
      
      // Here you would update the user info in your database
      // For now, just showing a success message
      _showSnackBar('Account information updated successfully');
      
      // Update the userData map
      widget.userData['name'] = name;
      widget.userData['physical_address'] = address;
      widget.userData['phone_number'] = phoneNumber;
      
      // You might want to update the user session data as well
      // UserSession.saveUserSession(widget.userData);
      
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _changePassword() async {
    // Validate form inputs first
    if (_currentPasswordController.text.isEmpty || 
        _newPasswordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      _showSnackBar('All fields are required');
      return;
    }
    
    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showSnackBar('New passwords do not match');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$baseApiUrl/api/change-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'old_password': _currentPasswordController.text,
          'new_password': _newPasswordController.text,
        }),
      );

      if (response.statusCode == 200) {
        _showSnackBar('Password changed successfully');
        // Clear password fields
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      } else {
        final responseData = jsonDecode(response.body);
        _showSnackBar(responseData['error'] ?? 'Failed to change password');
      }
    } catch (e) {
      _showSnackBar('Error: ${e.toString()}');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: message.contains('successfully') 
            ? Colors.green 
            : Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  Widget _buildAccountDetailsSection() {
    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Account Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF63C5DA),
              ),
            ),
            SizedBox(height: 16),
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: _getImageProvider(),
                    backgroundColor: Colors.grey[200],
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Color(0xFF63C5DA),
                        shape: BoxShape.circle,
                      ),
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                prefixIcon: Icon(Icons.person, color: Color(0xFF63C5DA)),
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _emailController,
              readOnly: true, // Email typically shouldn't be changed
              decoration: InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                prefixIcon: Icon(Icons.email, color: Color(0xFF63C5DA)),
                filled: true,
                fillColor: Colors.grey[200],
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: 'Address',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                prefixIcon: Icon(Icons.home, color: Color(0xFF63C5DA)),
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                prefixIcon: Icon(Icons.phone, color: Color(0xFF63C5DA)),
              ),
              keyboardType: TextInputType.phone,
            ),
            SizedBox(height: 20),
            Center(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _saveAccountInfo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF63C5DA),
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
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

  Widget _buildChangePasswordSection() {
    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Change Password',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF63C5DA),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _currentPasswordController,
              obscureText: !isPasswordVisible,
              decoration: InputDecoration(
                labelText: 'Current Password',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                suffixIcon: IconButton(
                  icon: Icon(
                    isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      isPasswordVisible = !isPasswordVisible;
                    });
                  },
                ),
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _newPasswordController,
              obscureText: !isPasswordVisible,
              decoration: InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _confirmPasswordController,
              obscureText: !isPasswordVisible,
              decoration: InputDecoration(
                labelText: 'Confirm New Password',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            SizedBox(height: 20),
            Center(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _changePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF63C5DA),
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Change Password',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Color(0xFF63C5DA),
        elevation: 0,
        title: Text(
          'Account Settings',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            // Account Details Section (moved from MePage)
            _buildAccountDetailsSection(),
            
            // Change Password Section
            _buildChangePasswordSection(),
          ],
        ),
      ),
    );
  }
}