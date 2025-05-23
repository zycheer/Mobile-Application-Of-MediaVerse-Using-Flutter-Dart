import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'main.dart';
import 'purchase_navigation_page.dart';
import 'message.dart';
import 'checkout.dart';
import 'productview.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'user_authentication.dart';
import 'accsett.dart';
import 'package:intl/intl.dart';

const String baseUrl = 'http://192.168.0.21:5000';

class BuyerHomePage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const BuyerHomePage({Key? key, required this.userData}) : super(key: key);

  @override
  _BuyerHomePageState createState() => _BuyerHomePageState();
}

class _BuyerHomePageState extends State<BuyerHomePage> {
  int _selectedIndex = 0;
  late final List<Widget> _pages;
  final GlobalKey<_HomePageContentState> _homePageKey = GlobalKey();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _pages = [
      HomePageContent(key: _homePageKey, userData: widget.userData),
      CartPage(),
      NotificationsPage(),
      MePage(userData: widget.userData),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _selectedIndex == 0
          ? PreferredSize(
              preferredSize: Size.fromHeight(80),
              child: AppBar(
                backgroundColor: Color(0xFF63C5DA),
                elevation: 0,
                title: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search on MediaVerse',
                      prefixIcon: Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          _homePageKey.currentState?.setSearchQuery('');
                        },
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.only(top: 6),
                    ),
                    onSubmitted: (value) {
                      _homePageKey.currentState?.setSearchQuery(value);
                    },
                    textInputAction: TextInputAction.search,
                    onChanged: (value) {
                      // Optionally implement live search here
                      // For better performance, use a debounce timer
                      // This will run only if you want real-time search
                      // _homePageKey.currentState?.setSearchQuery(value);
                    },
                  ),
                ),
                actions: [
                  IconButton(
                    icon: Icon(Icons.search),
                    onPressed: () {
                      _homePageKey.currentState?.setSearchQuery(_searchController.text);
                    },
                  ),
                  _iconWithBadge(Icons.chat_bubble_outline, '', onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MessagesPage(userData: widget.userData),
                      ),
                    );
                  }),
                ],
              ),
            )
          : null,
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Color(0xFF63C5DA),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'Cart'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Notifications'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Me'),
        ],
      ),
    );
  }

  Widget _iconWithBadge(IconData icon, String count, {VoidCallback? onPressed}) {
    return Stack(
      children: [
        IconButton(
          icon: Icon(icon),
          onPressed: onPressed ?? () {},
        ),
        if (count.isNotEmpty)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(count, style: TextStyle(color: Colors.white, fontSize: 10)),
            ),
          ),
      ],
    );
  }
}

class HomePageContent extends StatefulWidget {
  final Map<String, dynamic> userData;

  const HomePageContent({Key? key, required this.userData}) : super(key: key);

  @override
  _HomePageContentState createState() => _HomePageContentState();
}

class _HomePageContentState extends State<HomePageContent> {
  List<dynamic> products = [];
  bool isLoading = true;
  String? error;
  String selectedCategory = 'All';
  String searchQuery = '';
  bool isRefreshing = false;
  bool isSearching = false;

  final List<String> categories = [
    'All',
    'Fiction & Non-Fiction',
    'Magazine & Periodicals',
    'Music CDs & Vinyl Records',
    'Movie DVDs & Blu-ray',
    'Video Games & Consoles',
    'Educationals DVD',
  ];

  @override
  void initState() {
    super.initState();
    fetchProducts();
    // Setup periodic refresh (every 30 seconds)
    _setupPeriodicRefresh();
  }

  void _setupPeriodicRefresh() {
    // Refresh products every 30 seconds to get updated stock quantities
    Future.delayed(Duration(seconds: 30), () {
      if (mounted) {
        // Only refresh if not currently searching
        if (!isSearching) {
          refreshProducts(silent: true);
        }
        _setupPeriodicRefresh();
      }
    });
  }

  void setSearchQuery(String query) {
    setState(() {
      searchQuery = query;
      isSearching = query.isNotEmpty;
      fetchProducts();
    });
  }

