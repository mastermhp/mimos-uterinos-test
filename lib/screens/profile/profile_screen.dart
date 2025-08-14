import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:menstrual_health_ai/constants/app_colors.dart';
import 'package:menstrual_health_ai/constants/text_styles.dart';
import 'package:menstrual_health_ai/models/user_data.dart';
import 'package:menstrual_health_ai/providers/theme_provider.dart';
import 'package:menstrual_health_ai/providers/user_data_provider.dart';
import 'package:menstrual_health_ai/providers/auth_provider.dart';
import 'package:menstrual_health_ai/screens/doctor/doctor_mode_screen.dart';
import 'package:menstrual_health_ai/screens/export/export_data_screen.dart';
import 'package:menstrual_health_ai/screens/help/help_support_screen.dart';
import 'package:menstrual_health_ai/screens/legal/privacy_policy_screen.dart';
import 'package:menstrual_health_ai/screens/legal/terms_of_service_screen.dart';
import 'package:menstrual_health_ai/screens/premium/premium_screen.dart';
import 'package:menstrual_health_ai/screens/profile/edit_profile_screen.dart';
import 'package:menstrual_health_ai/screens/reminders/reminders_screen.dart';
import 'package:menstrual_health_ai/screens/settings/settings_screen.dart';
import 'package:menstrual_health_ai/screens/auth/login_screen.dart';
import 'package:menstrual_health_ai/widgets/animated_gradient_button.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _profileData;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      // Get the auth provider to access current user info
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // You can access basic user info from auth provider
      final currentUser = authProvider.currentUser;
      
      if (currentUser != null) {
        // For now, we'll use the current user data
        // Later, you can implement API call to get full profile
        setState(() {
          _profileData = {
            'name': currentUser.name,
            'email': currentUser.email,
            'hasCompletedOnboarding': true,
            'profile': {
              'age': 28, // Default values, replace with API data
              'cycleLength': 28,
              'periodLength': 5,
            },
          };
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading profile: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
    final backgroundColor = isDarkMode ? const Color(0xFF1A1A1A) : Colors.white;
    final cardColor = isDarkMode ? const Color(0xFF2A2A2A) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final secondaryTextColor = isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;
    
    if (_isLoading) {
      return Scaffold(
        backgroundColor: backgroundColor,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Header
              _buildProfileHeader(context, authProvider, isDarkMode, textColor, secondaryTextColor),
              
              // Stats Section
              _buildStatsSection(context, isDarkMode, textColor, secondaryTextColor, cardColor),
              
              // Options Section
              _buildOptionsSection(context, isDarkMode, textColor, secondaryTextColor, cardColor),
              
              // Account Section
              _buildAccountSection(context, authProvider, isDarkMode, textColor, secondaryTextColor, cardColor),
              
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildProfileHeader(BuildContext context, AuthProvider authProvider, bool isDarkMode, Color textColor, Color secondaryTextColor) {
    final currentUser = authProvider.currentUser;
    
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 80,
                height: 80,
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
                    (currentUser?.name ?? 'U').substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentUser?.name ?? "Guest User",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentUser?.email ?? "No email provided",
                    style: TextStyle(
                      fontSize: 14,
                      color: secondaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "Free Plan",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
          
            ],
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
            icon: Icon(
              Icons.settings_outlined,
              color: textColor,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: -10, end: 0);
  }
  
  Widget _buildStatsSection(BuildContext context, bool isDarkMode, Color textColor, Color secondaryTextColor, Color cardColor) {
    // Use profile data if available, otherwise show defaults
    final profile = _profileData?['profile'];
    final cycleLength = profile?['cycleLength'] ?? 28;
    final periodLength = profile?['periodLength'] ?? 5;
    final cyclesTracked = 0; // You can track this in your app
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "My Stats",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  "Cycles Tracked", 
                  cyclesTracked.toString(), 
                  Icons.loop_rounded,
                  textColor,
                  secondaryTextColor,
                ),
                _buildStatItem(
                  "Avg. Cycle Length", 
                  "$cycleLength days", 
                  Icons.calendar_today_rounded,
                  textColor,
                  secondaryTextColor,
                ),
                _buildStatItem(
                  "Avg. Period Length", 
                  "$periodLength days", 
                  Icons.water_drop_rounded,
                  textColor,
                  secondaryTextColor,
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 800.ms, delay: 200.ms);
  }
  
  Widget _buildStatItem(
    String title, 
    String value, 
    IconData icon,
    Color textColor,
    Color secondaryTextColor,
  ) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: AppColors.primary,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: secondaryTextColor,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
  
  Widget _buildOptionsSection(BuildContext context, bool isDarkMode, Color textColor, Color secondaryTextColor, Color cardColor) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Options",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 16),
          _buildOptionItem(
            context,
            "Settings",
            "Customize app preferences",
            Icons.settings_outlined,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
            isDarkMode,
            textColor,
            secondaryTextColor,
            cardColor,
          ),
          _buildOptionItem(
            context,
            "Doctor Mode",
            "View medical reports",
            Icons.medical_services_outlined,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DoctorModeScreen(),
                ),
              );
            },
            isDarkMode,
            textColor,
            secondaryTextColor,
            cardColor,
          ),
          _buildOptionItem(
            context,
            "Reminders",
            "Set up notifications",
            Icons.notifications_outlined,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RemindersScreen(),
                ),
              );
            },
            isDarkMode,
            textColor,
            secondaryTextColor,
            cardColor,
          ),
          _buildOptionItem(
            context,
            "Export Data",
            "Download your data",
            Icons.download_outlined,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ExportDataScreen(),
                ),
              );
            },
            isDarkMode,
            textColor,
            secondaryTextColor,
            cardColor,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 800.ms, delay: 400.ms);
  }
  
  Widget _buildOptionItem(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
    bool isDarkMode,
    Color textColor,
    Color secondaryTextColor,
    Color cardColor,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: secondaryTextColor,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAccountSection(BuildContext context, AuthProvider authProvider, bool isDarkMode, Color textColor, Color secondaryTextColor, Color cardColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Account",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 16),
          AnimatedGradientButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PremiumScreen(),
                ),
              );
            },
            text: "Upgrade to Premium",
            gradientColors: const [
              Color(0xFFFFD700),
              Color(0xFFFFA500),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
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
                _buildAccountItem(
                  "Edit Profile",
                  Icons.edit_outlined,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EditProfileScreen(),
                      ),
                    );
                  },
                  textColor,
                  isDarkMode,
                ),
                Divider(color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade300),
                _buildAccountItem(
                  "Privacy Policy",
                  Icons.privacy_tip_outlined,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PrivacyPolicyScreen(),
                      ),
                    );
                  },
                  textColor,
                  isDarkMode,
                ),
                Divider(color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade300),
                _buildAccountItem(
                  "Terms of Service",
                  Icons.description_outlined,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TermsOfServiceScreen(),
                      ),
                    );
                  },
                  textColor,
                  isDarkMode,
                ),
                Divider(color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade300),
                _buildAccountItem(
                  "Help & Support",
                  Icons.help_outline_rounded,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HelpSupportScreen(),
                      ),
                    );
                  },
                  textColor,
                  isDarkMode,
                ),
                Divider(color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade300),
                _buildAccountItem(
                  "Log Out",
                  Icons.logout_rounded,
                  () {
                    _showLogoutDialog(context, authProvider, isDarkMode);
                  },
                  textColor,
                  isDarkMode,
                  isLogout: true,
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 800.ms, delay: 600.ms);
  }
  
  Widget _buildAccountItem(
    String title,
    IconData icon,
    VoidCallback onTap,
    Color textColor,
    bool isDarkMode, {
    bool isLogout = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              color: isLogout ? Colors.red : AppColors.primary,
              size: 20,
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isLogout ? Colors.red : textColor,
              ),
            ),
            const Spacer(),
            if (!isLogout)
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }
  
  void _showLogoutDialog(BuildContext context, AuthProvider authProvider, bool isDarkMode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.logout_rounded,
              color: Colors.red,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              "Log Out",
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black87,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          "Are you sure you want to log out? You'll need to sign in again to access your account.",
          style: TextStyle(
            color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: isDarkMode ? Colors.white : Colors.black87,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              "Cancel",
              style: TextStyle(fontSize: 16),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              // Store the navigator state before any async operations
              final navigator = Navigator.of(context);
              
              navigator.pop(); // Close dialog first
              
              try {
                // Show loading indicator
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => WillPopScope(
                    onWillPop: () async => false,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                      ),
                    ),
                  ),
                );
                
                // Perform logout
                await authProvider.logout();
                
                // Clear all saved data
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear(); // Clear all preferences
                
                // Print logout success to terminal
                print('👋 Logout successful!');
                print('🔐 Auth token cleared');
                print('📱 User session ended');
                print('✅ Redirecting to login screen...');
                
                // Small delay to ensure logout is complete
                await Future.delayed(const Duration(milliseconds: 500));
                
                // Navigate to login screen using the stored navigator
                navigator.pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const LoginScreen(),
                  ),
                  (route) => false, // Remove all previous routes
                );
                
              } catch (e) {
                print('❌ Logout error: $e');
                
                // Pop loading dialog
                navigator.pop();
                
                // Show error snackbar
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Logout failed: $e'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              "Log Out",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
