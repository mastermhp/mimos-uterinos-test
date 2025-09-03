import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:menstrual_health_ai/constants/app_colors.dart';
import 'package:menstrual_health_ai/constants/text_styles.dart';
import 'package:menstrual_health_ai/models/user_data.dart';
import 'package:menstrual_health_ai/providers/user_data_provider.dart';
import 'package:menstrual_health_ai/providers/auth_provider.dart';
import 'package:menstrual_health_ai/services/api_service.dart';
import 'package:menstrual_health_ai/widgets/animated_gradient_button.dart';
import 'package:provider/provider.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _birthdayController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _cycleLengthController = TextEditingController();
  final _periodLengthController = TextEditingController();
  
  DateTime? _birthDate;
  DateTime? _lastPeriodDate;
  bool _isLoading = false;
  List<String> _healthConditions = [];
  List<String> _goals = [];
  bool _notificationsEnabled = true;
  bool _dataSharing = false;
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }
  
  Future<void> _loadUserData() async {
    try {
      // Load from AuthProvider first
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;
      
      if (currentUser != null) {
        setState(() {
          _nameController.text = currentUser.name;
          _emailController.text = currentUser.email;
        });
      }

      // Try to load additional profile data from API
      final profileData = await ApiService.getUserProfile();
      if (profileData != null && profileData['success'] == true) {
        final data = profileData['data'];
        final profile = data['profile'];
        
        setState(() {
          if (profile != null) {
            _heightController.text = profile['height']?.toString() ?? '';
            _weightController.text = profile['weight']?.toString() ?? '';
            _cycleLengthController.text = profile['cycleLength']?.toString() ?? '28';
            _periodLengthController.text = profile['periodLength']?.toString() ?? '5';
            _goals = List<String>.from(profile['goals'] ?? []);
            _healthConditions = List<String>.from(profile['healthConditions'] ?? []);
            
            if (profile['birthDate'] != null) {
              _birthDate = DateTime.parse(profile['birthDate']);
              _birthdayController.text = DateFormat('yyyy-MM-dd').format(_birthDate!);
            }
            
            if (profile['lastPeriodDate'] != null) {
              _lastPeriodDate = DateTime.parse(profile['lastPeriodDate']);
            }
          }
          
          final preferences = data['preferences'];
          if (preferences != null) {
            _notificationsEnabled = preferences['notifications'] ?? true;
            _dataSharing = preferences['dataSharing'] ?? false;
          }
        });
      }
    } catch (e) {
      print('Error loading profile data: $e');
      // Continue with default/empty values
    }
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _birthdayController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _cycleLengthController.dispose();
    _periodLengthController.dispose();
    super.dispose();
  }

  Future<void> _saveUserData() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      
      try {
        // Prepare profile data for API
        final profileData = <String, dynamic>{
          'name': _nameController.text.trim(),
          'profile': <String, dynamic>{
            'weight': double.tryParse(_weightController.text) ?? 0.0,
            'height': double.tryParse(_heightController.text) ?? 0.0,
            'cycleLength': int.tryParse(_cycleLengthController.text) ?? 28,
            'periodLength': int.tryParse(_periodLengthController.text) ?? 5,
            'goals': _goals,
            'healthConditions': _healthConditions,
          },
          'preferences': <String, dynamic>{
            'notifications': _notificationsEnabled,
            'dataSharing': _dataSharing,
          },
        };

        // Add optional fields if they exist - FIX 2 & 3: Safe null access
        if (_birthDate != null) {
          (profileData['profile'] as Map<String, dynamic>)['birthDate'] = _birthDate!.toIso8601String();
        }
        if (_lastPeriodDate != null) {
          (profileData['profile'] as Map<String, dynamic>)['lastPeriodDate'] = _lastPeriodDate!.toIso8601String();
        }

        print('🔄 Updating profile with data: $profileData');

        // Call the API
        final response = await ApiService.updateUserProfile(
          profileData: profileData,
        );

        if (response != null && response['success'] == true) {
          print('✅ Profile updated successfully');
          print('📄 Response: ${response['message']}');
          
          // FIX 1: Update local provider properly (assuming AuthProvider has updateUser method)
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          // Instead of updateUserName, use a method that exists in AuthProvider
          // Option 1: If there's an updateUser method
          // await authProvider.updateUser(name: _nameController.text.trim());
          
          // Option 2: If you need to create the method in AuthProvider, here's what to add:
          // For now, we'll skip this update or handle it differently
          print('Updated user name: ${_nameController.text.trim()}');
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(response['message'] ?? 'Profile updated successfully!'),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
            Navigator.pop(context);
          }
        } else {
          throw Exception('Failed to update profile');
        }
      } catch (e) {
        print('❌ Profile update error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text("Error updating profile: ${e.toString()}"),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _handleSavePressed() {
    _saveUserData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Profile"),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfilePicture(),
                  const SizedBox(height: 32),
                  _buildProfileForm(),
                  const SizedBox(height: 24),
                  _buildGoalsSection(),
                  const SizedBox(height: 24),
                  _buildPreferencesSection(),
                  const SizedBox(height: 32),
                  _buildSaveButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfilePicture() {
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(0.1),
                  border: Border.all(
                    color: AppColors.primary,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    (_nameController.text.isNotEmpty ? _nameController.text : 'U')
                        .substring(0, 1)
                        .toUpperCase(),
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.camera_alt,
                      size: 20,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      // Show image picker
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Profile picture upload coming soon!"),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            "Change Profile Picture",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.primary,
            ),
          ),
        ],
      ).animate().fadeIn(duration: 600.ms),
    );
  }

  Widget _buildGoalsSection() {
    const availableGoals = [
      'track_cycle',
      'manage_symptoms',
      'fertility_tracking',
      'health_monitoring',
      'mood_tracking'
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Health Goals",
          style: TextStyles.heading3,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: availableGoals.map((goal) {
            final isSelected = _goals.contains(goal);
            return FilterChip(
              label: Text(
                goal.replaceAll('_', ' ').toUpperCase(),
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _goals.add(goal);
                  } else {
                    _goals.remove(goal);
                  }
                });
              },
              backgroundColor: Colors.white,
              selectedColor: AppColors.primary,
              checkmarkColor: Colors.white,
              side: BorderSide(color: AppColors.primary),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPreferencesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Preferences",
          style: TextStyles.heading3,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Notifications'),
                subtitle: const Text('Receive reminders and updates'),
                value: _notificationsEnabled,
                onChanged: (value) {
                  setState(() {
                    _notificationsEnabled = value;
                  });
                },
                activeColor: AppColors.primary,
              ),
              const Divider(),
              SwitchListTile(
                title: const Text('Data Sharing'),
                subtitle: const Text('Share anonymous data for research'),
                value: _dataSharing,
                onChanged: (value) {
                  setState(() {
                    _dataSharing = value;
                  });
                },
                activeColor: AppColors.primary,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ... rest of the existing methods remain the same ...
  Widget _buildProfileForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Personal Information",
          style: TextStyles.heading3,
        ),
        const SizedBox(height: 24),
        _buildTextField(
          label: "Full Name",
          controller: _nameController,
          icon: Icons.person_outline,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return "Please enter your name";
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildTextField(
          label: "Email",
          controller: _emailController,
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          readOnly: true, // Email should not be editable
          validator: (value) {
            if (value == null || value.isEmpty) {
              return "Please enter your email";
            }
            if (!value.contains('@')) {
              return "Please enter a valid email";
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildTextField(
          label: "Phone Number",
          controller: _phoneController,
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          label: "Birthday",
          controller: _birthdayController,
          icon: Icons.cake_outlined,
          readOnly: true,
          onTap: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: _birthDate ?? DateTime(1990, 5, 15),
              firstDate: DateTime(1950),
              lastDate: DateTime.now(),
            );
            if (picked != null) {
              setState(() {
                _birthDate = picked;
                _birthdayController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
              });
            }
          },
        ),
        const SizedBox(height: 24),
        Text(
          "Health Information",
          style: TextStyles.heading3,
        ),
        const SizedBox(height: 24),
        _buildTextField(
          label: "Height (cm)",
          controller: _heightController,
          icon: Icons.height,
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return "Please enter your height";
            }
            if (double.tryParse(value) == null) {
              return "Please enter a valid number";
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildTextField(
          label: "Weight (kg)",
          controller: _weightController,
          icon: Icons.monitor_weight_outlined,
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return "Please enter your weight";
            }
            if (double.tryParse(value) == null) {
              return "Please enter a valid number";
            }
            return null;
          },
        ),
        const SizedBox(height: 24),
        Text(
          "Cycle Information",
          style: TextStyles.heading3,
        ),
        const SizedBox(height: 24),
        _buildTextField(
          label: "Average Cycle Length (days)",
          controller: _cycleLengthController,
          icon: Icons.calendar_month_outlined,
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return "Please enter your cycle length";
            }
            if (int.tryParse(value) == null) {
              return "Please enter a valid number";
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildTextField(
          label: "Average Period Length (days)",
          controller: _periodLengthController,
          icon: Icons.water_drop_outlined,
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return "Please enter your period length";
            }
            if (int.tryParse(value) == null) {
              return "Please enter a valid number";
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _buildTextField(
          label: "Last Period Date",
          controller: TextEditingController(
            text: _lastPeriodDate != null 
                ? DateFormat('yyyy-MM-dd').format(_lastPeriodDate!) 
                : 'Not set'
          ),
          icon: Icons.event_outlined,
          readOnly: true,
          onTap: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: _lastPeriodDate ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
            );
            if (picked != null) {
              setState(() {
                _lastPeriodDate = picked;
              });
            }
          },
        ),
      ],
    ).animate().fadeIn(duration: 800.ms, delay: 200.ms);
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    VoidCallback? onTap,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        readOnly: readOnly,
        onTap: onTap,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(
            icon,
            color: AppColors.primary,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return AnimatedGradientButton(
      onPressed: _isLoading ? null : _handleSavePressed,
      text: _isLoading ? "Saving..." : "Save Changes",
      isLoading: _isLoading,
      icon: Icons.check,
    ).animate().fadeIn(duration: 800.ms, delay: 400.ms);
  }
}