  Future<void> refreshProducts({bool silent = false}) async {
    if (!silent) {
      setState(() {
        isRefreshing = true;
      });
    }
    await fetchProducts();
    if (!silent) {
      setState(() {
        isRefreshing = false;
      });
    }
  }

  Future<void> fetchProducts() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      String url = '$baseUrl/api/shop';
      List<String> params = [];

      if (selectedCategory != 'All') {
        params.add('category=${Uri.encodeComponent(selectedCategory)}');
      }

      if (searchQuery.isNotEmpty) {
        params.add('search=${Uri.encodeComponent(searchQuery)}');
        print('Searching for: $searchQuery'); // Debug print
      }

      // Add 'include_ratings=true' parameter to request ratings data
      params.add('include_ratings=true');

      if (params.isNotEmpty) {
        url += '?' + params.join('&');
      }

      print('Fetching from URL: $url'); // Debug print

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);
        print('Products received: ${decodedData.length}'); // Debug print
        
        setState(() {
          products = decodedData;
          isLoading = false;
        });
      } else {
        print('Error status code: ${response.statusCode}'); // Debug print
        print('Error response: ${response.body}'); // Debug print
        
        setState(() {
          error = 'Failed to load products: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      print('Network error: $e'); // Debug print
      
      setState(() {
        error = 'Network error: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => refreshProducts(),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category Filter
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: categories.map((category) {
                  final isSelected = selectedCategory == category;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(
                        category,
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() {
                          selectedCategory = category;
                          fetchProducts();
                        });
                      },
                      selectedColor: Color(0xFF63C5DA),
                      backgroundColor: Colors.grey[200],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            SizedBox(height: 10),
            
            // Search status indicator
            if (searchQuery.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search, size: 16, color: Colors.grey[700]),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Search results for "$searchQuery"',
                                style: TextStyle(color: Colors.grey[700]),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  searchQuery = '';
                                  isSearching = false;
                                  fetchProducts();
                                });
                              },
                              child: Icon(Icons.close, size: 16, color: Colors.grey[700]),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            // Products Grid
            if (isLoading && products.isEmpty)
              Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (error != null && products.isEmpty)
              Expanded(
                child: Center(child: Text(error!)),
              )
            else if (isRefreshing && products.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Center(child: LinearProgressIndicator()),
              ),
              
            Expanded(
              child: products.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No products found',
                          style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                        ),
                        if (searchQuery.isNotEmpty || selectedCategory != 'All')
                          TextButton(
                            onPressed: () {
                              setState(() {
                                searchQuery = '';
                                selectedCategory = 'All';
                                isSearching = false;
                                fetchProducts();
                              });
                            },
                            child: Text('Clear filters'),
                          ),
                      ],
                    ),
                  )
                : GridView.builder(
                    itemCount: products.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.65, // Further reduced to give space for the rating
                    ),
                    itemBuilder: (context, index) {
                      final product = products[index];
                      final stockQuantity = int.tryParse(product['stock_quantity']?.toString() ?? '0') ?? 0;
                      // Extract rating from product or default to 0
                      // Print out raw rating data to debug
                      print('Raw rating data for ${product['product_name']}: ${product['average_rating']}');
                      
                      // Force a default rating of 3.5 for testing if needed
                      // final double rating = 3.5;
                      
                      final double rating = product['average_rating'] != null ? 
                          double.tryParse(product['average_rating'].toString()) ?? 0.0 : 0.0;
                      final int reviewCount = product['review_count'] != null ?
                          int.tryParse(product['review_count'].toString()) ?? 0 : 0;
                          
                      // Debug print
                      print('Parsed rating: $rating, review count: $reviewCount');
                      
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProductViewPage(
                                product: product,
                                userData: widget.userData,
                              ),
                            ),
                          ).then((_) {
                            // Refresh products when returning from product view
                            refreshProducts(silent: true);
                          });
                        },
                        child: Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          elevation: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Product Image with stock indicator
                              Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                                    child: product['product_image'] != null
                                        ? Image.network(
                                            product['product_image'],
                                            height: 110,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Container(
                                                height: 110,
                                                width: double.infinity,
                                                color: Colors.grey[300],
                                                child: Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
                                              );
                                            },
                                          )
                                        : Container(
                                            height: 110,
                                            width: double.infinity,
                                            color: Colors.grey[300],
                                            child: Icon(Icons.shopping_bag, size: 40, color: Colors.grey),
                                          ),
                                  ),
                                  // Stock indicator
                                  if (stockQuantity <= 5)
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: stockQuantity > 0 ? Colors.amber.shade700 : Colors.red,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          stockQuantity > 0 ? 'Low Stock' : 'Out of Stock',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              
                              // Product details
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product['product_name'] ?? 'Unnamed Product',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      
                                      // Rating display
                                      Row(
                                        children: [
                                          // Star rating display with text
                                          Row(
                                            children: [
                                              ...List.generate(5, (index) {
                                                return Icon(
                                                  index < rating.floor() 
                                                    ? Icons.star 
                                                    : (index < rating && index >= rating.floor()) 
                                                      ? Icons.star_half 
                                                      : Icons.star_border,
                                                  color: Colors.amber,
                                                  size: 14,
                                                );
                                              }),
                                              // Add a numerical rating display for debugging and clarity
                                              SizedBox(width: 4),
                                              Text(
                                                rating > 0 ? rating.toStringAsFixed(1) : 'No Rating',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey[700],
                                                ),
                                              ),
                                            ],
                                          ),
                                          Spacer(),
                                          // Display rating count if available
                                          if (reviewCount > 0)
                                            Text(
                                              '($reviewCount)',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                        ],
                                      ),
                                      SizedBox(height: 4),
                                      
                                      // Price with stock quantity
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '₱${product['price']?.toString() ?? "0.00"}',
                                            style: TextStyle(
                                              color: Colors.redAccent,
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            '$stockQuantity left',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: stockQuantity > 5 ? Colors.green : 
                                                    stockQuantity > 0 ? Colors.orange : Colors.red,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                      
                                      // Category pill
                                      if (product['category'] != null)
                                        Expanded(
                                          child: Align(
                                            alignment: Alignment.bottomLeft,
                                            child: Container(
                                              margin: EdgeInsets.only(top: 4),
                                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.shade50,
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(color: Colors.blue.shade100),
                                              ),
                                              child: Text(
                                                product['category'],
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  color: Colors.blue.shade800,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }
}



// Cart Page (Displays items added to the cart)

class CartPage extends StatefulWidget {
  @override
  _CartPageState createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  List<dynamic> cartItems = [];
  bool isLoading = true;
  String? error;
  double totalPrice = 0.0;
  
  // Map to track selected items
  Map<int, bool> selectedItems = {};

  // Remove the hardcoded user ID
  int? userId; // This will be loaded from user session

  @override
  void initState() {
    super.initState();
    loadUserSession(); // Load user session first
  }

  // Function to load user session and get user ID
  Future<void> loadUserSession() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      
      // Get the logged-in user's data
      String? userDataString = prefs.getString('userData');
      
      if (userDataString != null) {
        Map<String, dynamic> userData = json.decode(userDataString);
        setState(() {
          userId = userData['id'] ?? userData['ID']; // Handle both 'id' and 'ID' keys
        });
        
        // Now fetch cart items with the actual user ID
        fetchCartItems();
      } else {
        // No user session found - redirect to login
        setState(() {
          error = 'Please log in to view your cart';
          isLoading = false;
        });
        
        // Optional: Navigate to login page
        // Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoginPage()));
      }
    } catch (e) {
      setState(() {
        error = 'Error loading user session: $e';
        isLoading = false;
      });
      print('Error loading user session: $e');
    }
  }

  // Function to fetch cart items from the API
  Future<void> fetchCartItems() async {
    if (userId == null) {
      setState(() {
        error = 'User not logged in';
        isLoading = false;
      });
      return;
    }

    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final response = await http.get(Uri.parse('$baseUrl/api/cart?user_id=$userId'));
      
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final List<dynamic> items = jsonResponse['cart_items'] ?? [];
        
        setState(() {
          cartItems = items;
          // Initialize all items as unselected
          selectedItems.clear();
          for (var item in items) {
            selectedItems[item['id']] = false;
          }
          calculateTotalForSelectedItems();
          isLoading = false;
        });
        
        // Debug log to verify data is being fetched
        print('Cart items loaded: ${cartItems.length} for user $userId');
        cartItems.forEach((item) => print('Item: ${item['product_name']}, Price: ${item['price']}, Qty: ${item['quantity']}'));
      } else {
        setState(() {
          error = 'Failed to load cart items. Status code: ${response.statusCode}';
          isLoading = false;
        });
        print('API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      setState(() {
        error = 'Error fetching cart items: $e';
        isLoading = false;
      });
      print('Exception while fetching cart: $e');
    }
  }

  // Calculate total price of selected items in cart
  void calculateTotalForSelectedItems() {
    totalPrice = 0.0;
    for (var item in cartItems) {
      if (selectedItems[item['id']] == true) {
        totalPrice += (double.parse(item['price'].toString()) * item['quantity']);
      }
    }
  }

  // Function to update the quantity of an item
  Future<void> updateQuantity(int itemId, int newQuantity) async {
    if (newQuantity < 1) return; // Don't allow quantities less than 1
    
    // Find the current item
    final currentItem = cartItems.firstWhere((item) => item['id'] == itemId, orElse: () => null);
    if (currentItem == null) return;
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/cart/update'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'id': itemId,
          'quantity': newQuantity
        }),
      );
      
      if (response.statusCode == 200) {
        // Update the UI without making another API call
        setState(() {
          final itemIndex = cartItems.indexWhere((item) => item['id'] == itemId);
          if (itemIndex != -1) {
            cartItems[itemIndex]['quantity'] = newQuantity;
            calculateTotalForSelectedItems();
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update quantity: ${response.body}'))
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'))
      );
    }
  }

  // Function to remove an item from the cart
  Future<void> removeItem(int itemId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/cart/remove'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'id': itemId,
        }),
      );
      
      if (response.statusCode == 200) {
        // Remove the item from the local list
        setState(() {
          cartItems.removeWhere((item) => item['id'] == itemId);
          // Also remove from selected items
          selectedItems.remove(itemId);
          calculateTotalForSelectedItems();
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Item removed from cart'))
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove item: ${response.body}'))
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'))
      );
    }
  }

  // Function to format image path correctly
  String formatImagePath(String? path) {
    if (path == null || path.isEmpty) return '';
    
    // If the path already starts with http, return it as is
    if (path.startsWith('http')) return path;
    
    // Otherwise, construct the full URL
    return '$baseUrl/static/uploads/$path';
  }

  // Function to process checkout
  void proceedToCheckout() {
    // Filter only selected items
    final selectedCartItems = cartItems.where((item) => selectedItems[item['id']] == true).toList();
    
    if (selectedCartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select items to checkout'))
      );
      return;
    }
    
    // Navigate to checkout page with the selected cart items
    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (context) => CheckoutPage(
          items: selectedCartItems,
          totalAmount: totalPrice,
          isBuyNow: false,
        ),
      ),
    );
  }

  // Select or deselect all items
  void toggleSelectAll(bool? value) {
    if (value == null) return;
    
    setState(() {
      for (var item in cartItems) {
        selectedItems[item['id']] = value;
      }
      calculateTotalForSelectedItems();
    });
  }

  // Count selected items
  int get selectedItemCount => selectedItems.values.where((selected) => selected).length;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Color(0xFF63C5DA),
          title: Text("Your Cart", style: TextStyle(color: Colors.white)),
          elevation: 0,
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (error != null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Color(0xFF63C5DA),
          title: Text("Your Cart", style: TextStyle(color: Colors.white)),
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 60, color: Colors.red),
              SizedBox(height: 16),
              Text('Something went wrong', style: TextStyle(fontSize: 18)),
              SizedBox(height: 8),
              Text(error!, style: TextStyle(color: Colors.grey[600])),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  if (error!.contains('log in')) {
                    // Navigate to login page if not logged in
                    // Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoginPage()));
                  } else {
                    // Try again for other errors
                    loadUserSession();
                  }
                },
                child: Text(error!.contains('log in') ? 'Go to Login' : 'Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF63C5DA),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (cartItems.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Color(0xFF63C5DA),
          title: Text("Your Cart", style: TextStyle(color: Colors.white)),
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey),
              SizedBox(height: 20),
              Text(
                "Your cart is empty!",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text("Start shopping now to add items to your cart."),
              SizedBox(height: 30),
              ElevatedButton(
                onPressed: () {
                  // Get the userData from the parent widget (BuyerHomePage)
                  final parentWidget = context.findAncestorWidgetOfExactType<BuyerHomePage>();
                  if (parentWidget != null) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => BuyerHomePage(userData: parentWidget.userData),
                      ),
                      (route) => false,
                    );
                  } else {
                    // Fallback if we can't get userData from parent
                    Navigator.of(context).pop();
                  }
                },
                child: Text("Browse Products"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF63C5DA),
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF63C5DA),
        title: Text("Your Cart", style: TextStyle(color: Colors.white)),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: fetchCartItems,
          ),
        ],
      ),
      body: Column(
        children: [
          // Select all checkbox
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Checkbox(
                  value: cartItems.isNotEmpty && 
                         cartItems.every((item) => selectedItems[item['id']] == true),
                  onChanged: toggleSelectAll,
                  activeColor: Color(0xFF63C5DA),
                ),
                Text("Select All Items", style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Divider(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: fetchCartItems,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                itemCount: cartItems.length,
                itemBuilder: (context, index) {
                  final item = cartItems[index];
                  return Dismissible(
                    key: Key(item['id'].toString()),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: EdgeInsets.only(right: 20),
                      color: Colors.red,
                      child: Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (direction) {
                      removeItem(item['id']);
                    },
                    child: Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 3,
                      margin: EdgeInsets.symmetric(vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Checkbox for selection
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0, top: 4.0),
                              child: Checkbox(
                                value: selectedItems[item['id']] ?? false,
                                onChanged: (bool? value) {
                                  setState(() {
                                    selectedItems[item['id']] = value ?? false;
                                    calculateTotalForSelectedItems();
                                  });
                                },
                                activeColor: Color(0xFF63C5DA),
                              ),
                            ),
                            // Product Image
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.grey[200],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  formatImagePath(item['image_path']),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    print('Error loading image: $error for path: ${formatImagePath(item['image_path'])}');
                                    return Icon(Icons.shopping_bag, size: 40, color: Colors.blueGrey);
                                  },
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center(
                                      child: CircularProgressIndicator(
                                        value: loadingProgress.expectedTotalBytes != null
                                            ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                            : null,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            SizedBox(width: 16),
                            // Product Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['product_name'] ?? 'Unnamed Product',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  if (item['Business_name'] != null && item['Business_name'].toString().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text(
                                        'Seller: ${item['Business_name']}',
                                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                      ),
                                    ),
                                  SizedBox(height: 8),
                                  Text(
                                    '₱${double.parse(item['price'].toString()).toStringAsFixed(2)}',
                                    style: TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(height: 12),
                                  // Quantity controls
                                  Row(
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.grey[300]!),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Row(
                                          children: [
                                            InkWell(
                                              onTap: () => updateQuantity(item['id'], item['quantity'] - 1),
                                              child: Container(
                                                padding: EdgeInsets.all(4),
                                                child: Icon(Icons.remove, size: 16),
                                              ),
                                            ),
                                            Container(
                                              padding: EdgeInsets.symmetric(horizontal: 12),
                                              child: Text('${item['quantity']}'),
                                            ),
                                            InkWell(
                                              onTap: () => updateQuantity(item['id'], item['quantity'] + 1),
                                              child: Container(
                                                padding: EdgeInsets.all(4),
                                                child: Icon(Icons.add, size: 16),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Spacer(),
                                      // Delete button
                                      IconButton(
                                        icon: Icon(Icons.delete_outline, color: Colors.red[400]),
                                        onPressed: () => removeItem(item['id']),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // Summary and checkout section
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Selected Items: $selectedItemCount', style: TextStyle(fontSize: 14)),
                    Text('Subtotal:', style: TextStyle(fontSize: 16)),
                    Text('₱${totalPrice.toStringAsFixed(2)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: proceedToCheckout,
                  child: Text("CHECKOUT", style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF63C5DA),
                    foregroundColor: Colors.white,
                    minimumSize: Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class NotificationsPage extends StatefulWidget {
  @override
  _NotificationsPageState createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> with TickerProviderStateMixin {
  List<dynamic> notifications = [];
  int unreadCount = 0;
  bool isLoading = true;
  late TabController _tabController;
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    fetchNotifications();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> fetchNotifications() async {
    // Get current user ID from your auth service
    final userId = await getUserId();
    
    if (userId == null) {
      setState(() {
        isLoading = false;
      });
      _showSnackBar('User not authenticated');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/notifications?user_id=$userId'),
      ).timeout(Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        setState(() {
          notifications = jsonResponse['notifications'] ?? [];
          unreadCount = jsonResponse['unread_count'] ?? 0;
          isLoading = false;
        });
      } else {
        _handleError('Server error: ${response.statusCode}');
      }
    } catch (e) {
      _handleError('Network error: $e');
    }
  }

  void _handleError(String message) {
    setState(() => isLoading = false);
    print(message);
    _showSnackBar('Failed to load notifications');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(10),
      ),
    );
  }

  Future<void> markAsRead(int notificationId) async {
    final userId = await getUserId();
    if (userId == null) return;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/notifications/mark-read'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'notification_id': notificationId,
          'user_id': userId,
        }),
      );

      if (response.statusCode == 200) {
        setState(() {
          final index = notifications.indexWhere((n) => n['id'] == notificationId);
          if (index >= 0) {
            notifications[index]['status'] = 'read';
            if (unreadCount > 0) unreadCount--;
          }
        });
      }
    } catch (e) {
      print('Failed to mark notification as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    final userId = await getUserId();
    if (userId == null) return;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/notifications/mark-all-read'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'user_id': userId}),
      );

      if (response.statusCode == 200) {
        setState(() {
          for (var notification in notifications) {
            notification['status'] = 'read';
          }
          unreadCount = 0;
        });
        _showSnackBar('All notifications marked as read');
      }
    } catch (e) {
      print('Failed to mark all notifications as read: $e');
      _showSnackBar('Failed to update notifications');
    }
  }

  // Replace this with your actual implementation to get user ID
  Future<int?> getUserId() async {
    // For example, from shared preferences or your auth service
    // SharedPreferences prefs = await SharedPreferences.getInstance();
    // return prefs.getInt('user_id');
    
    // Temporary placeholder - replace with your actual implementation
    return 4; // Using user_id 4 from your database sample
  }

  List<dynamic> get unreadNotifications => 
    notifications.where((n) => n['status'] == 'unread').toList();

  List<dynamic> get readNotifications => 
    notifications.where((n) => n['status'] == 'read').toList();

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            icon: Icon(Icons.refresh),
            label: Text('Refresh'),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Color(0xFF63C5DA),
              elevation: 2,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () => _refreshIndicatorKey.currentState?.show(),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(dynamic notif) {
    final bool isUnread = notif['status'] == 'unread';
    final message = notif['message'] ?? '';
    final orderId = notif['order_id'] ?? '';
    final title = getNotificationTitle(message, orderId);
    final IconData iconData = getNotificationIcon(message);
    final Color iconColor = getNotificationColor(message);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Card(
        elevation: isUnread ? 3 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isUnread 
              ? BorderSide(color: Theme.of(context).primaryColor.withOpacity(0.5), width: 1)
              : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            // Mark as read when opened
            if (isUnread) {
              markAsRead(notif['id']);
            }
            
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Row(
                  children: [
                    Icon(
                      iconData,
                      color: iconColor,
                      size: 24,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(message),
                      SizedBox(height: 12),
                      Text(
                        formatDateDetailed(notif['created_at']),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    child: Text("Close"),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).primaryColor,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.all(10),
                  child: Icon(
                    iconData,
                    color: iconColor,
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontWeight: isUnread ? FontWeight.bold : FontWeight.w500,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (isUnread)
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        message.length > 80 ? '${message.substring(0, 80)}...' : message,
                        style: TextStyle(
                          color: Colors.grey[700],
                          height: 1.3,
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: Colors.grey[400],
                          ),
                          SizedBox(width: 4),
                          Text(
                            formatDate(notif['created_at']),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData getNotificationIcon(String message) {
    if (message.contains('confirmed')) {
      return Icons.check_circle;
    } else if (message.contains('shipped')) {
      return Icons.local_shipping;
    } else if (message.contains('cancelled')) {
      return Icons.cancel;
    } else if (message.contains('payment')) {
      return Icons.payment;
    } else if (message.contains('delivered')) {
      return Icons.home;
    } else {
      return Icons.notifications;
    }
  }

  Color getNotificationColor(String message) {
    if (message.contains('confirmed')) {
      return Colors.green;
    } else if (message.contains('shipped')) {
      return Colors.blue;
    } else if (message.contains('cancelled')) {
      return Colors.red;
    } else if (message.contains('payment')) {
      return Colors.purple;
    } else if (message.contains('delivered')) {
      return Colors.orange;
    } else {
      return Color(0xFF63C5DA); // Default color
    }
  }

  String getNotificationTitle(String message, dynamic orderId) {
    if (message.contains('confirmed')) {
      return 'Order #$orderId Confirmed';
    } else if (message.contains('shipped')) {
      return 'Order #$orderId Shipped';
    } else if (message.contains('cancelled')) {
      return 'Order #$orderId Cancelled';
    } else if (message.contains('payment')) {
      return 'Payment Received';
    } else if (message.contains('delivered')) {
      return 'Order #$orderId Delivered';
    } else {
      return 'Notification';
    }
  }
  
  String formatDate(String? dateString) {
    if (dateString == null) return '';
    try {
      final DateTime date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays > 7) {
        // More than a week ago, show actual date
        return DateFormat('MMM d').format(date);
      } else if (difference.inDays > 0) {
        return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return dateString;
    }
  }

  String formatDateDetailed(String? dateString) {
    if (dateString == null) return '';
    try {
      final DateTime date = DateTime.parse(dateString);
      return DateFormat('EEEE, MMMM d, y • h:mm a').format(date);
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Color(0xFF63C5DA),
        elevation: 0,
        title: Text(
          "Notifications",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          if (unreadCount > 0)
            TextButton.icon(
              icon: Icon(Icons.done_all, color: Colors.white, size: 18),
              label: Text(
                "Mark all read",
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
              onPressed: markAllAsRead,
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: [
            Tab(
              text: unreadCount > 0 ? "Unread ($unreadCount)" : "Unread",
            ),
            Tab(text: "All"),
          ],
        ),
      ),
      body: SafeArea(
        child: isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF63C5DA)),
                    ),
                    SizedBox(height: 16),
                    Text(
                      "Loading notifications...",
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                key: _refreshIndicatorKey,
                color: Color(0xFF63C5DA),
                onRefresh: fetchNotifications,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Unread Notifications Tab
                    unreadNotifications.isEmpty
                        ? _buildEmptyState('No unread notifications')
                        : ListView.builder(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            itemCount: unreadNotifications.length,
                            itemBuilder: (context, index) {
                              return _buildNotificationItem(unreadNotifications[index]);
                            },
                          ),
                    
                    // All Notifications Tab
                    notifications.isEmpty
                        ? _buildEmptyState('No notifications found')
                        : ListView.builder(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            itemCount: notifications.length,
                            itemBuilder: (context, index) {
                              return _buildNotificationItem(notifications[index]);
                            },
                          ),
                  ],
                ),
              ),
      ),
    );
  }
}


//Me Page

class MePage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const MePage({Key? key, required this.userData}) : super(key: key);

  @override
  _MePageState createState() => _MePageState();
}

class _MePageState extends State<MePage> {
  late String name;
  late String email;
  String? profilePicturePath;

  @override
  void initState() {
    super.initState();
    name = widget.userData['name'] ?? 'User';
    email = widget.userData['email'] ?? 'No Email';
    
    // Set default profile picture to kim.jpg
    profilePicturePath = widget.userData['profilePicture'] ?? 'assets/kim.jpg';
    
    // Debug print to check the loaded data
    print('Profile picture path: $profilePicturePath');
  }

  // Method to determine the image provider
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

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Row(
            children: [
              Icon(Icons.logout, color: Color(0xFF63C5DA)),
              SizedBox(width: 10),
              Text('Logout'),
            ],
          ),
          content: Text('Are you sure you want to logout?'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('Logout', style: TextStyle(color: Colors.white)),
              onPressed: () async {
                // Clear the user session data using the correct method
                await UserSession.clearUserSession();
                
                // Close the dialog
                Navigator.of(context).pop();
                
                // Navigate to login page and remove all previous routes
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/login', 
                  (Route<dynamic> route) => false,
                );
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF63C5DA),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Color(0xFF63C5DA),
        elevation: 0,
        title: Text('Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Profile Header Section
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              children: [
                // Profile Picture
                CircleAvatar(
                  radius: 50,
                  backgroundImage: _getImageProvider(),
                  backgroundColor: Colors.white,
                ),
                SizedBox(height: 15),
                // User Info
                Text(name, style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(email, style: TextStyle(color: Colors.white, fontSize: 14)),
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text('1,232 Points', style: TextStyle(color: Color(0xFF63C5DA), fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          
          // Main Content Section
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: ListView(
                padding: EdgeInsets.all(20),
                children: [
                  // Purchase Status Row
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        _purchaseStatus(Icons.payment_outlined, 'To Pay', onTap: () {
                          Navigator.push(
                            context, 
                            MaterialPageRoute(builder: (context) => PurchaseNavigationPage(initialPage: 0))
                          );
                        }),
                        _purchaseStatus(Icons.local_shipping_outlined, 'To Ship', onTap: () {
                          Navigator.push(
                            context, 
                            MaterialPageRoute(builder: (context) => PurchaseNavigationPage(initialPage: 1))
                          );
                        }),
                        _purchaseStatus(Icons.inbox_outlined, 'To Receive', onTap: () {
                          Navigator.push(
                            context, 
                            MaterialPageRoute(builder: (context) => PurchaseNavigationPage(initialPage: 2))
                          );
                        }),
                        _purchaseStatus(Icons.star_rate_outlined, 'Rate', onTap: () {
                          Navigator.push(
                            context, 
                            MaterialPageRoute(builder: (context) => PurchaseNavigationPage(initialPage: 3))
                          );
                        }),
                      ],
                    ),
                  ),
                  
                  Divider(height: 40, thickness: 1, color: Colors.grey[200]),
                  
                  // Profile Options - Removed Account Details and now directly navigate to AccountSettingsPage
                  _profileOption(Icons.settings_outlined, 'Account Settings', onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AccountSettingsPage(userData: widget.userData),
                      ),
                    );
                  }),
                  _profileOption(Icons.help_outline, 'Help Centre'),
                  _profileOption(Icons.chat_outlined, 'Chat with MediaVerse'),
                  
                  SizedBox(height: 20),
                  
                  Divider(height: 40, thickness: 1, color: Colors.grey[200]),
                  
                  _profileOption(Icons.logout, 'Logout', onTap: _showLogoutConfirmation, isDestructive: true),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _purchaseStatus(IconData icon, String label, {VoidCallback? onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 4),
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          decoration: BoxDecoration(
            color: Color(0xFF63C5DA).withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 28, color: Color(0xFF63C5DA)),
              SizedBox(height: 8),
              Text(
                label, 
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileOption(IconData icon, String title, {VoidCallback? onTap, bool isDestructive = false}) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: Colors.grey[50],
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDestructive ? Colors.red.withOpacity(0.1) : Color(0xFF63C5DA).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: isDestructive ? Colors.red : Color(0xFF63C5DA), size: 22),
        ),
        title: Text(
          title, 
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: isDestructive ? Colors.red : Colors.black87,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios, 
          size: 16, 
          color: Colors.grey[400],
        ),
        onTap: onTap ?? () {},
      ),
    );
  }
}