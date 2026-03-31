import 'package:doc_delete/Admin%20Screens/all_manifest_list_screen.dart';
import 'package:doc_delete/Admin%20Screens/technician_list_screen.dart';
import 'package:doc_delete/Models/user_model.dart';
import 'package:doc_delete/Screens/customer_list_screen.dart';
import 'package:doc_delete/Screens/login_screen.dart';
import 'package:doc_delete/Widgets/confirm_dialog.dart';
import 'package:doc_delete/Widgets/custom_iconbutton.dart';
import 'package:doc_delete/utils/session_manager.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  UserModel? loggedUser;

  @override
  void initState() {
    super.initState();
    loadUser();
  }

  Future<void> loadUser() async {
    final user = await SessionManager.getUser();

    setState(() {
      loggedUser = user;
    });
  }

  Future<void> logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove("user");
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    /// RESPONSIVE GRID
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
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
                    /// TEXT SECTION
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "WELCOME ${loggedUser?.name ?? "ADMIN"}",
                          style: TextStyle(
                            fontSize: width < 600 ? 22 : 28,
                            color: AppColors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 5),

                        Text(
                          "Manage your customer and technician easily",
                          style: TextStyle(
                            fontSize: width < 600 ? 13 : 16,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),

                    /// LOGOUT BUTTON
                    CircleAvatar(
                      backgroundColor: AppColors.white,
                      radius: 30,
                      child: CustomIconButton(
                        icon: Icons.power_settings_new,
                        textColor: AppColors.red,
                        onTap: () {
                          ConfirmDialog.show(
                            context: context,
                            title: "Logout",
                            message: "Are you sure you want to logout?",
                            icon: Icons.power_settings_new,
                            confirmText: "Logout",
                            onConfirm: logout,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),

            /// BUTTONS
            Padding(
              padding: EdgeInsets.symmetric(horizontal: width * .05),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 3,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: gridCount,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  childAspectRatio: width < 1300 ? 1.2 : 1.8,
                ),

                itemBuilder: (context, index) {
                  final items = [
                    {"icon": Icons.person, "title": "Technician List"},
                    {"icon": Icons.people, "title": "Customer List"},
                    // {"icon": Icons.local_shipping, "title": "Transporter List"},
                    {"icon": Icons.description, "title": "Manifest List"},
                  ];

                  return _actionCard(
                    items[index]["icon"] as IconData,
                    items[index]["title"] as String,
                    iconRadius,
                    () {
                      if (index == 0) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TechnicianListScreen(),
                          ),
                        );
                      }

                      if (index == 1) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CustomerListScreen(),
                          ),
                        );
                      }

                      /*     if (index == 2) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TransporterListScreen(),
                          ),
                        );
                      }
*/
                      if (index == 2) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AllManifestListScreen(),
                          ),
                        );
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// DASHBOARD CARD
  Widget dashboardCard(
    String title,
    String value,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  title,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),

            Icon(icon, color: AppColors.white, size: 32),
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
              style: TextStyle(
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
