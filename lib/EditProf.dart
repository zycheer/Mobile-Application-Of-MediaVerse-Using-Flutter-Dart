import 'package:flutter/material.dart';
import 'dart:io';


class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final Function(Map<String, dynamic>) onProfileUpdated;

  const EditProfileScreen({
    Key? key,
    required this.userData,
    required this.onProfileUpdated,
  }) : super(key: key);

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController nameController;
  late TextEditingController emailController;
  late TextEditingController businessNameController;
  late TextEditingController phoneController;
  late TextEditingController addressController;
  String? profilePicturePath;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.userData['name'] ?? '');
    emailController = TextEditingController(text: widget.userData['email'] ?? '');
    businessNameController = TextEditingController(text: widget.userData['businessName'] ?? '');
    phoneController = TextEditingController(text: widget.userData['phoneNumber'] ?? '');
    addressController = TextEditingController(text: widget.userData['address'] ?? '');
    profilePicturePath = widget.userData['profilePicturePath'];
  }
  
  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    businessNameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    super.dispose();
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

  Future<void> _updateProfile() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Here you would typically make an API call to update the profile
      // For now, we'll just simulate a delay
      await Future.delayed(Duration(seconds: 1));
      
      // Return the updated data to the parent
      widget.onProfileUpdated({
        'name': nameController.text,
        'email': emailController.text,
        'businessName': businessNameController.text,
        'phoneNumber': phoneController.text,
        'address': addressController.text,
        'profilePicturePath': profilePicturePath,
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Go back to profile screen
      Navigator.pop(context);
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update profile: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    // This would typically use image_picker package
    // For now, we'll just show a dialog simulating the process
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Change Profile Picture'),
          content: Text('This would open the image picker. Feature to be implemented.'),
          actions: <Widget>[
            TextButton(
              child: Text('Close'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Color(0xFF63C5DA),
        elevation: 0,
        title: Text('Edit Profile', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (isLoading)
            Container(
              padding: EdgeInsets.all(10),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 2,
              ),
            )
          else
            IconButton(
              icon: Icon(Icons.check, color: Colors.white),
              onPressed: _updateProfile,
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile picture section
            Container(
              color: Color(0xFF63C5DA),
              padding: EdgeInsets.only(bottom: 30),
              child: Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundImage: _getImageProvider(),
                      backgroundColor: Colors.white,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 5,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(Icons.camera_alt, color: Color(0xFF63C5DA), size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Form fields
            Container(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 10),
                  
                  // Personal Information Section
                  _sectionTitle('Personal Information'),
                  SizedBox(height: 20),
                  
                  _buildTextField(
                    controller: nameController, 
                    label: 'Full Name', 
                    icon: Icons.person
                  ),
                  
                  _buildTextField(
                    controller: emailController, 
                    label: 'Email', 
                    icon: Icons.email,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  
                  _buildTextField(
                    controller: businessNameController, 
                    label: 'Business Name', 
                    icon: Icons.business
                  ),
                  
                  _buildTextField(
                    controller: phoneController, 
                    label: 'Phone Number', 
                    icon: Icons.phone,
                    keyboardType: TextInputType.phone,
                  ),
                  
                  _buildTextField(
                    controller: addressController, 
                    label: 'Address', 
                    icon: Icons.location_on
                  ),
                  
                  SizedBox(height: 30),
                  
                  // Save Button
                  Container(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF63C5DA),
                        padding: EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: isLoading ? null : _updateProfile,
                      child: Text(
                        'Save Changes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 20),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[600]),
          prefixIcon: Container(
            padding: EdgeInsets.all(12),
            child: Icon(icon, color: Color(0xFF63C5DA)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Color(0xFF63C5DA)),
          ),
          filled: true,
          fillColor: Colors.grey[50],
          contentPadding: EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }
}