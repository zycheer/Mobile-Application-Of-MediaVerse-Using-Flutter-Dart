import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'otp.dart'; // Import the OTP verification page

class ResetPasswordPage extends StatefulWidget {
  final String email;
  final bool isFromForgotPassword;

  const ResetPasswordPage({
    Key? key, 
    required this.email,
    this.isFromForgotPassword = false,
  }) : super(key: key);

  @override
  _ResetPasswordPageState createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  String _message = '';
  bool _isSuccess = false;

  // Server URL
  final String serverUrl = 'http://192.168.0.21:5000';

  Future<void> _resetPassword() async {
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // Validate inputs
    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      setState(() {
        _message = 'All fields are required';
        _isSuccess = false;
      });
      return;
    }

    if (newPassword != confirmPassword) {
      setState(() {
        _message = 'Passwords do not match';
        _isSuccess = false;
      });
      return;
    }

    // Basic password strength check
    if (newPassword.length < 8) {
      setState(() {
        _message = 'Password must be at least 8 characters long';
        _isSuccess = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _message = '';
    });

    try {
      // Call API to initiate password reset with OTP
      final response = await http.post(
        Uri.parse('$serverUrl/api/reset-password-init'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': widget.email,
          'new_password': newPassword,
        }),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      // Handle response
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // If successful, navigate to OTP verification
        if (data['status'] == 'success') {
          // Navigate to OTP verification page
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OTPVerificationPage(
                email: widget.email,
                newPassword: newPassword,
                isPasswordReset: true, // Flag to indicate this is for password reset
                onSuccessCallback: () {
                  // This will be called after successful OTP verification
                  // Show success message and navigate back to login page
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Password reset successful! Please login with your new password.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  // Navigate back to login page
                  Navigator.popUntil(context, ModalRoute.withName('/login'));
                },
              ),
            ),
          );
        } else {
          setState(() {
            _isLoading = false;
            _message = data['message'] ?? 'Failed to reset password';
            _isSuccess = false;
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          _message = 'Failed to reset password. Please try again.';
          _isSuccess = false;
        });
      }
    } catch (e) {
      print('Error details: $e');
      setState(() {
        _isLoading = false;
        _message = 'An error occurred. Please check your connection and try again.';
        _isSuccess = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            colors: [
              Color(0xFF63C5DA),
              Color(0xFF63C5DA),
              Color(0xFF63C5DA),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 80),
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                "Reset Password",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(30),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(60),
                    topRight: Radius.circular(60),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      Text(
                        "Create a new password for ${widget.email}",
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[700],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),
                      _buildPasswordField(
                        controller: _newPasswordController,
                        labelText: 'New Password',
                      ),
                      const SizedBox(height: 20),
                      _buildPasswordField(
                        controller: _confirmPasswordController,
                        labelText: 'Confirm New Password',
                      ),
                      const SizedBox(height: 20),
                      if (_message.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _isSuccess ? Colors.green.shade50 : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _message,
                            style: TextStyle(
                              color: _isSuccess ? Colors.green.shade700 : Colors.red.shade700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      const SizedBox(height: 30),
                      _buildResetButton(),
                      const SizedBox(height: 20),
                      _buildCancelButton(context),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String labelText,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF63C5DA).withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: !_isPasswordVisible,
        decoration: InputDecoration(
          hintText: labelText,
          border: InputBorder.none,
          suffixIcon: IconButton(
            icon: Icon(
              _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
              color: Colors.grey,
            ),
            onPressed: () {
              setState(() {
                _isPasswordVisible = !_isPasswordVisible;
              });
            },
          ),
        ),
      ),
    );
  }

  Widget _buildResetButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _resetPassword,
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF63C5DA),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
          elevation: 5,
          shadowColor: Color(0xFF63C5DA),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              )
            : const Text(
                "Continue",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildCancelButton(BuildContext context) {
    return TextButton(
      onPressed: () {
        Navigator.pop(context);
      },
      child: const Text(
        "Cancel",
        style: TextStyle(
          color: Color(0xFF63C5DA),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
