import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl =
      'https://mimosuterinos-api-v1.vercel.app/api'; // Added /api prefix
  static const Duration timeout = Duration(seconds: 30);

  static Future<Map<String, String>> _getHeaders(
      {bool includeAuth = true}) async {
    final headers = {
      'Content-Type': 'application/json',
    };

    if (includeAuth) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  static Future<Map<String, dynamic>?> _handleResponse(
      http.Response response) async {
    print('📡 API Response Status: ${response.statusCode}');
    print('📡 API Response Body: ${response.body}');
    print('📡 API Response Headers: ${response.headers}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      // Check if response body is empty
      if (response.body.isEmpty) {
        print('⚠️ Empty response body, returning empty map');
        return {};
      }

      try {
        final decoded = json.decode(response.body);
        print('✅ Successfully decoded JSON: $decoded');
        return decoded;
      } catch (e) {
        print('❌ JSON decode error: $e');
        print('❌ Raw response body: "${response.body}"');
        throw ApiException(message: 'Invalid response format from server');
      }
    } else {
      print('❌ HTTP Error Status: ${response.statusCode}');

      if (response.body.isEmpty) {
        throw ApiException(
          message: 'Server error (${response.statusCode}): No response body',
          statusCode: response.statusCode,
        );
      }

      try {
        final errorData = json.decode(response.body);
        throw ApiException(
          message: errorData['message'] ?? 'Server error occurred',
          statusCode: response.statusCode,
        );
      } catch (e) {
        // If we can't parse the error response, throw a generic error
        throw ApiException(
          message: 'Server error (${response.statusCode}): ${response.body}',
          statusCode: response.statusCode,
        );
      }
    }
  }

  // User Registration
  static Future<Map<String, dynamic>?> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      print('🔄 Starting registration request...');
      print('📧 Email: $email');
      print('👤 Name: $name');

      final headers = await _getHeaders(includeAuth: false);
      final body = json.encode({
        'name': name,
        'email': email,
        'password': password,
      });

      print('📤 Request URL: $baseUrl/users/register');
      print('📤 Request Headers: $headers');
      print('📤 Request Body: $body');

      final response = await http
          .post(
            Uri.parse(
                '$baseUrl/users/register'), // Now becomes: /api/users/register
            headers: headers,
            body: body,
          )
          .timeout(timeout);

      final data = await _handleResponse(response);

      if (data != null && data['success'] == true) {
        print('✅ Registration successful!');
        print('📄 Full response: $data');

        // Extract token and user data from the response structure
        final responseData = data['data'];
        final token = responseData['token'];
        final user = responseData['user'];

        // Save token
        if (token != null) {
          print('💾 Saving auth token...');
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', token);
          await prefs.setBool('is_authenticated', true);
        }

        print('👤 User data: $user');
      }

      return data;
    } on SocketException catch (e) {
      print('❌ Network error: $e');
      throw ApiException(message: 'No internet connection');
    } on HttpException catch (e) {
      print('❌ HTTP error: $e');
      throw ApiException(message: 'Network error occurred');
    } catch (e) {
      print('❌ Registration error: $e');
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Registration failed: ${e.toString()}');
    }
  }

  // User Login
  static Future<Map<String, dynamic>?> login({
    required String email,
    required String password,
  }) async {
    try {
      print('🔄 Starting login request...');
      print('📧 Email: $email');

      final headers = await _getHeaders(includeAuth: false);
      final body = json.encode({
        'email': email,
        'password': password,
      });

      print('📤 Request URL: $baseUrl/users/login');

      final response = await http
          .post(
            Uri.parse('$baseUrl/users/login'), // Now becomes: /api/users/login
            headers: headers,
            body: body,
          )
          .timeout(timeout);

      final data = await _handleResponse(response);

      if (data != null && data['success'] == true) {
        print('✅ Login successful!');

        // Extract token and user data from the response structure
        final responseData = data['data'];
        final token = responseData['token'];

        // Save token
        if (token != null) {
          print('💾 Saving auth token...');
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', token);
          await prefs.setBool('is_authenticated', true);
        }
      }

      return data;
    } on SocketException {
      throw ApiException(message: 'No internet connection');
    } on HttpException {
      throw ApiException(message: 'Network error occurred');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Login failed: ${e.toString()}');
    }
  }

  // Complete Onboarding
  static Future<Map<String, dynamic>?> completeOnboarding({
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
    required String notes,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = json.encode({
        'name': name,
        'birthDate': birthDate.toIso8601String(),
        'age': age,
        'weight': weight,
        'height': height,
        'periodLength': periodLength,
        'isRegularCycle': isRegularCycle,
        'cycleLength': cycleLength,
        'lastPeriodDate': lastPeriodDate.toIso8601String(),
        'goals': goals,
        'email': email,
        'healthConditions': healthConditions,
        'symptoms': symptoms,
        'moods': moods,
        'notes': notes,
      });

      final response = await http
          .post(
            Uri.parse('$baseUrl/users/onboarding'), // /api/users/onboarding
            headers: headers,
            body: body,
          )
          .timeout(timeout);

      final data = await _handleResponse(response);

      // Mark onboarding as completed
      if (data != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('hasCompletedOnboarding', true);
      }

      return data;
    } on SocketException {
      throw ApiException(message: 'No internet connection');
    } on HttpException {
      throw ApiException(message: 'Network error occurred');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Onboarding failed: ${e.toString()}');
    }
  }

  // Get User Profile
  static Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final headers = await _getHeaders();

      final response = await http
          .get(
            Uri.parse('$baseUrl/users/profile'), // /api/users/profile
            headers: headers,
          )
          .timeout(timeout);

      return await _handleResponse(response);
    } on SocketException {
      throw ApiException(message: 'No internet connection');
    } on HttpException {
      throw ApiException(message: 'Network error occurred');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Failed to get profile: ${e.toString()}');
    }
  }

  // Update User Profile - ADDED THIS METHOD
  static Future<Map<String, dynamic>?> updateUserProfile({
    required Map<String, dynamic> profileData,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = json.encode(profileData);

      final response = await http
          .put(
            Uri.parse('$baseUrl/users/profile'),
            headers: headers,
            body: body,
          )
          .timeout(timeout);

      return await _handleResponse(response);
    } on SocketException {
      throw ApiException(message: 'No internet connection');
    } on HttpException {
      throw ApiException(message: 'Network error occurred');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Failed to update profile: ${e.toString()}');
    }
  }

  // Verify Email - ADDED THIS METHOD
  static Future<Map<String, dynamic>?> verifyEmail({
    required String email,
    required String token,
  }) async {
    try {
      final headers = await _getHeaders(includeAuth: false);
      final body = json.encode({
        'email': email,
        'token': token,
      });

      final response = await http
          .post(
            Uri.parse('$baseUrl/users/verify-email'),
            headers: headers,
            body: body,
          )
          .timeout(timeout);

      return await _handleResponse(response);
    } on SocketException {
      throw ApiException(message: 'No internet connection');
    } on HttpException {
      throw ApiException(message: 'Network error occurred');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Email verification failed: ${e.toString()}');
    }
  }

  // Resend Verification Code - ADDED THIS METHOD
  static Future<Map<String, dynamic>?> resendVerificationCode({
    required String email,
  }) async {
    try {
      final headers = await _getHeaders(includeAuth: false);
      final body = json.encode({'email': email});

      final response = await http
          .post(
            Uri.parse('$baseUrl/users/resend-verification'),
            headers: headers,
            body: body,
          )
          .timeout(timeout);

      return await _handleResponse(response);
    } on SocketException {
      throw ApiException(message: 'No internet connection');
    } on HttpException {
      throw ApiException(message: 'Network error occurred');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
          message: 'Failed to resend verification: ${e.toString()}');
    }
  }

  // Request Password Reset - ADDED THIS METHOD
  static Future<Map<String, dynamic>?> requestPasswordReset({
    required String email,
  }) async {
    try {
      final headers = await _getHeaders(includeAuth: false);
      final body = json.encode({'email': email});

      final response = await http
          .post(
            Uri.parse('$baseUrl/users/forgot-password'),
            headers: headers,
            body: body,
          )
          .timeout(timeout);

      return await _handleResponse(response);
    } on SocketException {
      throw ApiException(message: 'No internet connection');
    } on HttpException {
      throw ApiException(message: 'Network error occurred');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
          message: 'Password reset request failed: ${e.toString()}');
    }
  }

  // Reset Password - ADDED THIS METHOD
  static Future<Map<String, dynamic>?> resetPassword({
    required String email,
    required String token,
    required String newPassword,
  }) async {
    try {
      final headers = await _getHeaders(includeAuth: false);
      final body = json.encode({
        'email': email,
        'token': token,
        'newPassword': newPassword,
      });

      final response = await http
          .post(
            Uri.parse('$baseUrl/users/reset-password'),
            headers: headers,
            body: body,
          )
          .timeout(timeout);

      return await _handleResponse(response);
    } on SocketException {
      throw ApiException(message: 'No internet connection');
    } on HttpException {
      throw ApiException(message: 'Network error occurred');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Password reset failed: ${e.toString()}');
    }
  }

  // Change Password - ADDED THIS METHOD
  static Future<Map<String, dynamic>?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = json.encode({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      });

      final response = await http
          .put(
            Uri.parse('$baseUrl/users/change-password'),
            headers: headers,
            body: body,
          )
          .timeout(timeout);

      return await _handleResponse(response);
    } on SocketException {
      throw ApiException(message: 'No internet connection');
    } on HttpException {
      throw ApiException(message: 'Network error occurred');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Password change failed: ${e.toString()}');
    }
  }

  // Delete Account - ADDED THIS METHOD
  static Future<Map<String, dynamic>?> deleteAccount({
    required String password,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = json.encode({'password': password});

      final response = await http
          .delete(
            Uri.parse('$baseUrl/users/account'),
            headers: headers,
            body: body,
          )
          .timeout(timeout);

      return await _handleResponse(response);
    } on SocketException {
      throw ApiException(message: 'No internet connection');
    } on HttpException {
      throw ApiException(message: 'Network error occurred');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Account deletion failed: ${e.toString()}');
    }
  }

  // Get chat history for a user
  static Future<Map<String, dynamic>?> getChatHistory({
    required String userId,
  }) async {
    try {
      print('🔄 Getting chat history for user: $userId');

      final headers = await _getHeaders(includeAuth: true);
      final response = await http
          .get(
            Uri.parse(
                '$baseUrl/ai/chat?userId=$userId'), // Fixed: changed from /chat to /ai/chat
            headers: headers,
          )
          .timeout(timeout);

      print('📡 Chat History Response Status: ${response.statusCode}');
      print('📡 Chat History Response: ${response.body}');

      return await _handleResponse(response);
    } on SocketException {
      throw ApiException(message: 'No internet connection');
    } on HttpException {
      throw ApiException(message: 'Network error occurred');
    } catch (e) {
      print('❌ Get chat history error: $e');
      throw ApiException(
          message: 'Failed to load chat history: ${e.toString()}');
    }
  }

  // Send message to AI chat
  static Future<Map<String, dynamic>?> sendChatMessage({
    required String userId,
    required String message,
  }) async {
    try {
      print('🔄 Sending chat message for user: $userId');
      print('📤 Message: $message');

      final headers = await _getHeaders(includeAuth: true);
      final body = json.encode({
        'userId': userId,
        'message': message,
      });

      print('📤 Request Body: $body');

      final response = await http
          .post(
            Uri.parse(
                '$baseUrl/ai/chat'), // Fixed: changed from /chat to /ai/chat
            headers: headers,
            body: body,
          )
          .timeout(timeout);

      print('📡 Send Message Response Status: ${response.statusCode}');
      print('📡 Send Message Response: ${response.body}');

      return await _handleResponse(response);
    } on SocketException {
      throw ApiException(message: 'No internet connection');
    } on HttpException {
      throw ApiException(message: 'Network error occurred');
    } catch (e) {
      print('❌ Send chat message error: $e');
      throw ApiException(message: 'Failed to send message: ${e.toString()}');
    }
  }

  // Delete chat conversation
  static Future<Map<String, dynamic>?> deleteChatConversation({
    required String chatId,
  }) async {
    try {
      print('🔄 Deleting chat conversation: $chatId');

      final headers = await _getHeaders(includeAuth: true);
      final response = await http
          .delete(
            Uri.parse(
                '$baseUrl/ai/chat/$chatId'), // Fixed: changed from /chat to /ai/chat
            headers: headers,
          )
          .timeout(timeout);

      print('📡 Delete Chat Response Status: ${response.statusCode}');
      print('📡 Delete Chat Response: ${response.body}');

      return await _handleResponse(response);
    } on SocketException {
      throw ApiException(message: 'No internet connection');
    } on HttpException {
      throw ApiException(message: 'Network error occurred');
    } catch (e) {
      print('❌ Delete chat error: $e');
      throw ApiException(message: 'Failed to delete chat: ${e.toString()}');
    }
  }

  // Get symptom logs for a user
  static Future<Map<String, dynamic>?> getSymptomLogs({
    required String userId,
  }) async {
    try {
      print('🔄 Getting symptom logs for user: $userId');

      final headers = await _getHeaders(includeAuth: true);
      final response = await http
          .get(
            Uri.parse('$baseUrl/symptoms?userId=$userId'),
            headers: headers,
          )
          .timeout(timeout);

      print('📡 Symptom Logs Response Status: ${response.statusCode}');
      print('📡 Symptom Logs Response: ${response.body}');

      return await _handleResponse(response);
    } on SocketException {
      throw ApiException(message: 'No internet connection');
    } on HttpException {
      throw ApiException(message: 'Network error occurred');
    } catch (e) {
      print('❌ Get symptom logs error: $e');
      throw ApiException(
          message: 'Failed to load symptom logs: ${e.toString()}');
    }
  }

  // Create symptom log
  static Future<Map<String, dynamic>?> createSymptomLog({
    required String userId,
    required String date,
    required List<Map<String, dynamic>> symptoms,
    String? flow,
    String? mood,
    double? temperature,
    String? notes,
  }) async {
    try {
      print('🔄 Creating symptom log for user: $userId on date: $date');
      
      final uri = Uri.parse('$baseUrl/symptoms');
      final headers = await _getHeaders(includeAuth: true);
      
      final requestBody = {
        'userId': userId,
        'date': date,
        'symptoms': symptoms,
        if (flow != null) 'flow': flow,
        if (mood != null) 'mood': mood,
        if (temperature != null) 'temperature': temperature,
        if (notes != null) 'notes': notes,
      };
      
      print('📤 Symptom log request body: $requestBody');
      
      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(requestBody),
      ).timeout(timeout);
      
      print('📡 Symptom Log Response Status: ${response.statusCode}');
      print('📡 Symptom Log Response: ${response.body}');
      
      return await _handleResponse(response);
    } catch (e) {
      print('❌ Create symptom log error: $e');
      return {
        'success': false,
        'message': 'Error creating symptom log: $e',
      };
    }
  }

  // Update symptom log
  static Future<Map<String, dynamic>?> updateSymptomLog({
    required String symptomId,
    String? date,
    List<Map<String, dynamic>>? symptoms,
    String? flow,
    String? mood,
    double? temperature,
    String? notes,
  }) async {
    try {
      print('🔄 Updating symptom log: $symptomId');

      final headers = await _getHeaders(includeAuth: true);
      final body = json.encode({
        if (date != null) 'date': date,
        if (symptoms != null) 'symptoms': symptoms,
        if (flow != null) 'flow': flow,
        if (mood != null) 'mood': mood,
        if (temperature != null) 'temperature': temperature,
        if (notes != null) 'notes': notes,
      });

      final response = await http
          .put(
            Uri.parse('$baseUrl/symptoms/$symptomId'),
            headers: headers,
            body: body,
          )
          .timeout(timeout);

      return await _handleResponse(response);
    } on SocketException {
      throw ApiException(message: 'No internet connection');
    } on HttpException {
      throw ApiException(message: 'Network error occurred');
    } catch (e) {
      print('❌ Update symptom log error: $e');
      throw ApiException(
          message: 'Failed to update symptom log: ${e.toString()}');
    }
  }

  // Delete symptom log
  static Future<Map<String, dynamic>?> deleteSymptomLog({
    required String symptomId,
  }) async {
    try {
      print('🔄 Deleting symptom log: $symptomId');

      final headers = await _getHeaders(includeAuth: true);
      final response = await http
          .delete(
            Uri.parse('$baseUrl/symptoms/$symptomId'),
            headers: headers,
          )
          .timeout(timeout);

      return await _handleResponse(response);
    } on SocketException {
      throw ApiException(message: 'No internet connection');
    } on HttpException {
      throw ApiException(message: 'Network error occurred');
    } catch (e) {
      print('❌ Delete symptom log error: $e');
      throw ApiException(
          message: 'Failed to delete symptom log: ${e.toString()}');
    }
  }

  // Get user cycles
  static Future<Map<String, dynamic>?> getCycles({
    required String userId,
  }) async {
    try {
      print('🔄 Getting cycles for user: $userId');

      final headers = await _getHeaders(includeAuth: true);
      final response = await http
          .get(
            Uri.parse('$baseUrl/cycles?userId=$userId'),
            headers: headers,
          )
          .timeout(timeout);

      print('📡 Cycles Response Status: ${response.statusCode}');
      print('📡 Cycles Response: ${response.body}');

      return await _handleResponse(response);
    } on SocketException {
      throw ApiException(message: 'No internet connection');
    } on HttpException {
      throw ApiException(message: 'Network error occurred');
    } catch (e) {
      print('❌ Get cycles error: $e');
      throw ApiException(message: 'Failed to get cycles: ${e.toString()}');
    }
  }

  // Create cycle
  static Future<Map<String, dynamic>?> createCycle({
    required String userId,
    required String startDate,
    String? endDate,
    int cycleLength = 28,
    int periodLength = 5,
    String flow = 'medium',
    String mood = 'normal',
    List<Map<String, dynamic>>? symptoms,
    double? temperature,
    String notes = '',
  }) async {
    try {
      print('🔄 Creating cycle for user: $userId');

      final headers = await _getHeaders(includeAuth: true);
      final body = json.encode({
        'userId': userId,
        'startDate': startDate,
        if (endDate != null) 'endDate': endDate,
        'cycleLength': cycleLength,
        'periodLength': periodLength,
        'flow': flow,
        'mood': mood,
        'symptoms': symptoms ?? [],
        'temperature': temperature,
        'notes': notes,
      });

      print('📤 Create Cycle Body: $body');

      final response = await http
          .post(
            Uri.parse('$baseUrl/cycles'),
            headers: headers,
            body: body,
          )
          .timeout(timeout);

      print('📡 Create Cycle Response Status: ${response.statusCode}');
      print('📡 Create Cycle Response: ${response.body}');

      return await _handleResponse(response);
    } on SocketException {
      throw ApiException(message: 'No internet connection');
    } on HttpException {
      throw ApiException(message: 'Network error occurred');
    } catch (e) {
      print('❌ Create cycle error: $e');
      throw ApiException(message: 'Failed to create cycle: ${e.toString()}');
    }
  }

  // Add cycle
  static Future<Map<String, dynamic>?> addCycle(
      Map<String, dynamic> cycleData) async {
    try {
      print('📤 Sending new cycle data to API: $cycleData');

      final uri = Uri.parse('$baseUrl/cycles');
      final headers = await _getHeaders(includeAuth: true);

      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(cycleData),
      );

      final responseData = jsonDecode(response.body);

      // Status code 200 or 201 are both success codes
      if (response.statusCode >= 200 && response.statusCode < 300) {
        print('✅ Successfully added new cycle');
        return responseData;
      } else {
        print('❌ Failed to add cycle: ${response.statusCode}');
        print('Error response: $responseData');
        return null;
      }
    } catch (e) {
      print('❌ Exception when adding cycle: $e');
      return null;
    }
  }

  // Update cycle
  static Future<Map<String, dynamic>?> updateCycle({
    required String cycleId,
    String? startDate,
    String? endDate,
    int? cycleLength,
    int? periodLength,
    String? flow,
    String? mood,
    List<Map<String, dynamic>>? symptoms,
    double? temperature,
    String? notes,
  }) async {
    try {
      print('🔄 Updating cycle: $cycleId');

      final headers = await _getHeaders(includeAuth: true);
      final body = json.encode({
        if (startDate != null) 'startDate': startDate,
        if (endDate != null) 'endDate': endDate,
        if (cycleLength != null) 'cycleLength': cycleLength,
        if (periodLength != null) 'periodLength': periodLength,
        if (flow != null) 'flow': flow,
        if (mood != null) 'mood': mood,
        if (symptoms != null) 'symptoms': symptoms,
        if (temperature != null) 'temperature': temperature,
        if (notes != null) 'notes': notes,
      });

      final response = await http
          .put(
            Uri.parse('$baseUrl/cycles/$cycleId'),
            headers: headers,
            body: body,
          )
          .timeout(timeout);

      return await _handleResponse(response);
    } on SocketException {
      throw ApiException(message: 'No internet connection');
    } on HttpException {
      throw ApiException(message: 'Network error occurred');
    } catch (e) {
      print('❌ Update cycle error: $e');
      throw ApiException(message: 'Failed to update cycle: ${e.toString()}');
    }
  }

  // Delete cycle
  static Future<Map<String, dynamic>?> deleteCycle({
    required String cycleId,
  }) async {
    try {
      print('🔄 Deleting cycle: $cycleId');

      final headers = await _getHeaders(includeAuth: true);
      final response = await http
          .delete(
            Uri.parse('$baseUrl/cycles/$cycleId'),
            headers: headers,
          )
          .timeout(timeout);

      return await _handleResponse(response);
    } on SocketException {
      throw ApiException(message: 'No internet connection');
    } on HttpException {
      throw ApiException(message: 'Network error occurred');
    } catch (e) {
      print('❌ Delete cycle error: $e');
      throw ApiException(message: 'Failed to delete cycle: ${e.toString()}');
    }
  }

  // Get doctor consultations for a user
  static Future<Map<String, dynamic>?> getDoctorConsultations({
    required String userId,
  }) async {
    try {
      print('🔄 Getting doctor consultations for user: $userId');

      final headers = await _getHeaders(includeAuth: true);
      final response = await http
          .get(
            Uri.parse('$baseUrl/doctor/consultations?userId=$userId'),
            headers: headers,
          )
          .timeout(timeout);

      print('📡 Doctor Consultations Response Status: ${response.statusCode}');
      print('📡 Doctor Consultations Response: ${response.body}');

      return await _handleResponse(response);
    } on SocketException {
      throw ApiException(message: 'No internet connection');
    } on HttpException {
      throw ApiException(message: 'Network error occurred');
    } catch (e) {
      print('❌ Get doctor consultations error: $e');
      throw ApiException(
          message: 'Failed to load consultations: ${e.toString()}');
    }
  }

  // Create doctor consultation
  static Future<Map<String, dynamic>?> createDoctorConsultation({
    required String userId,
    required String doctorName,
    required String scheduledDate,
    String type = 'general',
    int duration = 30,
    String reason = '',
    String notes = '',
  }) async {
    try {
      print('🔄 Creating doctor consultation for user: $userId');

      final headers = await _getHeaders(includeAuth: true);
      final body = json.encode({
        'userId': userId,
        'doctorName': doctorName,
        'type': type,
        'scheduledDate': scheduledDate,
        'duration': duration,
        'reason': reason,
        'notes': notes,
      });

      print('📤 Create Doctor Consultation Body: $body');

      final response = await http
          .post(
            Uri.parse('$baseUrl/doctor/consultations'),
            headers: headers,
            body: body,
          )
          .timeout(timeout);

      print(
          '📡 Create Doctor Consultation Response Status: ${response.statusCode}');
      print('📡 Create Doctor Consultation Response: ${response.body}');

      return await _handleResponse(response);
    } on SocketException {
      throw ApiException(message: 'No internet connection');
    } on HttpException {
      throw ApiException(message: 'Network error occurred');
    } catch (e) {
      print('❌ Create doctor consultation error: $e');
      throw ApiException(
          message: 'Failed to create consultation: ${e.toString()}');
    }
  }

  // Update doctor consultation
  static Future<Map<String, dynamic>?> updateDoctorConsultation({
    required String consultationId,
    String? doctorName,
    String? type,
    String? status,
    String? scheduledDate,
    int? duration,
    String? reason,
    String? notes,
  }) async {
    try {
      print('🔄 Updating doctor consultation: $consultationId');

      final headers = await _getHeaders(includeAuth: true);
      final body = json.encode({
        if (doctorName != null) 'doctorName': doctorName,
        if (type != null) 'type': type,
        if (status != null) 'status': status,
        if (scheduledDate != null) 'scheduledDate': scheduledDate,
        if (duration != null) 'duration': duration,
        if (reason != null) 'reason': reason,
        if (notes != null) 'notes': notes,
      });

      final response = await http
          .put(
            Uri.parse('$baseUrl/doctor/consultations/$consultationId'),
            headers: headers,
            body: body,
          )
          .timeout(timeout);

      return await _handleResponse(response);
    } on SocketException {
      throw ApiException(message: 'No internet connection');
    } on HttpException {
      throw ApiException(message: 'Network error occurred');
    } catch (e) {
      print('❌ Update doctor consultation error: $e');
      throw ApiException(
          message: 'Failed to update consultation: ${e.toString()}');
    }
  }

  // Delete doctor consultation
  static Future<Map<String, dynamic>?> deleteDoctorConsultation({
    required String consultationId,
  }) async {
    try {
      print('🔄 Deleting doctor consultation: $consultationId');

      final headers = await _getHeaders(includeAuth: true);
      final response = await http
          .delete(
            Uri.parse('$baseUrl/doctor/consultations/$consultationId'),
            headers: headers,
          )
          .timeout(timeout);

      return await _handleResponse(response);
    } on SocketException {
      throw ApiException(message: 'No internet connection');
    } on HttpException {
      throw ApiException(message: 'Network error occurred');
    } catch (e) {
      print('❌ Delete doctor consultation error: $e');
      throw ApiException(
          message: 'Failed to delete consultation: ${e.toString()}');
    }
  }

  // Get AI doctor consultations
  static Future<Map<String, dynamic>?> getAIDoctorConsultations({
    required String userId,
  }) async {
    try {
      print('🔄 Getting AI doctor consultations for user: $userId');

      final headers = await _getHeaders(includeAuth: true);
      final response = await http
          .get(
            Uri.parse('$baseUrl/ai/doctor-consultations?userId=$userId'),
            headers: headers,
          )
          .timeout(timeout);

      print('📡 AI Doctor Consultations Response Status: ${response.statusCode}');
      print('📡 AI Doctor Consultations Response: ${response.body}');

      return await _handleResponse(response);
    } on SocketException {
      throw ApiException(message: 'No internet connection');
    } on HttpException {
      throw ApiException(message: 'Network error occurred');
    } catch (e) {
      print('❌ Get AI doctor consultations error: $e');
      throw ApiException(
          message: 'Failed to load AI consultations: ${e.toString()}');
    }
  }

  // Create AI doctor consultation
  static Future<Map<String, dynamic>?> createAIDoctorConsultation({
    required String userId,
    required String symptoms,
    required int severity,
    String? duration,
    String? additionalNotes,
  }) async {
    try {
      print('🔄 Creating AI doctor consultation for user: $userId');

      final headers = await _getHeaders(includeAuth: true);
      final body = json.encode({
        'userId': userId,
        'symptoms': symptoms,
        'severity': severity,
        if (duration != null) 'duration': duration,
        if (additionalNotes != null) 'additionalNotes': additionalNotes,
      });

      print('📤 Create AI Doctor Consultation Body: $body');

      final response = await http
          .post(
            Uri.parse('$baseUrl/ai/doctor-consultation'),
            headers: headers,
            body: body,
          )
          .timeout(timeout);

      print(
          '📡 Create AI Doctor Consultation Response Status: ${response.statusCode}');
      print('📡 Create AI Doctor Consultation Response: ${response.body}');

      return await _handleResponse(response);
    } on SocketException {
      throw ApiException(message: 'No internet connection');
    } on HttpException {
      throw ApiException(message: 'Network error occurred');
    } catch (e) {
      print('❌ Create AI doctor consultation error: $e');
      throw ApiException(
          message: 'Failed to create AI consultation: ${e.toString()}');
    }
  }

  // Get user reports
  static Future<Map<String, dynamic>?> getUserReports({
    required String userId,
  }) async {
    try {
      print('🔄 Getting reports for user: $userId');

      final headers = await _getHeaders(includeAuth: true);
      final response = await http
          .get(
            Uri.parse('$baseUrl/reports?userId=$userId'),
            headers: headers,
          )
          .timeout(timeout);

      print('📡 Reports Response Status: ${response.statusCode}');
      print('📡 Reports Response: ${response.body}');

      return await _handleResponse(response);
    } on SocketException {
      throw ApiException(message: 'No internet connection');
    } on HttpException {
      throw ApiException(message: 'Network error occurred');
    } catch (e) {
      print('❌ Get reports error: $e');
      throw ApiException(message: 'Failed to load reports: ${e.toString()}');
    }
  }

  // Create user report
  static Future<Map<String, dynamic>?> createReport({
    required Map<String, dynamic> reportData,
  }) async {
    try {
      print('🔄 Creating new report');
      print('📤 Report data: $reportData');

      final headers = await _getHeaders(includeAuth: true);
      final body = json.encode(reportData);

      final response = await http
          .post(
            Uri.parse('$baseUrl/reports'),
            headers: headers,
            body: body,
          )
          .timeout(timeout);

      print('📡 Create Report Response Status: ${response.statusCode}');
      print('📡 Create Report Response: ${response.body}');

      return await _handleResponse(response);
    } on SocketException {
      throw ApiException(message: 'No internet connection');
    } on HttpException {
      throw ApiException(message: 'Network error occurred');
    } catch (e) {
      print('❌ Create report error: $e');
      throw ApiException(message: 'Failed to create report: ${e.toString()}');
    }
  }

  // Get User Stats
  static Future<Map<String, dynamic>?> getUserStats() async {
    try {
      final headers = await _getHeaders();

      final response = await http
          .get(
            Uri.parse('$baseUrl/users/stats'),
            headers: headers,
          )
          .timeout(timeout);

      return await _handleResponse(response);
    } on SocketException {
      throw ApiException(message: 'No internet connection');
    } on HttpException {
      throw ApiException(message: 'Network error occurred');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Failed to get user stats: ${e.toString()}');
    }
  }

  // Get AI Dashboard Insights
  static Future<Map<String, dynamic>?> getAIDashboardInsights() async {
    try {
      final headers = await _getHeaders();

      final response = await http
          .get(
            Uri.parse('$baseUrl/ai/insights'),
            headers: headers,
          )
          .timeout(timeout);

      return await _handleResponse(response);
    } on SocketException {
      throw ApiException(message: 'No internet connection');
    } on HttpException {
      throw ApiException(message: 'Network error occurred');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Failed to get AI insights: ${e.toString()}');
    }
  }

  // Clear authentication
  static Future<void> clearAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.setBool('is_authenticated', false);
  }
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException({required this.message, this.statusCode});

  @override
  String toString() => message;
}
