import 'dart:convert';
import 'package:doc_delete/Models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  /// Get Logged User
  static Future<UserModel?> getUser() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    String? userData = prefs.getString("user");

    if (userData == null) return null;

    return UserModel.fromJson(jsonDecode(userData));
  }

  /// Get User ID
  static Future<int?> getUserId() async {
    UserModel? user = await getUser();

    return user?.id;
  }

  static Future<String?> getUserName() async {
    UserModel? user = await getUser();
    return user?.name;
  }
}

class AddressFormatter {
  static String format(String address) {
    if (address.trim().isEmpty) return "";

    List<String> parts = address
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (parts.length <= 1) {
      return parts.isNotEmpty ? parts.first : "";
    }

    String line2 = "${parts[parts.length - 2]}, ${parts[parts.length - 1]}";
    String line1 = parts.sublist(0, parts.length - 2).join(', ');

    // ✅ Fix: line1 empty હોય તો comma નહીં
    if (line1.isEmpty) return line2;

    return "$line1,\n$line2";
  }
}

class AppColors {
  static const Color darkGreen = Color(0xFF023021);
  static const Color white = Colors.white;
  static const Color black = Colors.black;
  static const Color grey = Colors.grey;
  static const Color red = Colors.red;
  static const Color blue = Colors.blue;
  static const Color orange = Colors.orange;
}
