import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// API base URL - change this to your server address
const String baseApiUrl = 'http://192.168.0.21:5000'; // For Android emulator
// Use 'http://localhost:5000' for iOS simulator or web
// Use your actual server IP for physical devices

// Utility function for parsing doubles safely
double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  if (value is String) {
    try {
      return double.parse(value);
    } catch (e) {
      return 0.0;
    }
  }
  return 0.0;
}

class PurchaseNavigationPage extends StatefulWidget {
  final int initialPage;

  const PurchaseNavigationPage({Key? key, required this.initialPage}) : super(key: key);

  @override
  _PurchaseNavigationPageState createState() => _PurchaseNavigationPageState();
}

class _PurchaseNavigationPageState extends State<PurchaseNavigationPage> {
  late int _selectedIndex;
  bool _isLoading = true;
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialPage;
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch orders from API
      final response = await http.get(Uri.parse('$baseApiUrl/get_orders'));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _orders = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load orders: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching orders: $e');
      // Show an error message to the user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load orders. Please try again later.')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Update order status
  Future<void> _updateOrderStatus(int orderId, String newStatus) async {
    try {
      // Make API call to update status
      final response = await http.post(
        Uri.parse('$baseApiUrl/api/update_status/$orderId'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({'status': newStatus})
      );
      
      if (response.statusCode == 200) {
        // Update local state immediately for UI feedback
        setState(() {
          final orderIndex = _orders.indexWhere((order) => order['id'] == orderId);
          if (orderIndex != -1) {
            _orders[orderIndex]['status'] = newStatus;
          }
        });
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order marked as $newStatus')),
        );
      } else {
        throw Exception('Failed to update order status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating order status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update order status. Please try again later.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Purchases'),
        backgroundColor: Color(0xFF63C5DA),
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: Color(0xFF63C5DA)))
        : RefreshIndicator(
            onRefresh: _fetchOrders,
            color: Color(0xFF63C5DA),
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                ToPayPage(
                  orders: _orders.where((order) => 
                    order['status'] == 'Pending' || order['status'] == 'Confirmed' || order['status'] == 'To Pay').toList(),
                  updateOrderStatus: _updateOrderStatus,
                ),
                ToShipPage(
                  orders: _orders.where((order) => 
                    order['status'] == 'Shipped Out').toList(),
                ),
                ToReceivePage(
                  orders: _orders.where((order) => 
                    order['status'] == 'Shipped Out').toList(),
                  updateOrderStatus: _updateOrderStatus,
                ),
                CompletedPage(
                  orders: _orders.where((order) => 
                    order['status'] == 'Completed').toList(),
                ),
                CancelledPage(
                  orders: _orders.where((order) => 
                    order['status'] == 'Cancelled').toList(),
                ),
              ],
            ),
          ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        selectedItemColor: Color(0xFF63C5DA),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.payment),
            label: 'To Pay',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_shipping),
            label: 'To Ship',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inbox),
            label: 'To Receive',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.check_circle),
            label: 'Completed',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.cancel),
            label: 'Cancelled',
          ),
        ],
      ),
    );
  }
}

class ToPayPage extends StatelessWidget {
  final List<Map<String, dynamic>> orders;
  final Function(int, String) updateOrderStatus;

