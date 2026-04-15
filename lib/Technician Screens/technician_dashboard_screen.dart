import 'dart:convert';
import 'package:doc_delete/Models/get_all_manifest_model.dart';
import 'package:doc_delete/Models/user_model.dart';
import 'package:doc_delete/Screens/customer_list_screen.dart';
import 'package:doc_delete/Technician Screens/service_form_screen.dart';
import 'package:doc_delete/Screens/login_screen.dart';
import 'package:doc_delete/Technician%20Screens/manifest_list_screen.dart';
import 'package:doc_delete/Widgets/confirm_dialog.dart';
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
  List<GetAllManifestModel> manifestList = []; // Today's PENDING only
  bool isManifestLoading = false;
  UserModel? loggedUser;

  @override
  void initState() {
    super.initState();
    loadUser();
    fetchManifests();
  }

  Future<void> loadUser() async {
    final user = await SessionManager.getUser();
    if (!mounted) return;
    setState(() => loggedUser = user);
  }

  Future<void> fetchManifests() async {
    if (mounted) setState(() => isManifestLoading = true);

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

          /// 🔥 Today + PENDING only (completed = 0)
          final todayPendingList = allManifests.where((m) {
            final date = DateTime.parse(m.serviceDate);
            final isToday =
                date.year == today.year &&
                date.month == today.month &&
                date.day == today.day;
            return isToday && m.completed == 0;
          }).toList();

          if (!mounted) return;
          setState(() => manifestList = todayPendingList);
        }
      }
    } catch (e) {
      debugPrint("Manifest Error: $e");
    } finally {
      if (mounted) setState(() => isManifestLoading = false);
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
          if (list.isNotEmpty) return GetAllManifestModel.fromJson(list[0]);
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
        body: jsonEncode({"id": manifestId, "technician_id": technicianId}),
      );

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
          setState(
            () => manifestList.removeWhere((m) => m.manifestID == manifestId),
          );
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
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            /// ─── HEADER ───
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: width < 600 ? 20 : 40,
                vertical: width < 600 ? 30 : 40,
              ),
              decoration: const BoxDecoration(
                color: AppColors.darkGreen,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(35),
                  bottomRight: Radius.circular(35),
                ),
              ),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "WELCOME ${loggedUser?.name ?? "TECHNICIAN"}",
                      style: TextStyle(
                        fontSize: width < 600 ? 22 : 28,
                        color: Colors.white,
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
              ),
            ),

            const SizedBox(height: 40),

            /// ─── ACTION GRID ───
            Padding(
              padding: EdgeInsets.symmetric(horizontal: width * .05),
              child: SafeArea(
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 4,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: gridCount,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                    childAspectRatio: width < 1300 ? 1.4 : 2,
                  ),
                  itemBuilder: (context, index) {
                    final items = [
                      {"icon": Icons.add, "title": "New Service"},
                      {"icon": Icons.people, "title": "Customer List"},
                      {"icon": Icons.description, "title": "Manifest History"},
                      {"icon": Icons.power_settings_new, "title": "Logout"},
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
                              builder: (_) => const ServiceFormScreen(),
                            ),
                          );
                          if (result == true) fetchManifests();
                        }
                        if (index == 1) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CustomerListScreen(),
                            ),
                          );
                        }
                        if (index == 2) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ManifestListScreen(),
                            ),
                          );
                        }
                        if (index == 3) {
                          ConfirmDialog.show(
                            context: context,
                            title: "Logout",
                            message: "Are you sure you want to logout?",
                            icon: Icons.power_settings_new,
                            confirmText: "Logout",
                            onConfirm: logout,
                          );
                        }
                      },
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 30),

            /// ─── TODAY'S PENDING MANIFESTS ───
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
                    /// Section Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.schedule_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Today's Pending Manifests",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                "Tap a manifest to edit manifest",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white60,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    if (isManifestLoading)
                      const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    else if (manifestList.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Column(
                            children: [
                              Icon(
                                Icons.check_circle_outline_rounded,
                                size: 48,
                                color: Colors.white.withOpacity(0.4),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "No pending manifests today!",
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.white.withOpacity(0.7),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
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
                          return _dashboardManifestCard(m);
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

  Widget _dashboardManifestCard(GetAllManifestModel m) {
    return GestureDetector(
      onTap: () async {
        if (!mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ServiceFormScreen(
              isEdit: true,
              existManifest: m, // 🔥 directly pass — no fetch needed
              technicianName: m.technicianName,
            ),
          ),
        ).then((_) => fetchManifests());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.darkGreen.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: const BoxDecoration(
              border: Border(
                /// 🔥 Pending = Orange
                left: BorderSide(color: Color(0xFFE67E22), width: 6),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.customer.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D3436),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 13,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              DateFormat(
                                'MMMM d, yyyy',
                              ).format(DateTime.parse(m.serviceDate)),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        /// 🔥 Pending Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE67E22).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 11,
                                color: Color(0xFFE67E22),
                              ),
                              SizedBox(width: 4),
                              Text(
                                "Pending",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFE67E22),
                                ),
                              ),
                            ],
                          ),
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
                            confirmColor: AppColors.red,
                            onConfirm: () => deleteManifest(m.manifestID),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.red.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.delete_outline_rounded,
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
              backgroundColor: Colors.white,
              child: Icon(icon, color: AppColors.darkGreen),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
