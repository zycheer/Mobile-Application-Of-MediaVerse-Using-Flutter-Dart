import 'dart:async'; // Import for Timer
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'user_authentication.dart'; // Import to save user session after login
import 'buyerhome.dart';
import 'courier.dart';

class OTPVerificationPage extends StatefulWidget {
  final String email;
  final String newPassword;
  final bool isPasswordReset;
  final Function? onSuccessCallback;
  final Map<String, dynamic>? userData; // Add userData for login flow

  OTPVerificationPage({
    required this.email, 
    required this.newPassword,
    this.isPasswordReset = false,
    this.onSuccessCallback,
    this.userData, // Store user data from login response
  });

  @override
  _OTPVerificationPageState createState() => _OTPVerificationPageState();
}

class _OTPVerificationPageState extends State<OTPVerificationPage> {
  final TextEditingController otpController = TextEditingController();
  bool _isVerifying = false;
  bool _otpSent = false;
  bool _isResending = false;
  
  // Adding a countdown timer for OTP expiry
  int _remainingTime = 600; // 10 minutes in seconds
  bool _isTimerRunning = false;
  Timer? _timer; // Add a Timer object to properly handle the countdown

  @override
  void initState() {
    super.initState();
    // Automatically trigger OTP sending when the page loads
    _sendOtp();
  }

  @override
  void dispose() {
    // Cancel the timer when the widget is disposed
    _timer?.cancel();
    otpController.dispose();
    super.dispose();
  }

