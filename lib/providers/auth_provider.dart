import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/api_service.dart';

class User {
  final String id;
  final String username;
  final String email;
  final String? profilePicture;
  final String? bio;
  final String? link;
  final DateTime createdAt;
  final bool isAdmin;

  User({
    required this.id,
    required this.username,
    required this.email,
    this.profilePicture,
    this.bio,
    this.link,
    required this.createdAt,
    this.isAdmin = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'profile_picture': profilePicture,
      'bio': bio,
      'link': link,
      'created_at': createdAt.toIso8601String(),
      'is_admin': isAdmin,
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      profilePicture: json['profile_picture'],
      bio: json['bio'],
      link: json['link'],
      createdAt: DateTime.parse(json['created_at'] ?? json['createdAt'] ?? DateTime.now().toIso8601String()),
      isAdmin: json['is_admin'] ?? json['isAdmin'] ?? false,
    );
  }
}

class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  String? _errorMessage;

  User? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  AuthProvider() {
    _loadUserFromStorage();
  }

  Future<void> _loadUserFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      if (token != null) {
        // Try to get user profile from backend
        try {
          final response = await ApiService.getProfile();
          if (response['success'] == true && response['user'] != null) {
            _user = User.fromJson(response['user']);
            notifyListeners();
          } else {
            // Token might be invalid, try to use local user data as fallback
            final userData = prefs.getString('user_data');
            if (userData != null) {
              try {
                final userJson = jsonDecode(userData) as Map<String, dynamic>;
                _user = User.fromJson(userJson);
                notifyListeners();
              } catch (e) {
                debugPrint('Error parsing local user data: $e');
                await _clearUserData();
              }
            } else {
              await _clearUserData();
            }
          }
        } catch (e) {
          debugPrint('Error loading user from backend: $e');
          // Try to use local user data as fallback
          final userData = prefs.getString('user_data');
          if (userData != null) {
            try {
              final userJson = jsonDecode(userData) as Map<String, dynamic>;
              _user = User.fromJson(userJson);
              notifyListeners();
            } catch (e) {
              debugPrint('Error parsing local user data: $e');
              await _clearUserData();
            }
          } else {
            await _clearUserData();
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading user from storage: $e');
    }
  }

  Future<void> _clearUserData() async {
    try {
      await ApiService.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      _user = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing user data: $e');
    }
  }

  Future<bool> signUp({
    required String username,
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiService.signUp(
        username: username,
        email: email,
        password: password,
      );

      if (response['success'] == true) {
        _user = User.fromJson(response['user']);
        
        // Save user data and token to local storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_data', jsonEncode(_user!.toJson()));
        if (response['token'] != null) {
          await prefs.setString('auth_token', response['token']);
        }
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = response['message'] ?? 'Sign up failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      if (e is ApiException) {
        _errorMessage = e.message;
      } else {
        _errorMessage = 'Network error. Please check your connection.';
      }
      notifyListeners();
      debugPrint('SignUp error: $e');
      return false;
    }
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiService.signIn(
        email: email,
        password: password,
      );

      if (response['success'] == true) {
        _user = User.fromJson(response['user']);
        
        // Save user data and token to local storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_data', jsonEncode(_user!.toJson()));
        if (response['token'] != null) {
          await prefs.setString('auth_token', response['token']);
        }
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = response['message'] ?? 'Sign in failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      if (e is ApiException) {
        _errorMessage = e.message;
      } else {
        _errorMessage = 'Network error. Please check your connection.';
      }
      notifyListeners();
      debugPrint('SignIn error: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await _clearUserData();
    } catch (e) {
      debugPrint('SignOut error: $e');
    }
  }

  // Profile picture upload state
  bool _isUploadingProfilePicture = false;
  
  bool get isUploadingProfilePicture => _isUploadingProfilePicture;

  Future<bool> updateProfile({
    String? username,
    String? bio,
    String? link,
    String? profilePicture,
  }) async {
    if (_user == null) return false;

    // If updating profile picture, prevent multiple uploads
    if (profilePicture != null) {
      if (_isUploadingProfilePicture) {
        debugPrint('⏳ Profile picture upload already in progress, skipping...');
        return false;
      }
      _isUploadingProfilePicture = true;
      notifyListeners();
    }

    debugPrint('🖼️ UpdateProfile called with profilePicture: $profilePicture');
    
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiService.updateProfile(
        username: username,
        bio: bio,
        link: link,
        profilePicturePath: profilePicture, // Send file path to backend
      );

      if (response['success'] == true) {
        _user = User.fromJson(response['user']);
        
        debugPrint('🖼️ Backend response user: ${_user!.profilePicture}');
        
        // Update local storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_data', jsonEncode(_user!.toJson()));
        
        _isLoading = false;
        if (profilePicture != null) {
          _isUploadingProfilePicture = false;
        }
        notifyListeners();
        return true;
      } else {
        _errorMessage = response['message'] ?? 'Profile update failed';
        _isLoading = false;
        if (profilePicture != null) {
          _isUploadingProfilePicture = false;
        }
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      if (profilePicture != null) {
        _isUploadingProfilePicture = false;
      }
      if (e is ApiException) {
        _errorMessage = e.message;
      } else {
        _errorMessage = 'Network error. Please check your connection.';
      }
      notifyListeners();
      debugPrint('Update profile error: $e');
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
} 