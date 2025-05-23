// File: forgotp.dart - Updated Forgot Password Page

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'resetp.dart'; // Make sure to import reset password page

// Global configuration
class ApiConfig {
  // Change this to your server's IP or hostname
  static String baseUrl = "http://192.168.0.21:5000";
  
  // Get full URL for an API endpoint
  static String getUrl(String endpoint) {
    return "$baseUrl$endpoint";
  }
  
  // Standard headers for API requests
  static Map<String, String> headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  
  // HTTP timeout duration
  static Duration timeoutDuration = Duration(seconds: 15);
}

class ForgotPasswordPage extends StatefulWidget {
  @override
  _ForgotPasswordPageState createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController emailController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';
  bool _hasError = false;

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  // Method to check if email exists before proceeding
  Future<void> checkEmail() async {
    final email = emailController.text.trim();

    // Basic validation
    if (email.isEmpty) {
      setState(() {
        _errorMessage = "Please enter your email";
        _hasError = true;
      });
      return;
    }
    
    // Email format validation
    final bool emailValid = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
    if (!emailValid) {
      setState(() {
        _errorMessage = "Please enter a valid email";
        _hasError = true;
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _hasError = false;
    });

    try {
      // Step 1: Check if email exists
      var url = Uri.parse(ApiConfig.getUrl('/api/forgot'));
      
      print('Verifying email: $email');
      
      var response = await http.post(
        url,
        headers: ApiConfig.headers,
        body: jsonEncode({'email': email}),
      ).timeout(ApiConfig.timeoutDuration);
      
      print('Verify email response: ${response.statusCode} - ${response.body}');
      
      var jsonResponse = jsonDecode(response.body);
      
      if (response.statusCode == 200 && jsonResponse['status'] == 'success') {
        // If email exists, navigate to reset password page
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResetPasswordPage(
              email: email,
              isFromForgotPassword: true,
            ),
          ),
        );
      } else {
        setState(() {
          _errorMessage = jsonResponse['message'] ?? 'Email not found';
          _hasError = true;
        });
      }
    } catch (e) {
      print('Error checking email: $e');
      setState(() {
        _errorMessage = 'Connection error. Please check your network and try again.';
        _hasError = true;
      });
    } finally {
      setState(() => _isLoading = false);
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
          children: <Widget>[
            const SizedBox(height: 80),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Column(
                  children: const <Widget>[
                    Text(
                      "MediaVerse",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                  ],
                ),
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
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const SizedBox(height: 30),
                        Center(
                          child: Text(
                            "Forgot Password",
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF63C5DA),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: Text(
                            "Enter your email address to reset your password",
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 30),
                        _buildEmailField(),
                        const SizedBox(height: 10),
                        if (_hasError)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10.0),
                              child: Text(
                                _errorMessage,
                                style: TextStyle(color: Colors.red, fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        const SizedBox(height: 20),
                        _buildContinueButton(),
                        const SizedBox(height: 20),
                        Center(
                          child: TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: const Text(
                              "Back to Login",
                              style: TextStyle(
                                color: Color(0xFF63C5DA),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
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

  Widget _buildEmailField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2963C5DA),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: emailController,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(
          hintText: "Enter your email",
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildContinueButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : checkEmail,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF63C5DA),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
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
}
