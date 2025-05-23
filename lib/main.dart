import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'register.dart';
import 'buyerhome.dart';
import 'courier.dart'; // Import the courier page
import 'forgotp.dart';
import 'user_authentication.dart'; 
import 'otp.dart';

void main() => runApp(buildApp());

Widget buildApp() {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: HomePage(),
    routes: {
      '/login': (context) => HomePage(),
      // Define other routes here
    },
  );
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _obscurePassword = true;
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Check if user is already logged in and verified
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final isLoggedIn = await UserSession.isLoggedIn();
    if (isLoggedIn) {
      final userData = await UserSession.getUserSession();
      if (userData != null) {
        // Only navigate to home screen if already logged in and verified
        // We'll check verification status with the backend
        _verifyUserSession(userData);
      }
    }
  }

  Future<void> _verifyUserSession(Map<String, dynamic> userData) async {
    try {
      // Make an API call to check if user session is valid and verified
      final response = await UserSession.authenticatedRequest('/api/check-session');
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        if (responseData['status'] == 'success' && responseData['verified'] == true) {
          // Check user role and route accordingly
          _routeBasedOnRole(userData);
        } else {
          // If not verified, clear the session
          await UserSession.clearUserSession();
        }
      } else {
        // If session check fails, clear the session
        await UserSession.clearUserSession();
      }
    } catch (e) {
      // On error, we'll just keep the user on the login page
      print('Error checking session: $e');
    }
  }

  // Function to route based on user role
  void _routeBasedOnRole(Map<String, dynamic> userData) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
    });
  }

  Future<void> loginUser(String email, String password) async {
    setState(() {
      _isLoading = true;
    });

    var url = Uri.parse('http://192.168.0.21:5000/api/login'); // Replace with your actual IP

    try {
      var response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 10)); // Timeout protection

      if (response.statusCode == 200) {
        var json = jsonDecode(response.body);

        if (json['status'] == 'success') {
          var userData = json['user'];
          
          // Navigate to OTP verification page and pass userData
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => OTPVerificationPage(
                email: email,
                newPassword: '', // Empty as we're not resetting password
                isPasswordReset: false,
                userData: userData, // Pass user data from login response
              ),
            ),
          );
        } else {
          _showError(json['message'] ?? "Login failed");
        }
      } else {
        try {
          var json = jsonDecode(response.body);
          _showError(json['message'] ?? "Login failed");
        } catch (_) {
          _showError("Unexpected response from server.");
        }
      }
    } catch (e) {
      _showError("Connection failed. Please check your internet or backend.");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
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
                          "Login",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF63C5DA),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      _buildEmailField(),
                      const SizedBox(height: 20),
                      _buildPasswordField(),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ForgotPasswordPage(),
                              ),
                            );
                          },
                          child: const Text(
                            "Forgot Password?",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildLoginButton(),
                      const SizedBox(height: 20),
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Don't have an account? ",
                              style: TextStyle(color: Colors.grey),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => RegisterPage(),
                                  ),
                                );
                              },
                              child: const Text(
                                "Register",
                                style: TextStyle(
                                  color: Color(0xFF63C5DA),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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
        decoration: const InputDecoration(
          hintText: "Email or Phone number",
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
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
        controller: passwordController,
        obscureText: _obscurePassword,
        decoration: InputDecoration(
          hintText: "Password",
          border: InputBorder.none,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_off : Icons.visibility,
              size: 20,
              color: const Color(0xFF63C5DA),
            ),
            onPressed: () {
              setState(() {
                _obscurePassword = !_obscurePassword;
              });
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading
            ? null
            : () {
                final email = emailController.text.trim();
                final password = passwordController.text.trim();

                if (email.isEmpty || password.isEmpty) {
                  _showError("Please fill in all fields.");
                } else {
                  loginUser(email, password);
                }
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF63C5DA),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
                "Login",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}