  const ToPayPage({Key? key, required this.orders, required this.updateOrderStatus}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return orders.isEmpty
        ? _buildEmptyState('No pending payments')
        : ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return _buildPaymentItem(
                context,
                orderNumber: 'Order #${order['id']}',
                productName: order['product_name'],
                status: order['status'],
                amount: _parseDouble(order['total']),
                orderId: order['id'],
              );
            },
          );
  }

  Widget _buildPaymentItem(
    BuildContext context, {
    required String orderNumber,
    required String productName,
    required String status,
    required double amount,
    required int orderId,
  }) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  orderNumber,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: status == 'Confirmed' ? Colors.green[100] : Colors.orange[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: status == 'Confirmed' ? Colors.green[800] : Colors.orange[800],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              productName,
              style: TextStyle(fontSize: 15),
            ),
            SizedBox(height: 8),
            Text(
              '₱${amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF63C5DA),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hourglass_empty, size: 60, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

class ToShipPage extends StatelessWidget {
  final List<Map<String, dynamic>> orders;

  const ToShipPage({Key? key, required this.orders}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return orders.isEmpty
        ? _buildEmptyState('No items to ship')
        : ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return _buildShippingItem(
                orderNumber: 'Order #${order['id']}',
                productName: order['product_name'],
                status: order['status'],
                createdAt: order['created_at'],
              );
            },
          );
  }

  Widget _buildShippingItem({
    required String orderNumber,
    required String productName,
    required String status,
    required String createdAt,
  }) {
    // Format date for display
    DateTime orderDate = DateTime.parse(createdAt);
    String formattedDate = "${orderDate.day}/${orderDate.month}/${orderDate.year}";

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  orderNumber,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: Colors.blue[800],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              productName,
              style: TextStyle(fontSize: 15),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                SizedBox(width: 4),
                Text(
                  'Order Date: $formattedDate',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.local_shipping, size: 14, color: Colors.grey[600]),
                SizedBox(width: 4),
                Text(
                  'Processing for shipping',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            // "Track Shipment" button removed from here
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hourglass_empty, size: 60, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

class ToReceivePage extends StatelessWidget {
  final List<Map<String, dynamic>> orders;
  final Function(int, String) updateOrderStatus;

  const ToReceivePage({Key? key, required this.orders, required this.updateOrderStatus}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return orders.isEmpty
        ? _buildEmptyState('No items to receive')
        : ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return _buildReceiveItem(
                context,
                orderNumber: 'Order #${order['id']}',
                productName: order['product_name'],
                status: order['status'],
                createdAt: order['created_at'],
                orderId: order['id'],
              );
            },
          );
  }

  Widget _buildReceiveItem(
    BuildContext context, {
    required String orderNumber,
    required String productName,
    required String status,
    required String createdAt,
    required int orderId,
  }) {
    // Calculate expected delivery date (example: 3 days after order date)
    DateTime orderDate = DateTime.parse(createdAt);
    DateTime expectedDelivery = orderDate.add(Duration(days: 3));
    String formattedDelivery = "${expectedDelivery.day}/${expectedDelivery.month}/${expectedDelivery.year}";

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  orderNumber,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: Colors.blue[800],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              productName,
              style: TextStyle(fontSize: 15),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                SizedBox(width: 4),
                Text(
                  'Expected: $formattedDelivery',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Show confirmation dialog
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: Text('Confirm Receipt'),
                        content: Text('Have you received this order?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text('No', style: TextStyle(color: Colors.grey[600])),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              updateOrderStatus(orderId, 'Completed');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF63C5DA),
                            ),
                            child: Text('Yes, Received', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      );
                    },
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF63C5DA),
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text('Order Received', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hourglass_empty, size: 60, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

class CompletedPage extends StatelessWidget {
  final List<Map<String, dynamic>> orders;

  const CompletedPage({Key? key, required this.orders}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return orders.isEmpty
        ? _buildEmptyState('No completed orders')
        : ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return _buildCompletedItem(
                context,
                orderNumber: 'Order #${order['id']}',
                productName: order['product_name'],
                total: _parseDouble(order['total']),
                createdAt: order['created_at'],
                orderId: order['id'], // Pass the orderId
              );
            },
          );
  }

  Widget _buildCompletedItem(
    BuildContext context, {
    required String orderNumber,
    required String productName,
    required double total,
    required String createdAt,
    required int orderId, // Add orderId parameter
  }) {
    // Format date for display
    DateTime orderDate = DateTime.parse(createdAt);
    String formattedDate = "${orderDate.day}/${orderDate.month}/${orderDate.year}";

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  orderNumber,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Completed',
                    style: TextStyle(
                      color: Colors.green[800],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              productName,
              style: TextStyle(fontSize: 15),
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                SizedBox(width: 4),
                Text(
                  'Completed on: $formattedDate',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            SizedBox(height: 4),
            Text(
              '₱${total.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF63C5DA),
              ),
            ),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // Pass the orderId to the rating dialog
                      _showRatingDialog(context, productName, orderId);
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Color(0xFF63C5DA)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text('Rate', style: TextStyle(color: Color(0xFF63C5DA))),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // Implement buy again action
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF63C5DA),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text('Buy Again', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // First, add this function to post rating to the database
Future<bool> submitFeedback(int orderId, int rating, String comment) async {
  try {
    final response = await http.post(
      Uri.parse('$baseApiUrl/submit_feedback'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'order_id': orderId,
        'rating': rating,
        'comment': comment,
      }),
    );
    
    if (response.statusCode == 200) {
      return true;
    } else {
      print('Failed to submit feedback: ${response.statusCode}');
      print('Response body: ${response.body}');
      return false;
    }
  } catch (e) {
    print('Error submitting feedback: $e');
    return false;
  }
}

// Then, update the _showRatingDialog function in CompletedPage class
void _showRatingDialog(BuildContext context, String productName, int orderId) {
  int rating = 3; // Default rating
  final TextEditingController commentController = TextEditingController();
  bool isSubmitting = false;

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Rate Product'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('How would you rate $productName?'),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      icon: Icon(
                        index < rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 36,
                      ),
                      onPressed: () {
                        setState(() {
                          rating = index + 1;
                        });
                      },
                    );
                  }),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: commentController,
                  decoration: InputDecoration(
                    hintText: 'Add a comment (optional)',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  maxLines: 3,
                ),
                if (isSubmitting)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: CircularProgressIndicator(color: Color(0xFF63C5DA)),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.of(context).pop(),
                child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        setState(() {
                          isSubmitting = true;
                        });

                        // Submit rating to the server
                        final success = await submitFeedback(
                          orderId,
                          rating,
                          commentController.text,
                        );

                        // Close dialog
                        Navigator.of(context).pop();
                        
                        // Show result message
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? 'Thank you for your $rating-star rating!'
                                  : 'Failed to submit rating. Please try again.',
                            ),
                            backgroundColor: success ? Colors.green : Colors.red,
                          ),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF63C5DA),
                ),
                child: Text('Submit', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      );
    },
  );
}

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hourglass_empty, size: 60, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

