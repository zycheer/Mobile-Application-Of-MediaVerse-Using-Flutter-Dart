import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// CHANGE 1: Update the base URL to match your Flask server
const String baseUrl = 'http://192.168.0.21:5000';

class MessagesPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const MessagesPage({Key? key, required this.userData}) : super(key: key);

  @override
  _MessagesPageState createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  List<dynamic> conversations = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    fetchConversations();
  }

  Future<void> fetchConversations() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      // CHANGE 2: Ensure query parameter is correctly formatted
      final response = await http.get(
        Uri.parse('$baseUrl/api/messages?user_id=${widget.userData['id']}')
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        setState(() {
          // CHANGE 3: Directly use 'conversations' key from response
          conversations = jsonResponse['conversations'] ?? [];
          isLoading = false;
        });
      } else {
        setState(() {
          error = 'Failed to load conversations';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Network error: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF63C5DA),
        title: Text('Messages', style: TextStyle(color: Colors.white)),
        elevation: 0,
      ),
      body: isLoading 
        ? Center(child: CircularProgressIndicator())
        : error != null
          ? Center(child: Text(error!, style: TextStyle(color: Colors.red)))
          : conversations.isEmpty
            ? Center(child: Text('No conversations yet'))
            : ListView.builder(
                itemCount: conversations.length,
                itemBuilder: (context, index) {
                  final conversation = conversations[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Color(0xFF63C5DA),
                      child: Text(
                        conversation['business_name'][0].toUpperCase(), 
                        style: TextStyle(color: Colors.white)
                      ),
                    ),
                    title: Text(
                      conversation['business_name'], 
                      style: TextStyle(fontWeight: FontWeight.bold)
                    ),
                    subtitle: Text(
                      conversation['last_message'] ?? 'No messages',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(
                      _formatTimestamp(conversation['last_message_time']),
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ConversationDetailPage(
                            userData: widget.userData,
                            sellerId: conversation['seller_id'],
                            businessName: conversation['business_name'],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
    );
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return '';
    
    final DateTime dateTime = DateTime.parse(timestamp);
    final DateTime now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inHours < 24) {
      // Show time for today's messages
      return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      // Show day for messages within a week
      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[dateTime.weekday - 1];
    } else {
      // Show date for older messages
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}

class ConversationDetailPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  final int sellerId;
  final String businessName;

  const ConversationDetailPage({
    Key? key, 
    required this.userData, 
    required this.sellerId,
    required this.businessName,
  }) : super(key: key);

  @override
  _ConversationDetailPageState createState() => _ConversationDetailPageState();
}

class _ConversationDetailPageState extends State<ConversationDetailPage> {
  List<dynamic> messages = [];
  final TextEditingController _messageController = TextEditingController();
  bool isLoading = true;
  String? error;
  late int _userId;
  late int _orderId;

  @override
  void initState() {
    super.initState();
    _userId = widget.userData['id'];
    fetchConversationMessages();
  }

  Future<void> fetchConversationMessages() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      // CHANGE 4: Ensure query parameters are correctly formatted
      final response = await http.get(
        Uri.parse('$baseUrl/api/messages/conversation?user_id=$_userId&seller_id=${widget.sellerId}')
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        setState(() {
          // CHANGE 5: Directly use 'messages' and 'order_id' keys from response
          messages = jsonResponse['messages'] ?? [];
          _orderId = jsonResponse['order_id'] ?? 0;
          isLoading = false;
        });
      } else {
        setState(() {
          error = 'Failed to load messages';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Network error: $e';
        isLoading = false;
      });
    }
  }

  Future<void> sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/messages/send'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': _userId,
          'seller_id': widget.sellerId,
          'order_id': _orderId,
          'message': _messageController.text.trim(),
          'name': widget.userData['name'],
          'business_name': widget.businessName,
          'sender_type': 'buyer'
        }),
      );

      if (response.statusCode == 200) {
        // Add the new message to the list
        setState(() {
          messages.add({
            'message': _messageController.text.trim(),
            'sender_type': 'buyer',
            'created_at': DateTime.now().toIso8601String(),
          });
          _messageController.clear();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF63C5DA),
        title: Text(
          widget.businessName, 
          style: TextStyle(color: Colors.white)
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: isLoading 
              ? Center(child: CircularProgressIndicator())
              : error != null
                ? Center(child: Text(error!, style: TextStyle(color: Colors.red)))
                : ListView.builder(
                    reverse: true,
                    padding: EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[messages.length - 1 - index];
                      final isCurrentUser = message['sender_type'] == 'buyer';

                      return Container(
                        margin: EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: isCurrentUser 
                            ? MainAxisAlignment.end 
                            : MainAxisAlignment.start,
                          children: [
                            Container(
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.7,
                              ),
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isCurrentUser 
                                  ? Color(0xFF63C5DA) 
                                  : Colors.grey[300],
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(15),
                                  topRight: Radius.circular(15),
                                  bottomLeft: isCurrentUser 
                                    ? Radius.circular(15) 
                                    : Radius.circular(0),
                                  bottomRight: isCurrentUser 
                                    ? Radius.circular(0) 
                                    : Radius.circular(15),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    message['message'],
                                    style: TextStyle(
                                      color: isCurrentUser 
                                        ? Colors.white 
                                        : Colors.black,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    _formatTimestamp(message['created_at']),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isCurrentUser 
                                        ? Colors.white70 
                                        : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          // Message input area
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16, 
                        vertical: 12
                      ),
                    ),
                    maxLines: null,
                  ),
                ),
                SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Color(0xFF63C5DA),
                  child: IconButton(
                    icon: Icon(Icons.send, color: Colors.white),
                    onPressed: sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return '';
    
    final DateTime dateTime = DateTime.parse(timestamp);
    final DateTime now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inHours < 24) {
      // Show time for today's messages
      return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      // Show day for messages within a week
      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[dateTime.weekday - 1];
    } else {
      // Show date for older messages
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}