import 'package:flutter/foundation.dart';
import 'package:menstrual_health_ai/models/user_auth.dart';
import 'package:menstrual_health_ai/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  UserAuth? _currentUser;
  bool _isLoading = false;
  String? _error;

  UserAuth? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;

  // Register a new user
  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      _isLoading = true;
      _error = null;

      print('🔄 AuthService: Starting registration...');

      final response = await ApiService.register(
        name: name,
        email: email,
        password: password,
      );

      if (response != null && response['success'] == true) {
        print('✅ AuthService: Registration successful');

        // Extract data from response structure: {"success": true, "data": {"token": "...", "user": {...}}}
        final responseData = response['data'];
        final userData = responseData['user'];

        // Create user object
        if (userData != null) {
          _currentUser = UserAuth.fromApiResponse(userData);
          print('✅ AuthService: User object created - ${_currentUser?.name}');

          // Save user data locally
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('current_user_id', _currentUser!.id);
          await prefs.setBool('is_authenticated', true);
        }

        return true;
      }

      print(
          '❌ AuthService: Registration failed - ${response?['message'] ?? 'Unknown error'}');
      _error = response?['message'] ?? 'Registration failed';
      return false;
    } on ApiException catch (e) {
      print('❌ AuthService: API error - ${e.message}');
      _error = e.message;
      return false;
    } catch (e) {
      print('❌ AuthService: Unexpected error - $e');
      _error = 'Registration failed: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
    }
  }

  // Login user - UPDATED
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    try {
      _isLoading = true;
      _error = null;

      print('🔄 AuthService: Starting login...');

      final response = await ApiService.login(
        email: email,
        password: password,
      );

      if (response != null && response['success'] == true) {
        print('✅ AuthService: Login successful');

        // Extract data from response structure
        final responseData = response['data'];
        final userData = responseData['user'];
        final token = responseData['token'];

        if (userData != null) {
          _currentUser = UserAuth.fromApiResponse(userData);
          print('✅ AuthService: User object created - ${_currentUser?.name}');

          // Save user data and authentication status locally
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('current_user_id', _currentUser!.id);
          await prefs.setBool('is_authenticated', true);

          // Token should already be saved by ApiService, but let's ensure it
          if (token != null) {
            await prefs.setString('auth_token', token);
            print('✅ AuthService: Token saved locally');
          }

          return true;
        }
      }

      print(
          '❌ AuthService: Login failed - ${response?['message'] ?? 'Unknown error'}');
      _error = response?['message'] ?? 'Login failed';
      return false;
    } on ApiException catch (e) {
      print('❌ AuthService: API error - ${e.message}');
      _error = e.message;
      return false;
    } catch (e) {
      print('❌ AuthService: Unexpected error - $e');
      _error = 'Login failed: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
    }
  }

  // Logout user
  Future<void> logout() async {
    _currentUser = null;
    await ApiService.clearAuth();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user_id');
    await prefs.setBool('is_authenticated', false);
  }

  // Check if user is authenticated - UPDATED
  Future<bool> checkAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isAuthenticated = prefs.getBool('is_authenticated') ?? false;
      final token = prefs.getString('auth_token');
      final userId = prefs.getString('current_user_id');

      if (kDebugMode) {
        print('🔍 AuthService.checkAuth:');
        print('  - isAuthenticated: $isAuthenticated');
        print('  - hasToken: ${token != null}');
        print('  - hasUserId: ${userId != null}');
      }

      if (!isAuthenticated || token == null || userId == null) {
        if (kDebugMode) {
          print('❌ AuthService: Missing authentication data');
        }
        return false;
      }

      // Try to get user profile from server to validate token
      try {
        final profileData = await ApiService.getUserProfile();
        if (profileData != null &&
            profileData['success'] == true &&
            profileData['data'] != null) {
          _currentUser = UserAuth.fromApiResponse(profileData['data']);
          if (kDebugMode) {
            print(
                '✅ AuthService: User profile validated - ${_currentUser?.name}');
          }
          return true;
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ AuthService: Profile validation failed: $e');
        }
        // Token might be invalid, clear auth data
        await prefs.setBool('is_authenticated', false);
        await prefs.remove('auth_token');
        await prefs.remove('current_user_id');
        return false;
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print('❌ AuthService.checkAuth error: $e');
      }
      return false;
    }
  }

  // Verify email
  Future<bool> verifyEmail(String email, String token) async {
    try {
      _isLoading = true;
      _error = null;

      final response = await ApiService.verifyEmail(
        email: email,
        token: token,
      );

      return response != null;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = 'Email verification failed: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
    }
  }

  // Resend verification code
  Future<bool> resendVerificationCode(String email) async {
    try {
      _isLoading = true;
      _error = null;

      final response = await ApiService.resendVerificationCode(email: email);
      return response != null;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = 'Failed to resend verification code: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
    }
  }

  // Request password reset
  Future<bool> requestPasswordReset(String email) async {
    try {
      _isLoading = true;
      _error = null;

      final response = await ApiService.requestPasswordReset(email: email);
      return response != null;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = 'Password reset request failed: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
    }
  }

  // Reset password
  Future<bool> resetPassword(
      String email, String token, String newPassword) async {
    try {
      _isLoading = true;
      _error = null;

      final response = await ApiService.resetPassword(
        email: email,
        token: token,
        newPassword: newPassword,
      );

      return response != null;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = 'Password reset failed: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
    }
  }

  // Change password
  Future<bool> changePassword(
      String currentPassword, String newPassword) async {
    try {
      _isLoading = true;
      _error = null;

      if (_currentUser == null) {
        _error = 'Not authenticated';
        return false;
      }

      final response = await ApiService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

      return response != null;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = 'Password change failed: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
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
    required List<String> goals,
    required String email,
    required List<String> healthConditions,
    required List<Map<String, dynamic>> symptoms,
    required List<Map<String, dynamic>> moods,
    String notes = '',
  }) async {
    try {
      _isLoading = true;
      _error = null;

      final response = await ApiService.completeOnboarding(
        name: name,
        birthDate: birthDate,
        age: age,
        weight: weight,
        height: height,
        periodLength: periodLength,
        isRegularCycle: isRegularCycle,
        cycleLength: cycleLength,
        lastPeriodDate: lastPeriodDate,
        goals: goals,
        email: email,
        healthConditions: healthConditions,
        symptoms: symptoms,
        moods: moods,
        notes: notes,
      );

      return response != null;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = 'Onboarding failed: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
    }
  }

  // Update user profile
  Future<bool> updateProfile({
    required String name,
    String? email,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      _isLoading = true;
      _error = null;

      if (_currentUser == null) {
        _error = 'Not authenticated';
        return false;
      }

      final profileData = <String, dynamic>{
        'name': name,
        'email': email ?? _currentUser!.email,
        ...?additionalData,
      };

      final response = await ApiService.updateUserProfile(
        profileData: profileData,
      );

      if (response != null && response['user'] != null) {
        _currentUser = UserAuth.fromApiResponse(response['user']);
        return true;
      }

      return false;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = 'Profile update failed: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
    }
  }

  // Delete account
  Future<bool> deleteAccount(String password) async {
    try {
      _isLoading = true;
      _error = null;

      if (_currentUser == null) {
        _error = 'Not authenticated';
        return false;
      }

      final response = await ApiService.deleteAccount(password: password);

      if (response != null) {
        // Clear local data after successful deletion
        await logout();
        return true;
      }

      return false;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = 'Account deletion failed: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
    }
  }
}
