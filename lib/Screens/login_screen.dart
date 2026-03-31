import 'dart:convert';
import 'dart:ui';
import 'package:doc_delete/Admin%20Screens/admin_screen.dart';
import 'package:doc_delete/Models/user_model.dart';
import 'package:doc_delete/Technician%20Screens/dashboard_screen.dart';
import 'package:doc_delete/config/api_urls.dart';
import 'package:doc_delete/utils/session_manager.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool obscurePassword = true;
  bool isLoading = false;

  late AnimationController controller;

  final url = Uri.parse(ApiUrls.login);

  @override
  void initState() {
    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    super.initState();
  }

  Future<void> login() async {
    setState(() {
      isLoading = true;
    });

    try {
      var response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": emailController.text.trim(),
          "password": passwordController.text.trim(),
        }),
      );

      final data = jsonDecode(response.body);

      if (data["status"] == true) {
        UserModel user = UserModel.fromJson(data["user"]);

        SharedPreferences prefs = await SharedPreferences.getInstance();

        prefs.setBool("isLogin", true);
        prefs.setString("role", user.role);

        String userJson = jsonEncode(user.toJson());

        prefs.setString("user", userJson);

        String role = data["role"];

        if (role == "admin") {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AdminDashboard()),
          );
        } else if (role == "technician") {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const DashboardScreen()),
          );
        }
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(data["message"])));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Server Error: $e")));
      print("Server Error: $e");
    }

    setState(() {
      isLoading = false;
    });
  }

  @override
  void dispose() {
    controller.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          return Container(
            color: AppColors.darkGreen,
            child: LayoutBuilder(
              builder: (context, constraints) {
                double width = constraints.maxWidth;
                double cardWidth;
                if (width < 600) {
                  cardWidth = width * 0.9; // mobile
                } else if (width < 1300) {
                  cardWidth = 420; // tablet
                } else {
                  cardWidth = 500; // desktop
                }

                return Stack(
                  children: [
                    /// floating circles
                    Positioned(top: -80, left: -60, child: buildCircle(240)),
                    Positioned(
                      bottom: -120,
                      right: -60,
                      child: buildCircle(280),
                    ),

                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                          child: Container(
                            width: cardWidth,
                            padding: const EdgeInsets.all(35),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.black,
                                  blurRadius: 30,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  /// LOGO
                                  Container(
                                    height: 80,
                                    width: 80,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.darkGreen,
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.darkGreen
                                              .withOpacity(0.5),
                                          blurRadius: 10,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.admin_panel_settings,
                                      color: AppColors.white,
                                      size: 40,
                                    ),
                                  ),

                                  const SizedBox(height: 20),

                                  const Text(
                                    "Login",
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.black,
                                    ),
                                  ),

                                  const SizedBox(height: 6),

                                  const Text(
                                    "Sign in to continue",
                                    style: TextStyle(color: Colors.black54),
                                  ),

                                  const SizedBox(height: 35),

                                  buildTextField(
                                    controller: emailController,
                                    hint: "Email Address",
                                    icon: Icons.email_outlined,
                                    keyboardType: TextInputType.emailAddress,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return "Email is required";
                                      }

                                      if (!RegExp(
                                        r'\S+@\S+\.\S+',
                                      ).hasMatch(value)) {
                                        return "Enter valid email";
                                      }

                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 20),

                                  buildTextField(
                                    controller: passwordController,
                                    hint: "Password",
                                    icon: Icons.lock_outline,
                                    obscure: obscurePassword,
                                    suffix: IconButton(
                                      icon: Icon(
                                        obscurePassword
                                            ? Icons.visibility
                                            : Icons.visibility_off,
                                        color: Colors.black54,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          obscurePassword = !obscurePassword;
                                        });
                                      },
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return "Password is required";
                                      }

                                      if (value.length < 6) {
                                        return "Password must be 6 characters";
                                      }

                                      return null;
                                    },
                                  ),

                                  const SizedBox(height: 35),

                                  /// LOGIN BUTTON
                                  GestureDetector(
                                    onTap: () {
                                      if (_formKey.currentState!.validate()) {
                                        login();
                                      }
                                    },
                                    child: Container(
                                      height: 55,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: AppColors.darkGreen,
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.darkGreen
                                                .withOpacity(0.5),
                                            blurRadius: 10,
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: isLoading
                                            ? const CircularProgressIndicator(
                                                color: AppColors.white,
                                              )
                                            : const Text(
                                                "LOGIN",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: AppColors.white,
                                                  letterSpacing: 1,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget buildCircle(double size) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.05),
      ),
    );
  }

  Widget buildTextField({
    required TextEditingController controller,
    TextInputType? keyboardType,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      validator: validator,
      style: const TextStyle(color: AppColors.black),
      cursorColor: AppColors.black,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black54),

        prefixIcon: Icon(icon, color: Colors.black87),
        suffixIcon: suffix,

        filled: true,
        fillColor: AppColors.black.withOpacity(0.12),

        contentPadding: const EdgeInsets.symmetric(
          vertical: 18,
          horizontal: 15,
        ),

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.black87),
        ),
      ),
    );
  }
}
