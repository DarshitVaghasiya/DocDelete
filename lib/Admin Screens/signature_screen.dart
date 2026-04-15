import 'dart:convert';
import 'package:doc_delete/Models/user_model.dart';
import 'package:doc_delete/Widgets/custom_appbar.dart';
import 'package:doc_delete/config/api_urls.dart';
import 'package:doc_delete/utils/session_manager.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:signature/signature.dart';

class SignatureScreen extends StatefulWidget {
  const SignatureScreen({super.key});

  @override
  State<SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends State<SignatureScreen> {
  SignatureController adminController = SignatureController(penStrokeWidth: 3);
  String? adminSignBase64;
  UserModel? loggedUser;

  @override
  void initState() {
    super.initState();
    loadUser();
    loadSignature(); // ✅ correct place
  }

  @override
  void dispose() {
    adminController.dispose();
    super.dispose();
  }

  Future<void> loadUser() async {
    final user = await SessionManager.getUser();
    if (!mounted) return;
    setState(() => loggedUser = user);
  }

  Future<void> loadSignature() async {
    try {
      final userId = await SessionManager.getUserId();

      final response = await http.get(Uri.parse("${ApiUrls.users}?id=$userId"));

      final result = jsonDecode(response.body);

      if (result["status"] == true) {
        final user = result["data"][0];

        if (user["admin_sign"] != null) {
          setState(() {
            adminSignBase64 = user["admin_sign"].split(',').last;
          });
        }
      }
    } catch (e) {
      print("Load Error: $e");
    }
  }

  Future<void> saveSignature() async {
    if (adminController.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please sign first")));
      return;
    }

    final bytes = await adminController.toPngBytes();
    if (bytes == null) return;

    final base64Sign = base64Encode(bytes);

    setState(() => adminSignBase64 = base64Sign);

    try {
      final userId = await SessionManager.getUserId();

      final response = await http.put(
        Uri.parse(ApiUrls.users),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"id": userId, "admin_sign": base64Sign}),
      );

      final result = jsonDecode(response.body);

      if (result["status"] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Signature uploaded successfully"),
            backgroundColor: AppColors.darkGreen,
          ),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result["message"] ?? "Error")));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
      print("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CustomAppBar(title: "Admin Signature"),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// ── SIGNATURE PAD ──
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// Header
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.draw_outlined,
                              size: 18,
                              color: AppColors.darkGreen,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "${loggedUser?.name ?? "Admin"} Signature",
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            if (adminSignBase64 != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.darkGreen.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      size: 12,
                                      color: AppColors.darkGreen,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "Signed",
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.darkGreen,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),

                      const Divider(height: 1),

                      /// Draw Area
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(16),
                            ),
                            child: adminSignBase64 == null
                                ? Signature(
                                    controller: adminController,
                                    height: 200,
                                    backgroundColor: Colors.grey.shade50,
                                  )
                                : Container(
                                    height: 200,
                                    width: double.infinity,
                                    color: Colors.grey.shade50,
                                    alignment: Alignment.center,
                                    child: Image.memory(
                                      base64Decode(adminSignBase64!),
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                          ),

                          /// Placeholder (ONLY when no sign AND pad empty)
                          if (adminSignBase64 == null &&
                              adminController.isEmpty)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: Center(
                                  child: Text(
                                    "Sign here",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          /// Clear Button
                          Positioned(
                            bottom: 10,
                            right: 10,
                            child: GestureDetector(
                              onTap: () {
                                adminController.clear();
                                setState(() {
                                  adminSignBase64 = null;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.red.withOpacity(0.3),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.clear_rounded,
                                      size: 13,
                                      color: AppColors.red,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "Clear",
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.red,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                /// ── SAVE BUTTON ──
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: saveSignature,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.darkGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Save Signature",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
