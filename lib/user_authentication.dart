import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String baseUrl = 'http://192.168.0.21:5000';

class UserSession {
  static const String _userDataKey = 'userData';
  static const String _isLoggedInKey = 'isLoggedIn';
  static const String _sessionCookieKey = 'sessionCookie';
  
  // Save user session after login
  static Future<bool> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );
      
      print('Login response status: ${response.statusCode}');
      print('Login response headers: ${response.headers}');
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        if (responseData['status'] == 'success') {
          final userData = responseData['user'];
          
          // Save user data
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString(_userDataKey, json.encode(userData));
          await prefs.setBool(_isLoggedInKey, true);
          
          // Extract and save the session cookie
          String? setCookieHeader = response.headers['set-cookie'];
          if (setCookieHeader != null) {
            print('Received set-cookie header: $setCookieHeader');
            await prefs.setString(_sessionCookieKey, setCookieHeader);
          } else {
            print('No set-cookie header found');
            // Extract session ID from any cookie header
            for (var key in response.headers.keys) {
              if (key.toLowerCase() == 'set-cookie') {
                print('Found cookie header in different case: ${response.headers[key]}');
                await prefs.setString(_sessionCookieKey, response.headers[key]!);
                break;
              }
            }
          }
          
          return true;
        } else {
          print('Login failed: ${responseData['message']}');
          return false;
        }
      } else if (response.statusCode == 401) {
        print('Invalid credentials');
        return false;
      } else if (response.statusCode == 403) {
        print('Account pending approval');
        return false;
      } else {
        print('Login error with status code: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Exception during login: $e');
      return false;
    }
  }

  // Add the missing saveUserSession method
  static Future<void> saveUserSession(Map<String, dynamic> userData) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userDataKey, json.encode(userData));
    await prefs.setBool(_isLoggedInKey, true);
  }
  
  // Get session cookie for API requests
  static Future<String?> getSessionCookie() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_sessionCookieKey);
  }
  
  // Make an authenticated API request
  static Future<http.Response> authenticatedRequest(
    String endpoint, 
    {String method = 'GET', Map<String, dynamic>? body}
  ) async {
    final String? sessionCookie = await getSessionCookie();
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
    };
    
    // Add session cookie if available
    if (sessionCookie != null) {
      headers['Cookie'] = sessionCookie;
    }
    
    final Uri url = Uri.parse('$baseUrl$endpoint');
    
    try {
      if (method == 'GET') {
        return await http.get(url, headers: headers);
      } else if (method == 'POST') {
        return await http.post(
          url, 
          headers: headers, 
          body: body != null ? json.encode(body) : null
        );
      } else if (method == 'PUT') {
        return await http.put(
          url, 
          headers: headers, 
          body: body != null ? json.encode(body) : null
        );
      } else if (method == 'DELETE') {
        return await http.delete(url, headers: headers);
      } else {
        throw Exception('Unsupported HTTP method: $method');
      }
    } catch (e) {
      print('Error in authenticated request: $e');
      rethrow;
    }
  }
  
  // Get current user session
  static Future<Map<String, dynamic>?> getUserSession() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userDataString = prefs.getString(_userDataKey);
    
    if (userDataString != null) {
      return json.decode(userDataString);
    }
    return null;
  }
  
  // Get current user ID
  static Future<dynamic> getCurrentUserId() async {
    Map<String, dynamic>? userData = await getUserSession();
    if (userData != null) {
      return userData['id'] ?? userData['ID'];
    }
    return null;
  }
  
  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isLoggedInKey) ?? false;
  }
  
  // Clear user session (logout)
  static Future<void> clearUserSession() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userDataKey);
    await prefs.remove(_sessionCookieKey);
    await prefs.setBool(_isLoggedInKey, false);
    
    // Make logout API call to clear server-side session
    try {
      await http.post(Uri.parse('$baseUrl/api/logout'));
    } catch (e) {
      print('Error logging out from server: $e');
    }
  }
}