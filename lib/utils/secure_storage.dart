import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureStorage {
  // Simplified storage configuration
  static const _storage = FlutterSecureStorage();

  // Write data to secure storage
  Future<void> write(String key, String value) async {
    try {
      if (kDebugMode) {
        print('💾 Writing to secure storage: $key');
      }
      await _storage.write(key: key, value: value);
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Secure storage failed, using SharedPreferences fallback: $e');
      }
      // Fallback to SharedPreferences if secure storage fails
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    }
  }

  // Read data from secure storage
  Future<String?> read(String key) async {
    try {
      if (kDebugMode) {
        print('📖 Reading from secure storage: $key');
      }
      return await _storage.read(key: key);
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Secure storage failed, using SharedPreferences fallback: $e');
      }
      // Fallback to SharedPreferences if secure storage fails
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    }
  }

  // Delete data from secure storage
  Future<void> delete(String key) async {
    try {
      if (kDebugMode) {
        print('🗑️ Deleting from secure storage: $key');
      }
      await _storage.delete(key: key);
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Secure storage failed, using SharedPreferences fallback: $e');
      }
      // Fallback to SharedPreferences if secure storage fails
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    }
  }

  // Delete all data from secure storage
  Future<void> deleteAll() async {
    try {
      if (kDebugMode) {
        print('🗑️ Clearing all secure storage data');
      }
      await _storage.deleteAll();
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Secure storage failed, using SharedPreferences fallback: $e');
      }
      // Fallback to SharedPreferences if secure storage fails
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    }
  }

  // Check if key exists
  Future<bool> containsKey(String key) async {
    try {
      return await _storage.containsKey(key: key);
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Secure storage failed, using SharedPreferences fallback: $e');
      }
      // Fallback to SharedPreferences if secure storage fails
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(key);
    }
  }

  // Get all keys
  Future<Map<String, String>> readAll() async {
    try {
      return await _storage.readAll();
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Secure storage readAll failed: $e');
      }
      // Return empty map if secure storage fails
      return {};
    }
  }
}
