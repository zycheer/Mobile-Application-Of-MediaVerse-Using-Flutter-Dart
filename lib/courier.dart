import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'user_authentication.dart';
import 'dart:io';
import 'EditProf.dart';
import 'accsett.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CourierHomePage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const CourierHomePage({Key? key, required this.userData}) : super(key: key);

  @override
  _CourierHomePageState createState() => _CourierHomePageState();
}

class _CourierHomePageState extends State<CourierHomePage> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _animationController;
  
  // Animation values for each tab
  final List<double> _animations = [1.0, 1.0, 1.0];

  @override
  void initState() {
    super.initState();
    
    // Create animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 200),
    );
    
    // Set initial animation value
    _animations[_selectedIndex] = 1.2;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (_selectedIndex != index) {
      setState(() {
        // Reset previous tab animation
        _animations[_selectedIndex] = 1.0;
        
        // Set new selected index
        _selectedIndex = index;
        
        // Animate new tab
        _animations[_selectedIndex] = 1.2;
        
        // Reset and forward animation
        _animationController.reset();
        _animationController.forward();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedIndex == 0 
          ? 'Courier Dashboard' 
          : _selectedIndex == 1 
              ? 'Deliveries' 
              : 'Profile'),
        backgroundColor: const Color(0xFF63C5DA),
      ),
      body: SafeArea(
        child: _buildSelectedScreen(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: [
          _buildAnimatedNavItem(Icons.home, 'Home', 0),
          _buildAnimatedNavItem(Icons.local_shipping, 'Deliveries', 1),
          _buildAnimatedNavItem(Icons.person, 'Profile', 2),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF63C5DA),
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        onTap: _onItemTapped,
      ),
    );
  }

  BottomNavigationBarItem _buildAnimatedNavItem(IconData icon, String label, int index) {
    return BottomNavigationBarItem(
      icon: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _animations[index],
            child: Icon(icon),
          );
        },
      ),
      label: label,
    );
  }

  Widget _buildSelectedScreen() {
    switch (_selectedIndex) {
      case 0:
        return HomeScreen(userData: widget.userData);
      case 1:
        return DeliveriesScreen();
      case 2:
        return ProfileScreen(userData: widget.userData);
      default:
        return HomeScreen(userData: widget.userData);
    }
  }
}

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  
  const HomeScreen({Key? key, required this.userData}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _recentDeliveries = [];
  bool _isLoading = true;
  String? _error;
  int _totalCompletedDeliveries = 0;
  double _totalEarnings = 0.0;
  final double _paymentPerDelivery = 15.0; // ₱15 per delivery

  @override
  void initState() {
    super.initState();
    _fetchRecentDeliveries();
    _fetchEarningsData();
  }

  Future<void> _fetchEarningsData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get courier ID from user session
      final courierId = await UserSession.getCurrentUserId();
      
      if (courierId == null) {
        setState(() {
          _error = 'User ID not available';
          _isLoading = false;
        });
        return;
      }

      final response = await UserSession.authenticatedRequest(
        '/get_courier_completed_deliveries/$courierId'
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Check if the server returns the completed deliveries count
        if (data.containsKey('completed_count')) {
          setState(() {
            _totalCompletedDeliveries = data['completed_count'];
            _totalEarnings = _totalCompletedDeliveries * _paymentPerDelivery;
            _isLoading = false;
          });
        } else {
          // If the endpoint doesn't directly return a count, calculate from deliveries
          final completedDeliveries = List<Map<String, dynamic>>.from(data['deliveries'] ?? []);
          
          setState(() {
            _totalCompletedDeliveries = completedDeliveries.length;
            _totalEarnings = _totalCompletedDeliveries * _paymentPerDelivery;
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _error = 'Failed to load earnings data';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Network error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchRecentDeliveries() async {
  setState(() {
    _isLoading = true;
    _error = null;
  });

  try {
    // Get courier ID from user session
    final courierId = await UserSession.getCurrentUserId();
    
    if (courierId == null) {
      setState(() {
        _error = 'User ID not available';
        _isLoading = false;
      });
      return;
    }
    
    final response = await UserSession.authenticatedRequest(
      '/get_courier_deliveries/$courierId'
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final allDeliveries = List<Map<String, dynamic>>.from(data['deliveries']);
      
      // Filter only completed deliveries for the Recent Deliveries section
      setState(() {
        _recentDeliveries = allDeliveries.where((delivery) => 
          delivery['status'] == 'Delivered').toList();
        
        // Limit to most recent 5 deliveries
        if (_recentDeliveries.length > 5) {
          _recentDeliveries = _recentDeliveries.sublist(0, 5);
        }
        
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = 'Failed to load recent deliveries';
        _isLoading = false;
      });
    }
  } catch (e) {
    setState(() {
      _error = 'Network error: $e';
      _isLoading = false;
    });
  }
}

  Future<void> _refreshData() async {
    await Future.wait([
      _fetchEarningsData(),
      _fetchRecentDeliveries(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Courier Earnings Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Courier Income',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF63C5DA),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total Earnings',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '₱${_totalEarnings.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF63C5DA).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.local_shipping,
                                size: 30,
                                color: Color(0xFF63C5DA),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '$_totalCompletedDeliveries',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF63C5DA),
                                ),
                              ),
                              const Text(
                                'Deliveries',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'You earn ₱$_paymentPerDelivery per successful delivery',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Completed Deliveries',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Color(0xFF63C5DA)),
                  onPressed: _refreshData,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildRecentDeliveriesList(),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentDeliveriesList() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _refreshData,
                child: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF63C5DA),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_recentDeliveries.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Text(
            'No completed deliveries yet',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _recentDeliveries.length,
      itemBuilder: (context, index) {
        final delivery = _recentDeliveries[index];
        
        // Format the completion date if available
        String completedDate = 'N/A';
        if (delivery['completed_at'] != null) {
          try {
            final date = DateTime.parse(delivery['completed_at']);
            completedDate = DateFormat('MMM d, yyyy • h:mm a').format(date);
          } catch (e) {
            completedDate = delivery['completed_at'].toString();
          }
        }
        
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Order #${delivery['order_id']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Delivered',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        delivery['Name'] ?? 'N/A',
                        style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.shopping_bag_outlined, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${delivery['product_name'] ?? 'N/A'} x${delivery['quantity_order'] ?? '1'}',
                        style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        delivery['PhysicalAddress'] ?? 'N/A',
                        style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time_outlined, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      completedDate,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '+₱$_paymentPerDelivery',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class DeliveriesScreen extends StatefulWidget {
  const DeliveriesScreen({Key? key}) : super(key: key);

  @override
  _DeliveriesScreenState createState() => _DeliveriesScreenState();
}

class _DeliveriesScreenState extends State<DeliveriesScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _confirmedOrders = [];
  List<Map<String, dynamic>> _assignedDeliveries = [];
  bool _isLoading = true;
  String? _error;
  late TabController _tabController;
  int? _courierId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Call getCourierId first, then fetch data once we have the ID
    _getCourierId();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Get the courier ID from SharedPreferences
  Future<void> _getCourierId() async {
    try {
      // Use UserSession class to get the current user ID
      final userId = await UserSession.getCurrentUserId();
      
      if (userId != null) {
        setState(() {
          _courierId = int.parse(userId.toString());
          print('Successfully retrieved courier ID: $_courierId');
        });
        // Now fetch data since we have the courier ID
        _fetchConfirmedOrders();
        _fetchAssignedDeliveries();
      } else {
        setState(() {
          _error = 'Could not retrieve courier ID. Please log in again.';
          _isLoading = false;
        });
        print('Failed to get courier ID - not found in session');
      }
    } catch (e) {
      setState(() {
        _error = 'Error retrieving user data: $e';
        _isLoading = false;
      });
      print('Exception when retrieving courier ID: $e');
    }
  }

  Future<void> _fetchConfirmedOrders() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await UserSession.authenticatedRequest('/get_confirmed_orders');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _confirmedOrders = List<Map<String, dynamic>>.from(data['orders']);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load orders: ${response.reasonPhrase}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Network error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchAssignedDeliveries() async {
    if (_courierId == null) {
      setState(() {
        _error = 'Courier ID not available. Please log in again.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Use the authenticated request method for secure API calls
      final response = await UserSession.authenticatedRequest('/get_courier_deliveries/$_courierId');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _assignedDeliveries = List<Map<String, dynamic>>.from(data['deliveries']);
          _isLoading = false;
        });
        print('Successfully loaded ${_assignedDeliveries.length} deliveries for courier $_courierId');
      } else {
        setState(() {
          _assignedDeliveries = [];
          _isLoading = false;
          _error = 'Failed to load deliveries: ${response.reasonPhrase}';
        });
        print('Failed to load deliveries: ${response.statusCode} - ${response.reasonPhrase}');
      }
    } catch (e) {
      setState(() {
        _assignedDeliveries = [];
        _isLoading = false;
        _error = 'Network error: $e';
      });
      print('Exception when loading deliveries: $e');
    }
  }

  Future<void> _acceptOrder(int orderId) async {
    if (_courierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Courier ID not found! Please login again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    try {
      final response = await UserSession.authenticatedRequest(
        '/accept_order',
        method: 'POST',
        body: {
          'order_id': orderId,
          'courier_id': _courierId,
        },
      );

      if (response.statusCode == 200) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order accepted! Ready for delivery.'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Refresh the lists
        _fetchConfirmedOrders();
        _fetchAssignedDeliveries();
      } else {
        final data = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['error'] ?? 'Failed to accept order'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Network error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Replace _markAsDelivered method in _DeliveriesScreenState class
Future<void> _markAsDelivered(int deliveryId) async {
  try {
    final response = await UserSession.authenticatedRequest(
      '/mark_delivered',
      method: 'POST',
      body: {
        'delivery_id': deliveryId,
      },
    );

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      final paymentAmount = responseData['payment'] ?? 0;
      
      // Show success message with earned amount
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order marked as delivered! You earned ₱$paymentAmount'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Refresh the lists
      _fetchAssignedDeliveries();
    } else {
      final data = json.decode(response.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(data['error'] ?? 'Failed to update delivery status'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Network error: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deliveries'),
        backgroundColor: const Color(0xFF63C5DA),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Available Orders'),
            Tab(text: 'My Deliveries'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _getCourierId(); // This will also fetch orders and deliveries
        },
        child: _error != null && _error!.contains('Courier ID') 
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _error!,
                      style: TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/login');
                      },
                      child: Text('Login Again'),
                    )
                  ],
                ),
              )
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildAvailableOrdersTab(),
                  _buildMyDeliveriesTab(),
                ],
              ),
      ),
    );
  }
  
  Widget _buildAvailableOrdersTab() {
    if (_isLoading && _confirmedOrders.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _confirmedOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchConfirmedOrders,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_confirmedOrders.isEmpty) {
      return const Center(
        child: Text('No available orders to pick up at the moment'),
      );
    }

    return ListView.builder(
      itemCount: _confirmedOrders.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final order = _confirmedOrders[index];
        return Card(
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Order #${order['id']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Confirmed',
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildInfoRow('Customer', order['Name']),
                _buildInfoRow('Product', order['product_name']),
                _buildInfoRow('Price', 'PHP ${order['price']}'),
                _buildInfoRow('Quantity', order['quantity_order'].toString()),
                _buildInfoRow('Total', 'PHP ${order['total']}'),
                _buildInfoRow('Address', order['PhysicalAddress']),
                _buildInfoRow('Phone', order['PhoneNumber']),
                _buildInfoRow('Payment', order['payment_method']),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF63C5DA),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => _acceptOrder(order['id']),
                    child: const Text(
                      'Pick Up',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMyDeliveriesTab() {
    if (_isLoading && _assignedDeliveries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _assignedDeliveries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchAssignedDeliveries,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_assignedDeliveries.isEmpty) {
      return const Center(
        child: Text('You have no assigned deliveries'),
      );
    }

    return ListView.builder(
      itemCount: _assignedDeliveries.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final delivery = _assignedDeliveries[index];
        final bool isShippedOut = delivery['status'] == 'Shipped Out';
        final bool isInTransit = delivery['status'] == 'In Transit';
        
        // Set colors based on status
        Color statusColor = Colors.grey;
        Color buttonColor = const Color(0xFF63C5DA);
        
        if (isShippedOut) {
          statusColor = Colors.blue;
          buttonColor = Colors.green;
        } else if (isInTransit) {
          statusColor = Colors.orange;
          buttonColor = Colors.green;
        } else if (delivery['status'] == 'Delivered') {
          statusColor = Colors.green;
          buttonColor = Colors.grey;
        }
        
        return Card(
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Order #${delivery['order_id']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        delivery['status'],
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildInfoRow('Customer', delivery['Name'] ?? 'N/A'),
                _buildInfoRow('Product', delivery['product_name'] ?? 'N/A'),
                _buildInfoRow('Price', 'PHP ${delivery['price'] ?? '0.00'}'),
                _buildInfoRow('Quantity', (delivery['quantity_order'] ?? '1').toString()),
                _buildInfoRow('Total', 'PHP ${delivery['total'] ?? '0.00'}'),
                _buildInfoRow('Address', delivery['PhysicalAddress'] ?? 'N/A'),
                _buildInfoRow('Phone', delivery['PhoneNumber'] ?? 'N/A'),
                _buildInfoRow('Payment', delivery['payment_method'] ?? 'N/A'),
                const SizedBox(height: 16),
                delivery['status'] != 'Delivered' ? SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: delivery['status'] != 'Delivered' ? 
                        () => _markAsDelivered(delivery['id']) : null,
                    child: const Text(
                      'Mark as Delivered',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ) : const SizedBox.shrink(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const ProfileScreen({Key? key, required this.userData}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late String name;
  late String email;
  late String businessName;
  late String phoneNumber;
  late String address;
  String? profilePicturePath;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    name = widget.userData['name'] ?? 'Courier Name';
    email = widget.userData['email'] ?? 'email@example.com';
    businessName = widget.userData['business_name'] ?? 'Business Name';
    phoneNumber = widget.userData['phone_number'] ?? '+1 234 567 8900';
    address = widget.userData['address'] ?? '123 Delivery St, Courier City';
    
    // Set default profile picture
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
                // Clear the user session data
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

  // Modified to navigate to AccountSettingsPage instead of EditProfileScreen
  void _navigateToAccountSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AccountSettingsPage(
          userData: {
            'name': name,
            'email': email,
            'business_name': businessName,
            'phone_number': phoneNumber,
            'physical_address': address,
            'profilePicture': profilePicturePath,
          },
        ),
      ),
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
                  child: Text(businessName, style: TextStyle(color: Color(0xFF63C5DA), fontSize: 12, fontWeight: FontWeight.bold)),
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
                  // Settings Section
                  _sectionTitle('Settings'),
                  SizedBox(height: 10),
                  
                  // Changed to navigate to AccountSettingsPage
                  _profileOption(Icons.edit, 'Account Settings', onTap: _navigateToAccountSettings),
                  
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
  
  Widget _sectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(left: 8, bottom: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF63C5DA),
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