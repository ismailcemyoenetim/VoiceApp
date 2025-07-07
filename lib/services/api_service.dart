import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  static const String _baseUrlLocal = 'http://localhost:3000/api';
  static const String _baseUrlWeb = 'http://localhost:3000/api';
  static const String _baseUrlDevice = 'http://192.168.1.100:3000/api';
  
  // Get base URL based on platform
  static String get baseUrl {
    if (kIsWeb) {
      return _baseUrlWeb;
    } else if (Platform.isIOS || Platform.isAndroid) {
      // For real devices, use the Mac's IP address
      return _baseUrlDevice;
    } else {
      // For simulators/emulators and desktop, use localhost
      return _baseUrlLocal;
    }
  }
  
  // HTTP client with timeout
  static const Duration _timeout = Duration(seconds: 30);
  
  // Get auth token from storage
  static Future<String?> _getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      debugPrint('🔐 Retrieved token from storage: ${token != null ? 'Present (${token.length} chars)' : 'Missing'}');
      return token;
    } catch (e) {
      debugPrint('Error getting token: $e');
      return null;
    }
  }
  
  // Save auth token to storage
  static Future<void> _saveToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
    } catch (e) {
      debugPrint('Error saving token: $e');
    }
  }
  
  // Remove auth token from storage
  static Future<void> _removeToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
    } catch (e) {
      debugPrint('Error removing token: $e');
    }
  }
  
  // Get headers with authentication
  static Future<Map<String, String>> _getHeaders({bool includeAuth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    if (includeAuth) {
      final token = await _getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    
    return headers;
  }
  
  // Get headers for multipart requests
  static Future<Map<String, String>> _getMultipartHeaders() async {
    final headers = <String, String>{
      'Accept': 'application/json',
    };
    
    final token = await _getToken();
    debugPrint('🔐 Getting multipart headers - token: ${token != null ? 'Present' : 'Missing'}');
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
      debugPrint('🔐 Added auth header: Bearer ${token.substring(0, 10)}...');
    }
    
    return headers;
  }
  
  // Handle API response
  static Map<String, dynamic> _handleResponse(http.Response response) {
    debugPrint('API Response: ${response.statusCode} - ${response.body}');
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        return json.decode(response.body);
      } catch (e) {
        throw ApiException('Invalid JSON response', response.statusCode);
      }
    } else {
      String errorMessage = 'Unknown error';
      try {
        final errorData = json.decode(response.body);
        errorMessage = errorData['message'] ?? errorMessage;
      } catch (e) {
        errorMessage = 'HTTP ${response.statusCode}';
      }
      throw ApiException(errorMessage, response.statusCode);
    }
  }
  
  // AUTHENTICATION ENDPOINTS
  
  static Future<Map<String, dynamic>> signUp({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/signup'),
        headers: await _getHeaders(includeAuth: false),
        body: json.encode({
          'username': username,
          'email': email,
          'password': password,
        }),
      ).timeout(_timeout);
      
      final data = _handleResponse(response);
      
      // Save token if signup successful
      if (data['success'] == true && data['token'] != null) {
        await _saveToken(data['token']);
      }
      
      return data;
    } catch (e) {
      debugPrint('SignUp API Error: $e');
      rethrow;
    }
  }
  
  static Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/signin'),
        headers: await _getHeaders(includeAuth: false),
        body: json.encode({
          'email': email,
          'password': password,
        }),
      ).timeout(_timeout);
      
      final data = _handleResponse(response);
      
      // Save token if signin successful
      if (data['success'] == true && data['token'] != null) {
        await _saveToken(data['token']);
      }
      
      return data;
    } catch (e) {
      debugPrint('SignIn API Error: $e');
      rethrow;
    }
  }
  
  static Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/profile'),
        headers: await _getHeaders(),
      ).timeout(_timeout);
      
      return _handleResponse(response);
    } catch (e) {
      debugPrint('GetProfile API Error: $e');
      rethrow;
    }
  }
  
  static Future<Map<String, dynamic>> updateProfile({
    String? username,
    String? bio,
    String? link,
    String? profilePicturePath,
  }) async {
    try {
      if (profilePicturePath != null) {
        // Use multipart form data for file upload
        final request = http.MultipartRequest(
          'PUT',
          Uri.parse('$baseUrl/auth/profile'),
        );
        
        // Add headers (multipart headers - no Content-Type for multipart)
        final headers = await _getMultipartHeaders();
        request.headers.addAll(headers);
        
        debugPrint('🔐 Multipart headers: $headers');
        
        // Add file with proper extension detection
        final file = File(profilePicturePath);
        final fileName = profilePicturePath.split('/').last;
        final extension = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'jpg';
        
        debugPrint('🖼️ Upload file - Original path: $profilePicturePath');
        debugPrint('🖼️ Upload file - File name: $fileName');
        debugPrint('🖼️ Upload file - Extension: $extension');
        debugPrint('🖼️ Upload file - Final filename: profile_picture.$extension');
        
        request.files.add(
          await http.MultipartFile.fromPath(
            'profile_picture',
            profilePicturePath,
            filename: 'profile_picture.$extension',
          ),
        );
        
        // Add other fields
        if (username != null) request.fields['username'] = username;
        if (bio != null) request.fields['bio'] = bio;
        if (link != null) request.fields['link'] = link;
        
        final streamedResponse = await request.send().timeout(_timeout);
        final response = await http.Response.fromStream(streamedResponse);
        
        return _handleResponse(response);
      } else {
        // Regular form data (no file)
        final body = <String, dynamic>{};
        if (username != null) body['username'] = username;
        if (bio != null) body['bio'] = bio;
        if (link != null) body['link'] = link;
        
        final response = await http.put(
          Uri.parse('$baseUrl/auth/profile'),
          headers: await _getHeaders(),
          body: json.encode(body),
        ).timeout(_timeout);
        
        return _handleResponse(response);
      }
    } catch (e) {
      debugPrint('UpdateProfile API Error: $e');
      rethrow;
    }
  }
  
  static Future<void> signOut() async {
    try {
      await _removeToken();
    } catch (e) {
      debugPrint('SignOut API Error: $e');
    }
  }
  
  // VOICE POSTS ENDPOINTS
  
  static Future<Map<String, dynamic>> getAllPosts({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/posts?page=$page&limit=$limit'),
        headers: await _getHeaders(includeAuth: true),
      ).timeout(_timeout);
      
      return _handleResponse(response);
    } catch (e) {
      debugPrint('GetAllPosts API Error: $e');
      rethrow;
    }
  }
  
  static Future<Map<String, dynamic>> getPost(String postId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/posts/$postId'),
        headers: await _getHeaders(includeAuth: true),
      ).timeout(_timeout);
      
      return _handleResponse(response);
    } catch (e) {
      debugPrint('GetPost API Error: $e');
      rethrow;
    }
  }
  
  static Future<Map<String, dynamic>> createPost({
    required File audioFile,
    required int durationMs,
    String? description,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/posts'),
      );
      
      request.headers.addAll(await _getMultipartHeaders());
      
      // Add audio file
      request.files.add(
        await http.MultipartFile.fromPath(
          'audio',
          audioFile.path,
          filename: 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
          contentType: MediaType('audio', 'mp4'), // M4A files are typically audio/mp4
        ),
      );
      
      // Add other fields
      request.fields['duration_ms'] = durationMs.toString();
      if (description != null) request.fields['description'] = description;
      
      final streamedResponse = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);
      
      return _handleResponse(response);
    } catch (e) {
      debugPrint('CreatePost API Error: $e');
      rethrow;
    }
  }
  
  static Future<Map<String, dynamic>> updatePost({
    required String postId,
    String? description,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/posts/$postId'),
        headers: await _getHeaders(),
        body: json.encode({
          'description': description,
        }),
      ).timeout(_timeout);
      
      return _handleResponse(response);
    } catch (e) {
      debugPrint('UpdatePost API Error: $e');
      rethrow;
    }
  }
  
  static Future<Map<String, dynamic>> deletePost(String postId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/posts/$postId'),
        headers: await _getHeaders(),
      ).timeout(_timeout);
      
      return _handleResponse(response);
    } catch (e) {
      debugPrint('DeletePost API Error: $e');
      rethrow;
    }
  }
  
  static Future<Map<String, dynamic>> likePost(String postId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/posts/$postId/like'),
        headers: await _getHeaders(),
      ).timeout(_timeout);
      
      return _handleResponse(response);
    } catch (e) {
      debugPrint('LikePost API Error: $e');
      rethrow;
    }
  }
  
  static Future<Map<String, dynamic>> getComments(String postId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/posts/$postId/comments'),
        headers: await _getHeaders(includeAuth: false),
      ).timeout(_timeout);
      
      return _handleResponse(response);
    } catch (e) {
      debugPrint('GetComments API Error: $e');
      rethrow;
    }
  }
  
  static Future<Map<String, dynamic>> addComment({
    required String postId,
    required String content,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/posts/$postId/comments'),
        headers: await _getHeaders(),
        body: json.encode({
          'content': content,
        }),
      ).timeout(_timeout);
      
      return _handleResponse(response);
    } catch (e) {
      debugPrint('AddComment API Error: $e');
      rethrow;
    }
  }
  
  // USER ENDPOINTS
  
  static Future<Map<String, dynamic>> searchUsers({
    required String query,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users?q=$query&page=$page&limit=$limit'),
        headers: await _getHeaders(includeAuth: false),
      ).timeout(_timeout);
      
      return _handleResponse(response);
    } catch (e) {
      debugPrint('SearchUsers API Error: $e');
      rethrow;
    }
  }
  
  static Future<Map<String, dynamic>> getUserProfile(String username) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/$username'),
        headers: await _getHeaders(includeAuth: false),
      ).timeout(_timeout);
      
      return _handleResponse(response);
    } catch (e) {
      debugPrint('GetUserProfile API Error: $e');
      rethrow;
    }
  }
  
  static Future<Map<String, dynamic>> getUserPosts({
    required String username,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/$username/posts?page=$page&limit=$limit'),
        headers: await _getHeaders(includeAuth: false),
      ).timeout(_timeout);
      
      return _handleResponse(response);
    } catch (e) {
      debugPrint('GetUserPosts API Error: $e');
      rethrow;
    }
  }
  
  static Future<Map<String, dynamic>> followUser(String username) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/$username/follow'),
        headers: await _getHeaders(),
      ).timeout(_timeout);
      
      return _handleResponse(response);
    } catch (e) {
      debugPrint('FollowUser API Error: $e');
      rethrow;
    }
  }
  
  static Future<Map<String, dynamic>> getFollowers({
    required String username,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/$username/followers?page=$page&limit=$limit'),
        headers: await _getHeaders(includeAuth: false),
      ).timeout(_timeout);
      
      return _handleResponse(response);
    } catch (e) {
      debugPrint('GetFollowers API Error: $e');
      rethrow;
    }
  }
  
  static Future<Map<String, dynamic>> getFollowing({
    required String username,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/$username/following?page=$page&limit=$limit'),
        headers: await _getHeaders(includeAuth: false),
      ).timeout(_timeout);
      
      return _handleResponse(response);
    } catch (e) {
      debugPrint('GetFollowing API Error: $e');
      rethrow;
    }
  }
}

// Custom exception for API errors
class ApiException implements Exception {
  final String message;
  final int statusCode;
  
  ApiException(this.message, this.statusCode);
  
  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
} 