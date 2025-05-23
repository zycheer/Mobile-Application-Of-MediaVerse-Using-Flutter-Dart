import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'buyerhome.dart'; // For CartPage
import 'checkout.dart'; // Import the checkout page

const String baseUrl = 'http://192.168.0.21:5000';

class ProductViewPage extends StatefulWidget {
  final Map<String, dynamic> product;
  final Map<String, dynamic> userData;

  const ProductViewPage({
    Key? key,
    required this.product,
    required this.userData,
  }) : super(key: key);

  @override
  State<ProductViewPage> createState() => _ProductViewPageState();
}

class _ProductViewPageState extends State<ProductViewPage> {
  int quantity = 1;
  bool isAddingToCart = false;
  bool isBuyingNow = false;
  bool isFavorite = false;
  
  // Add variables for ratings and reviews
  double averageRating = 0.0;
  int reviewCount = 0;
  List<Map<String, dynamic>> reviews = [];
  bool isLoadingReviews = true;

  @override
  void initState() {
    super.initState();
    // Fetch product ratings and reviews on page load
    fetchProductRatings();
    fetchProductReviews();
  }

  // Fetch average rating for the product
  Future<void> fetchProductRatings() async {
    try {
      final productId = widget.product.containsKey('id') 
          ? int.tryParse(widget.product['id'].toString()) ?? 0
          : int.tryParse(widget.product['product_id'].toString()) ?? 0;
      
      final response = await http.get(
        Uri.parse('$baseUrl/get_product_rating/$productId'),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          averageRating = data['rating'] is double 
              ? data['rating'] 
              : double.parse(data['rating'].toString());
          reviewCount = data['count'] is int 
              ? data['count'] 
              : int.parse(data['count'].toString());
        });
      }
    } catch (e) {
      print('Error fetching product ratings: $e');
    }
  }

  // Fetch recent reviews for the product
  Future<void> fetchProductReviews() async {
    setState(() {
      isLoadingReviews = true;
    });
    
    try {
      final productId = widget.product.containsKey('id') 
          ? int.tryParse(widget.product['id'].toString()) ?? 0
          : int.tryParse(widget.product['product_id'].toString()) ?? 0;
      
      final response = await http.get(
        Uri.parse('$baseUrl/get_product_reviews/$productId'),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          reviews = List<Map<String, dynamic>>.from(data['reviews']);
          isLoadingReviews = false;
        });
      } else {
        setState(() {
          isLoadingReviews = false;
        });
      }
    } catch (e) {
      print('Error fetching product reviews: $e');
      setState(() {
        isLoadingReviews = false;
      });
    }
  }

  // Add to cart method
  Future<void> addToCart() async {
    try {
      final product = widget.product;
      final stock = int.tryParse(product['stock_quantity']?.toString() ?? '0') ?? 0;

      // Check if quantity exceeds stock before proceeding
      if (quantity > stock) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot add to cart: Quantity exceeds available stock ($stock items available)'),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        isAddingToCart = true;
      });

      // Get user_id from userData, ensure it's not null
      final userId = widget.userData['id'] ?? widget.userData['user_id'] ?? widget.userData['ID'];
      
      if (userId == null) {
        throw Exception('User ID not found in session data');
      }

      // Debug: Print the entire product object
      print('Product data: $product');
      print('User ID from session: $userId');
      
      // Extract product_id - check multiple possible field names
      int productId = 0;
      if (product.containsKey('id')) {
        productId = int.tryParse(product['id'].toString()) ?? 0;
      } else if (product.containsKey('product_id')) {
        productId = int.tryParse(product['product_id'].toString()) ?? 0;
      }
      
      // Extract seller_id but don't set a default value
      int? sellerId;
      if (product.containsKey('seller_id') && product['seller_id'] != null) {
        sellerId = int.tryParse(product['seller_id'].toString());
        print('Found seller_id in product data: $sellerId');
      }
      
      // We'll send the minimum data needed
      final payload = {
        'user_id': userId,
        'product_id': productId,
        'quantity': quantity,
      };
      
      // Only include seller_id if we actually have it
      if (sellerId != null) {
        payload['seller_id'] = sellerId;
      }

      print('Sending to API: ${json.encode(payload)}');

      final response = await http.post(
        Uri.parse('$baseUrl/api/cart/add'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      setState(() {
        isAddingToCart = false;
      });

      print('API Response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        setState(() {
          quantity = 1;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Item added to cart'),
            action: SnackBarAction(
              label: 'VIEW CART',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => CartPage()),
                );
              },
            ),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add item: ${response.body}'),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() {
        isAddingToCart = false;
      });
      print('Error adding to cart: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Buy now method to directly go to checkout
  Future<void> buyNow() async {
    try {
      final product = widget.product;
      final stock = int.tryParse(product['stock_quantity']?.toString() ?? '0') ?? 0;

      // Check if quantity exceeds stock before proceeding
      if (quantity > stock) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot proceed: Quantity exceeds available stock ($stock items available)'),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      setState(() {
        isBuyingNow = true;
      });
      
      // Create a list with just this product for checkout
      final checkoutItem = {
        'product_id': product.containsKey('id') 
            ? int.tryParse(product['id'].toString()) ?? 0
            : int.tryParse(product['product_id'].toString()) ?? 0,
        'product_name': product['product_name'],
        'price': double.tryParse(product['price'].toString()) ?? 0.0,
        'quantity': quantity,
        'seller_id': product['seller_id'] != null 
            ? int.tryParse(product['seller_id'].toString()) 
            : null,
        'image_path': product['product_image'],
      };

      // Calculate total amount
      final totalAmount = (double.tryParse(product['price'].toString()) ?? 0.0) * quantity;

      setState(() {
        isBuyingNow = false;
      });

      // Navigate directly to checkout page with this item only
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CheckoutPage(
            items: [checkoutItem],
            totalAmount: totalAmount,
            isBuyNow: true, // Indicate this is a direct purchase
          ),
        ),
      );
    } catch (e) {
      setState(() {
        isBuyingNow = false;
      });
      print('Error buying now: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Helper method to display star rating
  Widget buildRatingStars(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < rating.floor()) {
          // Full star
          return Icon(Icons.star, color: Colors.amber, size: 18);
        } else if (index == rating.floor() && rating % 1 > 0) {
          // Half star
          return Icon(Icons.star_half, color: Colors.amber, size: 18);
        } else {
          // Empty star
          return Icon(Icons.star_border, color: Colors.amber, size: 18);
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final stock = int.tryParse(product['stock_quantity']?.toString() ?? '0') ?? 0;
    final sellerName = product['business_name'] ?? 'Unknown Seller';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          product['product_name'] ?? 'Product Details',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF63C5DA),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.shopping_cart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CartPage()),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            height: MediaQuery.of(context).size.height * 0.35,
            color: const Color(0xFF63C5DA).withOpacity(0.2),
          ),
          ListView(
            padding: EdgeInsets.zero,
            children: [
              // Product Image with Overlay
              Stack(
                children: [
                  Hero(
                    tag: 'product-${product['id'] ?? ''}',
                    child: Container(
                      height: MediaQuery.of(context).size.height * 0.35,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: product['product_image'] != null
                          ? Image.network(
                              product['product_image'],
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.image, size: 100, color: Colors.grey),
                                );
                              },
                            )
                          : Container(
                              color: Colors.grey[200],
                              child: const Icon(Icons.image, size: 100, color: Colors.grey),
                            ),
                    ),
                  ),
                  // Favorite button
                  Positioned(
                    top: 10,
                    right: 10,
                    child: CircleAvatar(
                      backgroundColor: Colors.white.withOpacity(0.9),
                      radius: 20,
                      child: IconButton(
                        icon: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: isFavorite ? Colors.red : Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            isFavorite = !isFavorite;
                          });
                          // TODO: Add to favorites functionality
                        },
                      ),
                    ),
                  ),
                  // Stock indicator
                  if (stock <= 5 && stock > 0)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Only $stock left!',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  if (stock == 0)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Out of Stock',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),

              // Product Details Card
              Transform.translate(
                offset: Offset(0, -20),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Seller info row with avatar
                        GestureDetector(
                          onTap: () {
                            // TODO: Navigate to seller page
                          },
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: const Color(0xFF63C5DA).withOpacity(0.2),
                                child: Text(
                                  sellerName.isNotEmpty ? sellerName[0].toUpperCase() : '?',
                                  style: TextStyle(
                                    color: const Color(0xFF63C5DA),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      sellerName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      'Verified Seller',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right, color: Colors.grey),
                            ],
                          ),
                        ),
                        
                        Divider(height: 20),
                        
                        // Product title and price
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product['product_name'] ?? '',
                                    style: TextStyle(
                                      fontSize: 22, 
                                      fontWeight: FontWeight.bold,
                                      height: 1.2,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  // Ratings display
                                  Row(
                                    children: [
                                      buildRatingStars(averageRating),
                                      SizedBox(width: 8),
                                      Text(
                                        '${averageRating.toStringAsFixed(1)} (${reviewCount} reviews)',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '₱${product['price'] ?? "0.00"}',
                                  style: TextStyle(
                                    fontSize: 24, 
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (stock > 0)
                                  Text(
                                    'In Stock: $stock',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.green,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        
                        SizedBox(height: 16),
                        
                        // Description
                        Text(
                          'Description',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          product['main_description'] ?? 'No description available',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                            height: 1.5,
                          ),
                        ),
                        
                        SizedBox(height: 24),
                        
                        // Quantity selector
                        Text(
                          'Quantity',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.remove, size: 20),
                                onPressed: quantity > 1 && stock > 0
                                    ? () => setState(() => quantity--)
                                    : null,
                                color: const Color(0xFF63C5DA),
                              ),
                              Container(
                                width: 60,
                                height: 40,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  border: Border(
                                    left: BorderSide(color: Colors.grey.shade300),
                                    right: BorderSide(color: Colors.grey.shade300),
                                  ),
                                ),
                                child: TextFormField(
                                  initialValue: quantity.toString(),
                                  textAlign: TextAlign.center,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  onChanged: (value) {
                                  final newQuantity = int.tryParse(value) ?? 0;
                                  if (newQuantity > 0) {
                                    if (newQuantity > stock && stock > 0) {
                                      // Show warning when exceeding stock
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Maximum available stock is $stock'),
                                          duration: Duration(seconds: 2),
                                          behavior: SnackBarBehavior.floating,
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                      // We'll still set the quantity to what user entered
                                      // but the add to cart/buy now validations will prevent checkout
                                      setState(() {
                                        quantity = newQuantity;
                                      });
                                    } else {
                                      setState(() {
                                        quantity = newQuantity;
                                      });
                                    }
                                  }
                                },
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.add, size: 20),
                                onPressed: quantity < stock && stock > 0
                                    ? () => setState(() => quantity++)
                                    : null,
                                color: const Color(0xFF63C5DA),
                              ),
                            ],
                          ),
                        ),
                        
                        SizedBox(height: 24),
                        
                        // Action buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: Icon(Icons.shopping_cart),
                                label: isAddingToCart
                                    ? SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : Text('Add to Cart'),
                                onPressed: stock == 0 || isAddingToCart || isBuyingNow
                                    ? null
                                    : () => addToCart(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF63C5DA),
                                  padding: EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: Icon(Icons.flash_on),
                                label: isBuyingNow
                                    ? SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : Text('Buy Now'),
                                onPressed: stock == 0 || isAddingToCart || isBuyingNow
                                    ? null
                                    : () => buyNow(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  padding: EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        SizedBox(height: 30),
                        
                        // Reviews Section
                        Text(
                          'Customer Reviews',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 16),
                        
                        // Display reviews or loading indicator
                        isLoadingReviews
                            ? Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF63C5DA)),
                                ),
                              )
                            : reviews.isEmpty
                                ? Center(
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.rate_review_outlined,
                                          size: 60,
                                          color: Colors.grey[400],
                                        ),
                                        SizedBox(height: 16),
                                        Text(
                                          'No reviews yet',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.separated(
                                    physics: NeverScrollableScrollPhysics(),
                                    shrinkWrap: true,
                                    itemCount: reviews.length,
                                    separatorBuilder: (context, index) => Divider(height: 24),
                                    itemBuilder: (context, index) {
                                      final review = reviews[index];
                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                backgroundColor: Colors.grey[200],
                                                radius: 18,
                                                child: Text(
                                                  review['Name'] != null && review['Name'].isNotEmpty
                                                      ? review['Name'][0].toUpperCase()
                                                      : '?',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(width: 12),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    review['Name'] ?? 'Anonymous',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  Text(
                                                    review['created_at'] ?? '',
                                                    style: TextStyle(
                                                      color: Colors.grey[600],
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Spacer(),
                                              buildRatingStars(
                                                review['rating'] is int
                                                    ? review['rating'].toDouble()
                                                    : double.parse(review['rating'].toString()),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            review['comment'] ?? '',
                                            style: TextStyle(
                                              fontSize: 14,
                                              height: 1.4,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                        
                        SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}