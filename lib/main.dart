import 'dart:convert';

import 'package:doc_delete/Admin Screens/admin_dashboard_screen.dart';
import 'package:doc_delete/Screens/login_screen.dart';
import 'package:doc_delete/Technician Screens/technician_dashboard_screen.dart';
import 'package:doc_delete/utils/session_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'Models/user_model.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<Widget> checkLogin() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    String? userData = prefs.getString("user");
    if (userData != null) {
      UserModel user = UserModel.fromJson(jsonDecode(userData));

      if (user.role == "admin") {
        return const AdminDashboard();
      } else {
        return const DashboardScreen();
      }
    }

    return const LoginScreen();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "DocDelete",
      home: FutureBuilder(
        future: checkLogin(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return snapshot.data as Widget;
          }

          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        },
      ),
    );
  }
}