class CancelledPage extends StatelessWidget {
  final List<Map<String, dynamic>> orders;

  const CancelledPage({Key? key, required this.orders}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return orders.isEmpty
        ? _buildEmptyState('No cancelled orders')
        : ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return _buildCancelledItem(
                orderNumber: 'Order #${order['id']}',
                productName: order['product_name'],
                total: _parseDouble(order['total']),
                createdAt: order['created_at'],
              );
            },
          );
  }

  Widget _buildCancelledItem({
    required String orderNumber,
    required String productName,
    required double total,
    required String createdAt,
  }) {
    // Format date for display
    DateTime orderDate = DateTime.parse(createdAt);
    String formattedDate = "${orderDate.day}/${orderDate.month}/${orderDate.year}";

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  orderNumber,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Cancelled',
                    style: TextStyle(
                      color: Colors.red[800],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              productName,
              style: TextStyle(fontSize: 15),
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                SizedBox(width: 4),
                Text(
                  'Cancelled on: $formattedDate',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            SizedBox(height: 4),
            Text(
              '₱${total.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.grey[600],
                decoration: TextDecoration.lineThrough,
              ),
            ),
            SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  // Implement buy again action
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Color(0xFF63C5DA)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text('Order Again', style: TextStyle(color: Color(0xFF63C5DA))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hourglass_empty, size: 60, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}