  // Method to send OTP to the user's email
  Future<void> _sendOtp() async {
    if (!mounted) return; // Check if widget is still mounted
    
    setState(() {
      _isVerifying = true;
      _isResending = true;
    });
    
    // Determine the appropriate endpoint based on whether this is for password reset
    String endpoint = widget.isPasswordReset 
        ? '/api/reset-password-init' 
        : '/api/send-otp';
    
    var url = Uri.parse('http://192.168.0.21:5000$endpoint');
  
    try {
      // Print the email we're sending to verify it's correct
      print('Sending OTP to email: ${widget.email}');
      
      // Prepare request body based on the operation type
      Map<String, dynamic> requestBody = {
        'email': widget.email,
      };
      
      // Add password if this is a reset request
      if (widget.isPasswordReset) {
        requestBody['new_password'] = widget.newPassword;
      }
      
      var response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      // Print response for debugging
      print('Send OTP response status: ${response.statusCode}');
      print('Send OTP response body: ${response.body}');
      
      if (!mounted) return; // Check if widget is still mounted before updating state
      
      var json = jsonDecode(response.body);
      
      if (response.statusCode == 200 && json['status'] == 'success') {
        setState(() {
          _otpSent = true;
          _isTimerRunning = true;
          _remainingTime = 600; // Reset timer to 10 minutes
        });
        
        // Start the countdown timer with a proper Timer
        _startCountdownTimer();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OTP sent to your email'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(json['message'] ?? 'Failed to send OTP'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error sending OTP: $e');
      
      if (!mounted) return; // Check if widget is still mounted
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection error. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) { // Check if widget is still mounted
        setState(() {
          _isVerifying = false;
          _isResending = false;
        });
      }
    }
  }

  // Improved countdown timer logic using a proper Timer object
  void _startCountdownTimer() {
    // Cancel any existing timer
    _timer?.cancel();
    
    // Create a new periodic timer that fires every second
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel(); // Cancel the timer if widget is not mounted
        return;
      }
      
      setState(() {
        if (_remainingTime > 0) {
          _remainingTime--;
        } else {
          _isTimerRunning = false;
          timer.cancel(); // Cancel the timer when countdown reaches zero
        }
      });
    });
  }

  // Format the remaining time as MM:SS
  String _formatRemainingTime() {
    int minutes = _remainingTime ~/ 60;
    int seconds = _remainingTime % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // Method to route based on user role
  void _routeBasedOnRole(Map<String, dynamic> userData) {
    String role = userData['role'].toString().toLowerCase();
    
    if (role == 'courier') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => CourierHomePage(userData: userData),
        ),
      );
    } else {
      // Default to buyer home page for 'user' role or any other role
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => BuyerHomePage(userData: userData),
        ),
      );
    }
  }

  // Method to verify the OTP entered by the user
  Future<void> verifyOtp() async {
    if (!mounted) return; // Check if widget is still mounted
    
    if (otpController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter OTP'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isVerifying = true);

    // Determine the appropriate endpoint based on whether this is for password reset
    String endpoint = widget.isPasswordReset 
        ? '/api/verify-reset-otp' 
        : '/api/verify-otp';
    
    var url = Uri.parse('http://192.168.0.21:5000$endpoint');
  
    try {
      // Prepare request body
      Map<String, dynamic> requestBody = {
        'otp': otpController.text,
        'email': widget.email,
      };
      
      // Add password if this is a reset request
      if (widget.isPasswordReset) {
        requestBody['new_password'] = widget.newPassword;
      }
      
      // Print request details for debugging
      print('Verifying OTP for email: ${widget.email}');
      print('OTP entered: ${otpController.text}');
      
      var response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      // Print response for debugging
      print('Verify OTP response status: ${response.statusCode}');
      print('Verify OTP response body: ${response.body}');

      if (!mounted) return; // Check if widget is still mounted
      
      var json = jsonDecode(response.body);

      if (response.statusCode == 200 && json['status'] == 'success') {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isPasswordReset 
                ? 'Password reset successful!' 
                : 'OTP verification successful!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Handle different workflows:
        if (widget.isPasswordReset) {
          // For password reset: Go back to login page
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (Route<dynamic> route) => false);
        } else {
          // For login flow
          // First save user session data if available
          if (json['user'] != null) {
            await UserSession.saveUserSession(json['user']);
            _routeBasedOnRole(json['user']);
          } else if (widget.userData != null) {
            // If no user in response but we have userData from login
            await UserSession.saveUserSession(widget.userData!);
            _routeBasedOnRole(widget.userData!);
          } else {
            // Fallback if no userData provided
            Navigator.of(context).pushNamedAndRemoveUntil('/login', (Route<dynamic> route) => false);
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(json['message'] ?? 'Invalid OTP'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error verifying OTP: $e');
      
      if (!mounted) return; // Check if widget is still mounted
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to verify OTP. Please try again later.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) { // Check if widget is still mounted
        setState(() => _isVerifying = false);
      }
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
                child: Padding(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const SizedBox(height: 30),
                      Center(
                        child: Text(
                          widget.isPasswordReset 
                              ? "Verify Password Reset" 
                              : "OTP Verification",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF63C5DA),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      Center(
                        child: Text(
                          widget.isPasswordReset
                              ? "Enter the verification code sent to ${widget.email} to confirm your password reset"
                              : "An OTP has been sent to ${widget.email}",
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      if (_isTimerRunning) ...[
                        const SizedBox(height: 10),
                        Center(
                          child: Text(
                            "OTP expires in: ${_formatRemainingTime()}",
                            style: TextStyle(
                              fontSize: 14,
                              color: _remainingTime < 60 ? Colors.red : Colors.grey,
                              fontWeight: _remainingTime < 60 ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 30),
                      _buildOtpField(),
                      const SizedBox(height: 20),
                      _buildVerifyButton(),
                      const SizedBox(height: 20),
                      if (_otpSent) _buildResendButton(),
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

  Widget _buildOtpField() {
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
        controller: otpController,
        keyboardType: TextInputType.number,
        maxLength: 6,
        decoration: const InputDecoration(
          hintText: "Enter OTP",
          border: InputBorder.none,
          counterText: '', // Removes the counter below the TextField
        ),
        style: TextStyle(
          fontSize: 20, 
          letterSpacing: 10, // Add some space between characters
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildVerifyButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isVerifying ? null : verifyOtp,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF63C5DA),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
        ),
        child: _isVerifying
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                widget.isPasswordReset ? "Confirm Password Reset" : "Verify OTP",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildResendButton() {
    return Center(
      child: TextButton(
        onPressed: _isResending ? null : _sendOtp,
        child: Text(
          "Didn't receive the code? Resend OTP",
          style: TextStyle(
            color: _isResending ? Colors.grey : Color(0xFF63C5DA),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}