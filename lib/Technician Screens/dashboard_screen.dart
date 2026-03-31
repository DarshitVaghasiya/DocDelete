import 'dart:convert';
import 'package:doc_delete/Models/get_all_manifest_model.dart';
import 'package:doc_delete/Models/user_model.dart';
import 'package:doc_delete/PDF/manifest_pdf.dart';
import 'package:doc_delete/Screens/customer_list_screen.dart';
import 'package:doc_delete/Technician Screens/service_form_screen.dart';
import 'package:doc_delete/Screens/login_screen.dart';
import 'package:doc_delete/Technician%20Screens/manifest_list_screen.dart';
import 'package:doc_delete/PDF/pdf_preview.dart';
import 'package:doc_delete/Widgets/confirm_dialog.dart';
import 'package:doc_delete/Widgets/custom_iconbutton.dart';
import 'package:doc_delete/config/api_urls.dart';
import 'package:doc_delete/utils/session_manager.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<GetAllManifestModel> manifestList = [];
  bool isManifestLoading = false;
  UserModel? loggedUser;
  bool isPdfLoading = false;

  @override
  void initState() {
    super.initState();
    loadUser();
    fetchManifests();
  }

  Future<void> loadUser() async {
    final user = await SessionManager.getUser();

    if (!mounted) return;

    setState(() {
      loggedUser = user;
    });
  }

  Future<void> fetchManifests() async {
    if (mounted) {
      setState(() => isManifestLoading = true);
    }

    try {
      int? techId = await SessionManager.getUserId();

      if (techId == null) return;

      final response = await http.get(
        Uri.parse("${ApiUrls.getAllManifest}?technician_id=$techId"),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        if (json["status"] == true) {
          final data = json["data"] as List;

          final allManifests = data
              .map((e) => GetAllManifestModel.fromJson(e))
              .toList();

          final today = DateTime.now();

          final todayList = allManifests.where((m) {
            final date = DateTime.parse(m.serviceDate);

            return date.year == today.year &&
                date.month == today.month &&
                date.day == today.day;
          }).toList();

          if (!mounted) return;

          setState(() {
            manifestList = todayList;
          });
        }
      }
    } catch (e) {
      debugPrint("Manifest Error: $e");
    } finally {
      if (mounted) {
        setState(() => isManifestLoading = false);
      }
    }
  }

  Future<void> logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove("user");

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<GetAllManifestModel?> getManifestById({
    required int technicianId,
    required int manifestId,
  }) async {
    final response = await http.get(
      Uri.parse(
        "${ApiUrls.getAllManifest}?technician_id=$technicianId&manifest_id=$manifestId",
      ),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data['status'] == true && data['data'] != null) {
        if (data['data'] is List) {
          final list = data['data'] as List;
          if (list.isNotEmpty) {
            return GetAllManifestModel.fromJson(list[0]);
          }
        } else if (data['data'] is Map) {
          return GetAllManifestModel.fromJson(data['data']);
        }
      }
    }

    return null;
  }

  Future<void> deleteManifest(int manifestId) async {
    int? technicianId = await SessionManager.getUserId();

    try {
      final response = await http.delete(
        Uri.parse(ApiUrls.manifest),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "id": manifestId,
          "technician_id": technicianId, // ✅ logged in user ID
        }),
      );

      print(response.body);

      final data = jsonDecode(response.body);

      if (data["status"] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Manifest deleted successfully"),
              backgroundColor: AppColors.darkGreen,
              behavior: SnackBarBehavior.floating,
            ),
          );
          setState(() {
            manifestList.removeWhere((m) => m.manifestID == manifestId);
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data["message"] ?? "Delete failed"),
              backgroundColor: AppColors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: AppColors.red),
        );
        print("Error: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    int gridCount = 2;
    if (width > 600) gridCount = 3;
    if (width > 1000) gridCount = 4;

    double iconRadius = width < 600
        ? 25
        : width < 1000
        ? 30
        : 35;

    return Scaffold(
      backgroundColor: const Color(0xffF4F7FB),
      body: isPdfLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.darkGreen),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: width < 600 ? 20 : 40,
                      vertical: width < 600 ? 30 : 40,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.darkGreen,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(35),
                        bottomRight: Radius.circular(35),
                      ),
                    ),
                    child: SafeArea(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "WELCOME ${loggedUser?.name ?? "TECHNICIAN"}",
                                style: TextStyle(
                                  fontSize: width < 600 ? 22 : 28,
                                  color: AppColors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                "Manage your service manifests easily",
                                style: TextStyle(
                                  fontSize: width < 600 ? 13 : 16,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: width * .05),
                    child: SafeArea(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: 4,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: gridCount,
                                  crossAxisSpacing: 15,
                                  mainAxisSpacing: 15,
                                  childAspectRatio: width < 1300 ? 1.4 : 2,
                                ),
                            itemBuilder: (context, index) {
                              final items = [
                                {"icon": Icons.add, "title": "New Service"},
                                {
                                  "icon": Icons.people,
                                  "title": "Customer List",
                                },
                                {
                                  "icon": Icons.description,
                                  "title": "Manifest History",
                                },
                                {
                                  "icon": Icons.power_settings_new,
                                  "title": "Logout",
                                },
                              ];

                              return _actionCard(
                                items[index]["icon"] as IconData,
                                items[index]["title"] as String,
                                iconRadius,
                                () async {
                                  if (index == 0) {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const ServiceFormScreen(),
                                      ),
                                    );

                                    if (result == true) {
                                      fetchManifests();
                                    }
                                  }

                                  if (index == 1) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const CustomerListScreen(),
                                      ),
                                    );
                                  }

                                  if (index == 2) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const ManifestListScreen(),
                                      ),
                                    );
                                  }

                                  if (index == 3) {
                                    ConfirmDialog.show(
                                      context: context,
                                      title: "Logout",
                                      message:
                                          "Are you sure you want to logout?",
                                      icon: Icons.power_settings_new,
                                      confirmText: "Logout",
                                      onConfirm: logout,
                                    );
                                  }
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: width * .05),
                    child: Container(
                      padding: EdgeInsets.all(width < 600 ? 15 : 25),
                      decoration: BoxDecoration(
                        color: AppColors.darkGreen,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 10,
                            color: Colors.grey.withOpacity(.1),
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Today's Manifests",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          if (isManifestLoading)
                            const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.white,
                              ),
                            )
                          else if (manifestList.isEmpty)
                            Center(
                              child: Text(
                                "No manifests available",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AppColors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: manifestList.length,

                              itemBuilder: (context, index) {
                                final m = manifestList[index];

                                return GestureDetector(
                                  onTap: () async {
                                    if (isPdfLoading) return;

                                    setState(() => isPdfLoading = true);

                                    final navigator = Navigator.of(context);
                                    int? technicianId =
                                        await SessionManager.getUserId();
                                    if (technicianId == null) {
                                      setState(() => isPdfLoading = false);
                                      return;
                                    }

                                    try {
                                      final manifest = await getManifestById(
                                        technicianId: technicianId,
                                        manifestId: m.manifestID,
                                      );

                                      if (manifest == null) return;

                                      final bytes = await generateManifestPdf(
                                        manifest,
                                        technicianName: m.technicianName,
                                      );

                                      if (!mounted) return;
                                      navigator.push(
                                        MaterialPageRoute(
                                          builder: (_) => WebPdfViewerScreen(
                                            bytes: bytes,
                                            customerEmail: m.customer.email,
                                          ),
                                        ),
                                      );
                                    } catch (e) {
                                      debugPrint("PDF Error: $e");
                                    } finally {
                                      if (mounted) {
                                        setState(() => isPdfLoading = false);
                                      }
                                    }
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: AppColors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.darkGreen
                                              .withOpacity(0.06),
                                          blurRadius: 20,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 10,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          m.customer.name,
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 15,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: Color(
                                                                  0xFF2D3436,
                                                                ),
                                                              ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 12),
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons
                                                            .calendar_today_outlined,
                                                        size: 14,
                                                        color: Colors
                                                            .grey
                                                            .shade600,
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        DateFormat(
                                                          'MMMM d, yyyy',
                                                        ).format(
                                                          DateTime.parse(
                                                            m.serviceDate,
                                                          ),
                                                        ),
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          color: Colors
                                                              .grey
                                                              .shade600,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Column(
                                              children: [
                                                Text(
                                                  "#${m.manifestNo}",
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.darkGreen,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                GestureDetector(
                                                  onTap: () {
                                                    ConfirmDialog.show(
                                                      context: context,
                                                      title: "Delete Manifest",
                                                      message:
                                                          "Are you sure you want to delete ${m.manifestNo}?",
                                                      confirmText: "Delete",
                                                      confirmColor:
                                                          AppColors.red,
                                                      onConfirm: () =>
                                                          deleteManifest(
                                                            m.manifestID,
                                                          ),
                                                    );
                                                  },
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(6),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.red
                                                          .withOpacity(0.08),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                    child: const Icon(
                                                      Icons
                                                          .delete_outline_rounded,
                                                      size: 22,
                                                      color: AppColors.red,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _actionCard(
    IconData icon,
    String title,
    double radius,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppColors.darkGreen,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: radius,
              backgroundColor: AppColors.white,
              child: Icon(icon, color: AppColors.darkGreen),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
