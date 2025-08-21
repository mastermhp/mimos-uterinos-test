import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:menstrual_health_ai/models/user_data.dart';
import 'package:menstrual_health_ai/services/api_service.dart';
import 'package:menstrual_health_ai/services/auth_service.dart';
import 'package:menstrual_health_ai/models/user_auth.dart';
import 'package:menstrual_health_ai/utils/secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final SecureStorage _secureStorage = SecureStorage();

  // Remove duplicate properties and use only these
  User? _currentUser;
  String? _token;
  String? _error;
  bool _isLoading = false;

  // Getters - keep only these, remove the duplicates
  User? get currentUser => _currentUser;
  String? get token => _token;
  String? get error => _error;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null && _currentUser != null;

  // Load user data from secure storage on app startup
  Future<void> loadUserFromStorage() async {
    try {
      final token = await _secureStorage.read('auth_token');
      final userJson = await _secureStorage.read('user_data');

      if (token != null && userJson != null) {
        _token = token;
        final userData = json.decode(userJson);
        _currentUser = User.fromJson(userData);
        notifyListeners();

        if (kDebugMode) {
          print('✅ User data loaded from secure storage');
          print('👤 User: ${_currentUser?.name}');
          print('📧 Email: ${_currentUser?.email}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Failed to load user from storage: $e');
      }
    }
  }

  // Register a new user
  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.register(
        name: name,
        email: email,
        password: password,
      );

      // If registration is successful, save the user data
      if (result && _authService.currentUser != null) {
        // Convert UserAuth to User and save to storage
        _currentUser = User(
          id: _authService.currentUser!.id,
          name: _authService.currentUser!.name,
          email: _authService.currentUser!.email,
          profileCompleted: false,
          isPremium: false,
        );

        // You would get the token from the auth service response
        _token = 'registered_token_${DateTime.now().millisecondsSinceEpoch}';

        await _saveUserDataToStorage();

        if (kDebugMode) {
          print('🔑 User registered and authenticated automatically');
        }
      }

      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Login method - UPDATED
  Future<bool> login({required String email, required String password}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Use actual auth service
      final result = await _authService.login(email: email, password: password);

      if (result && _authService.currentUser != null) {
        // Convert UserAuth to User
        _currentUser = User(
          id: _authService.currentUser!.id,
          name: _authService.currentUser!.name,
          email: _authService.currentUser!.email,
          profileCompleted: true,
          isPremium: false,
        );

        // Get the actual token from SharedPreferences (saved by ApiService)
        final prefs = await SharedPreferences.getInstance();
        _token = prefs.getString('auth_token');

        if (_token != null) {
          await _saveUserDataToStorage();
          _isLoading = false;
          notifyListeners();
          return true;
        }
      }

      _error = _authService.error ?? 'Login failed';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Save user data to secure storage
  Future<void> _saveUserDataToStorage() async {
    try {
      if (_token != null) {
        await _secureStorage.write('auth_token', _token!);
      }

      if (_currentUser != null) {
        final userJson = json.encode(_currentUser!.toJson());
        await _secureStorage.write('user_data', userJson);

        // Also save login status
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_logged_in', true);
        await prefs.setString('user_email', _currentUser!.email);

        if (kDebugMode) {
          print('💾 User data saved to secure storage');
          print('📧 Email: ${_currentUser!.email}');
          print('👤 Name: ${_currentUser!.name}');
          print('🔒 Token saved: ${_token != null}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Failed to save user data: $e');
      }
    }
  }

  // Logout method
  Future<void> logout() async {
    try {
      // Call auth service logout if available
      await _authService.logout();

      // Clear secure storage
      await _secureStorage.deleteAll();

      // Clear shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', false);
      await prefs.remove('user_email');

      _currentUser = null;
      _token = null;
      _error = null;

      notifyListeners();

      if (kDebugMode) {
        print('👋 User logged out and data cleared');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error during logout: $e');
      }
    }
  }

  // Check authentication status - UPDATED
  Future<bool> checkAuth() async {
    try {
      // First, try to load from secure storage
      await loadUserFromStorage();

      // If we have user data and token locally, verify with server
      if (_currentUser != null && _token != null) {
        if (kDebugMode) {
          print('✅ Found local auth data, verifying with server...');
        }

        // Verify token is still valid by making an API call
        try {
          final response = await ApiService.getUserProfile();
          if (response != null && response['success'] == true) {
            if (kDebugMode) {
              print('✅ Token is valid, user authenticated');
            }
            notifyListeners();
            return true;
          }
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Token validation failed: $e');
          }
        }
      }

      // If no local data or validation failed, check with auth service
      final result = await _authService.checkAuth();
      if (result && _authService.currentUser != null) {
        _currentUser = User(
          id: _authService.currentUser!.id,
          name: _authService.currentUser!.name,
          email: _authService.currentUser!.email,
          profileCompleted: true,
          isPremium: false,
        );

        // Get token from prefs
        final prefs = await SharedPreferences.getInstance();
        _token = prefs.getString('auth_token');

        if (_token != null) {
          await _saveUserDataToStorage();
        }
      }

      notifyListeners();
      return result;
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error checking auth: $e');
      }
      // Clear invalid data
      _currentUser = null;
      _token = null;
      notifyListeners();
      return false;
    }
  }

  // Complete onboarding
  Future<bool> completeOnboarding({
    required String name,
    required DateTime birthDate,
    required int age,
    required double weight,
    required double height,
    required int periodLength,
    required bool isRegularCycle,
    required int cycleLength,
    required DateTime lastPeriodDate,
    required DateTime initialPeriodDate,
    required List<String> goals,
    required String email,
    required List<Map<String, dynamic>> healthConditions,
    required List<Map<String, dynamic>> symptoms,
    required List<Map<String, dynamic>> moods,
    required int painLevel,
    required int energyLevel,
    required int sleepQuality,
    required String notes,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Convert date to required format for API
      final formattedLastPeriod = lastPeriodDate.toIso8601String();
      final formattedInitialPeriod = initialPeriodDate.toIso8601String();
      final formattedBirthDate = birthDate.toIso8601String();

      // Create request body
      final Map<String, dynamic> userData = {
        'name': name,
        'birth_date': formattedBirthDate,
        'age': age,
        'weight': weight,
        'height': height,
        'period_length': periodLength,
        'is_regular_cycle': isRegularCycle,
        'cycle_length': cycleLength,
        'last_period_date': formattedLastPeriod,
        'initial_period_date': formattedInitialPeriod,
        'goals': goals,
        'email': email,
        'health_conditions': healthConditions,
        'symptoms': symptoms,
        'moods': moods,
        'pain_level': painLevel,
        'energy_level': energyLevel,
        'sleep_quality': sleepQuality,
        'notes': notes,
      };

      // Make API call
      // ... rest of implementation

      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Verify email
  Future<bool> verifyEmail(String email, String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.verifyEmail(email, token);
      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Resend verification code
  Future<bool> resendVerificationCode(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.resendVerificationCode(email);
      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Request password reset
  Future<bool> requestPasswordReset(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.requestPasswordReset(email);
      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Reset password
  Future<bool> resetPassword(
      String email, String token, String newPassword) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result =
          await _authService.resetPassword(email, token, newPassword);
      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Change password
  Future<bool> changePassword(
      String currentPassword, String newPassword) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result =
          await _authService.changePassword(currentPassword, newPassword);
      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Update user profile
  Future<bool> updateProfile({
    required String name,
    String? email,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.updateProfile(
        name: name,
        email: email,
      );

      if (result && _currentUser != null) {
        // Update local user data
        _currentUser = User(
          id: _currentUser!.id,
          name: name,
          email: email ?? _currentUser!.email,
          phone: _currentUser!.phone,
          dateOfBirth: _currentUser!.dateOfBirth,
          profileCompleted: _currentUser!.profileCompleted,
          isPremium: _currentUser!.isPremium,
          cycleData: _currentUser!.cycleData,
          preferences: _currentUser!.preferences,
          healthData: _currentUser!.healthData,
        );

        await _saveUserDataToStorage();
      }

      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Delete account
  Future<bool> deleteAccount(String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _authService.deleteAccount(password);

      if (result) {
        // Clear all data after successful account deletion
        await logout();
      }

      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}

// User model class - keep this as is
class User {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? dateOfBirth;
  final bool profileCompleted;
  final bool isPremium;
  final Map<String, dynamic>? cycleData;
  final Map<String, dynamic>? preferences;
  final Map<String, dynamic>? healthData;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.dateOfBirth,
    required this.profileCompleted,
    required this.isPremium,
    this.cycleData,
    this.preferences,
    this.healthData,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      dateOfBirth: json['dateOfBirth'],
      profileCompleted: json['profileCompleted'] ?? false,
      isPremium: json['isPremium'] ?? false,
      cycleData: json['cycleData'],
      preferences: json['preferences'],
      healthData: json['healthData'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'dateOfBirth': dateOfBirth,
      'profileCompleted': profileCompleted,
      'isPremium': isPremium,
      'cycleData': cycleData,
      'preferences': preferences,
      'healthData': healthData,
    };
  }
}
