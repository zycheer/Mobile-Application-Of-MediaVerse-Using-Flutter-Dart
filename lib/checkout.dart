import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'purchase_navigation_page.dart';
import 'buyerhome.dart'; // Import the BuyerHomePage

// Use a dynamic base URL or implement proper configuration
const String baseUrl = 'http://192.168.0.21:5000';

class CheckoutPage extends StatefulWidget {
  final List<dynamic> items;
  final double totalAmount;
  final bool isBuyNow;

  const CheckoutPage({
    Key? key, 
    required this.items, 
    required this.totalAmount,
    required this.isBuyNow,
  }) : super(key: key);

  @override
  _CheckoutPageState createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  bool _isLoading = true;
  String _errorMessage = '';
  Map<String, dynamic> _userInfo = {
    'name': '',
    'phone': '',
    'address': ''
  };
  String _selectedPaymentMethod = 'cod';
  double _subtotal = 0.0;
  double _shippingFee = 50.0; // Default shipping fee
  double _total = 0.0;
  int? _userId;
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Calculate subtotal and total from widget items
      _subtotal = widget.totalAmount;
      _total = _subtotal + _shippingFee;

      // Get user data from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      String? userDataString = prefs.getString('userData');
      
      if (userDataString != null) {
        Map<String, dynamic> userData = json.decode(userDataString);
        _userId = userData['id'] ?? userData['ID'];
        
        // Use locally stored user info if available as fallback
        _userInfo['name'] = userData['name'] ?? '';
        _userInfo['phone'] = userData['PhoneNumber'] ?? userData['phone'] ?? '';
        _userInfo['address'] = userData['PhysicalAddress'] ?? userData['address'] ?? '';
        
        // Fetch user shipping information from backend
        await _fetchUserShippingInfo();
      } else {
        throw Exception('User data not found');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading user data: $e';
        _isLoading = false;
      });
      print('Error loading user data: $e');
    }
  }

  // Fetch user shipping information from backend
  Future<void> _fetchUserShippingInfo() async {
    try {
      if (_userId == null) {
        throw Exception('User ID not found');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/api/user-info?user_id=$_userId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _userInfo = {
            'name': data['name'] ?? _userInfo['name'],
            'phone': data['PhoneNumber'] ?? data['phone'] ?? _userInfo['phone'],
            'address': data['PhysicalAddress'] ?? data['address'] ?? _userInfo['address'],
          };
          _isLoading = false;
        });
        print('User shipping info loaded: $_userInfo');
      } else {
        print('Failed to load user info: ${response.statusCode} - ${response.body}');
        // Fallback: Check if we can get this info from backend directly
        await _fetchCheckoutData();
      }
    } catch (e) {
      print('Error fetching user shipping info: $e');
      // Fallback to checkout API which may provide the user info
      await _fetchCheckoutData();
    }
  }

  // Fallback method to get user data from checkout API
  Future<void> _fetchCheckoutData() async {
    try {
      // Create properly formatted items array for API
      List<Map<String, dynamic>> formattedItems = [];
      for (var item in widget.items) {
        formattedItems.add({
          'product_id': item['product_id']?.toString(),
          'quantity': item['quantity'] ?? item['quantity_order'] ?? 1,
        });
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/checkout'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': _userId,
          'cart_items': formattedItems,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          if (data['user_info'] != null) {
            _userInfo = {
              'name': data['user_info']['name'] ?? _userInfo['name'],
              'phone': data['user_info']['phone'] ?? _userInfo['phone'],
              'address': data['user_info']['address'] ?? _userInfo['address'],
            };
          }
          // If backend provides totals, use them
          if (data['subtotal'] != null) {
            _subtotal = double.tryParse(data['subtotal'].toString()) ?? _subtotal;
          }
          if (data['shipping_fee'] != null) {
            _shippingFee = double.tryParse(data['shipping_fee'].toString()) ?? _shippingFee;
          }
          if (data['total'] != null) {
            _total = double.tryParse(data['total'].toString()) ?? _total;
          } else {
            // Recalculate total if needed
            _total = _subtotal + _shippingFee;
          }
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load checkout data (${response.statusCode})';
          _isLoading = false;
        });
        print('Checkout API error: ${response.statusCode} - ${response.body}');
        
        // Continue with local data even if backend fails
        _useLocalDataOnly();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error connecting to server: $e';
        _isLoading = false;
      });
      print('Exception during checkout: $e');
      
      // Continue with local data even if backend fails
      _useLocalDataOnly();
    }
  }
  
  // Use local data when all backend requests fail
  void _useLocalDataOnly() {
    setState(() {
      // Continue with the data we have locally
      _total = _subtotal + _shippingFee;
      _isLoading = false;
      _errorMessage = '';
    });
  }

  // Function to clear cart items after successful order
  Future<void> _clearCartItems() async {
    try {
      if (!widget.isBuyNow) {  // Only clear cart for normal checkout, not buy now
        // Extract all cart item IDs
        List<int> cartItemIds = [];
        for (var item in widget.items) {
          if (item['id'] != null) {
            cartItemIds.add(item['id']);
          }
        }
        
        if (cartItemIds.isEmpty) {
          print('No cart items to clear');
          return;
        }
        
        // Call API to delete cart items
        final response = await http.post(
          Uri.parse('$baseUrl/api/cart/clear'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'user_id': _userId,
            'cart_item_ids': cartItemIds,
          }),
        ).timeout(const Duration(seconds: 10));
        
        if (response.statusCode == 200) {
          print('Cart items cleared successfully after order placement');
        } else {
          print('Failed to clear cart items: ${response.statusCode} - ${response.body}');
        }
      }
    } catch (e) {
      print('Error clearing cart items: $e');
      // Don't throw error - this is a non-critical operation
    }
  }

  // Fetch user data for returning to BuyerHomePage
  Future<Map<String, dynamic>> _getUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? userDataString = prefs.getString('userData');
      if (userDataString != null) {
        return json.decode(userDataString);
      }
      return {};
    } catch (e) {
      print('Error fetching user data: $e');
      return {};
    }
  }

  // Place order function
  Future<void> _placeOrder() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Create a proper formatted items list for the API
      List<Map<String, dynamic>> formattedItems = [];
      for (var item in widget.items) {
        formattedItems.add({
          'product_id': item['product_id'].toString(),
          'product_name': item['product_name'],
          'price': double.parse(item['price'].toString()),
          'quantity': item['quantity'] ?? item['quantity_order'] ?? 1,
          'total': double.parse(item['price'].toString()) * (item['quantity'] ?? item['quantity_order'] ?? 1),
          'image_path': item['image_path'],
        });
      }

      // Create order payload
      final orderPayload = {
        'user_id': _userId,
        'cart_items': formattedItems,
        'user_info': _userInfo,
        'payment_method': _selectedPaymentMethod,
        'subtotal': _subtotal,
        'shipping_fee': _shippingFee,
        'total': _total,
        'is_buy_now': widget.isBuyNow,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/api/place-order'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(orderPayload),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        // Clear cart items after successful order
        await _clearCartItems();
        
        setState(() {
          _isLoading = false;
        });
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order placed successfully!'),
            backgroundColor: Colors.green,
          )
        );
        
        // Get user data for navigation back to BuyerHomePage
        final userData = await _getUserData();
        
        // Navigate back to BuyerHomePage
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => BuyerHomePage(userData: userData),
          ),
          (route) => false, // Remove all previous routes
        );
      } else {
        setState(() {
          _errorMessage = 'Failed to place order: ${response.statusCode}';
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to place order. Please try again.'),
            backgroundColor: Colors.red,
          )
        );
        print('Order API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Network error. Please check your connection.'),
          backgroundColor: Colors.red,
        )
      );
      print('Exception during place order: $e');
    }
  }

  // Helper method to get correct image URL
  String _getImageUrl(dynamic item) {
    // Check if image_path is a full URL already
    if (item['image_path'] != null) {
      String imagePath = item['image_path'].toString();
      
      // If it's already a full URL, use it directly
      if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
        return imagePath;
      }
      
      // If it already contains the base URL path, don't add it again
      if (imagePath.contains('static/uploads')) {
        return '$baseUrl/$imagePath';
      }
      
      // Otherwise, construct the full URL
      return '$baseUrl/static/uploads/$imagePath';
    }
    
    // Fallback to product_image if image_path is not available
    if (item['product_image'] != null) {
      String productImage = item['product_image'].toString();
      
      // If it's already a full URL, use it directly
      if (productImage.startsWith('http://') || productImage.startsWith('https://')) {
        return productImage;
      }
      
      return '$baseUrl/static/uploads/$productImage';
    }
    
    // No image available
    return '';
  }

  Widget _buildCheckoutContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Shipping Address Card
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Shipping Address',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          // Navigate to edit address page
                          // Navigator.pushNamed(context, '/edit-address');
                        },
                        child: const Text(''),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _userInfo['name'] ?? 'No name provided',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _userInfo['phone'] ?? 'No phone number provided',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _userInfo['address'] ?? 'No address provided',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Order Summary
          const Text(
            'Order Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          
          // Cart Items
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.items.length,
            itemBuilder: (context, index) {
              final item = widget.items[index];
              final itemQuantity = item['quantity'] ?? item['quantity_order'] ?? 1;
              final itemPrice = double.parse(item['price'].toString());
              final itemTotal = itemPrice * itemQuantity;
              
              // Get the correct image URL using the helper method
              final imageUrl = _getImageUrl(item);
              
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            print('Error loading image: $imageUrl - $error');
                            return Container(
                              width: 50,
                              height: 50,
                              color: Colors.grey.shade300,
                              child: const Icon(Icons.image_not_supported),
                            );
                          },
                        )
                      : Container(
                          width: 50,
                          height: 50,
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.image),
                        ),
                  title: Text(item['product_name'] ?? 'Unnamed Product'),
                  subtitle: Text('$itemQuantity x ₱${itemPrice.toStringAsFixed(2)}'),
                  trailing: Text(
                    '₱${itemTotal.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 20),
          
          // Payment Method
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Payment Method',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  RadioListTile<String>(
                    title: const Text('Cash on Delivery'),
                    value: 'cod',
                    groupValue: _selectedPaymentMethod,
                    onChanged: (value) {
                      setState(() {
                        _selectedPaymentMethod = value!;
                      });
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text('GCash'),
                    value: 'gcash',
                    groupValue: _selectedPaymentMethod,
                    onChanged: (value) {
                      setState(() {
                        _selectedPaymentMethod = value!;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Price Summary
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Subtotal'),
                      Text('₱${_subtotal.toStringAsFixed(2)}'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Shipping Fee'),
                      Text('₱${_shippingFee.toStringAsFixed(2)}'),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '₱${_total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Place Order Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _placeOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    )
                  : const Text(
                      'Place Order',
                      style: TextStyle(fontSize: 16),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        backgroundColor: const Color(0xFF63C5DA),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty && _userInfo['name']?.isEmpty == true
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 60, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error', style: TextStyle(fontSize: 20)),
                      const SizedBox(height: 8),
                      Text(_errorMessage, textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loadUserData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF63C5DA),
                        ),
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
              : _buildCheckoutContent(),
    );
  }
}