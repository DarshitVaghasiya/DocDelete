import 'dart:convert';

import 'package:doc_delete/Admin Screens/all_manifest_list_screen.dart';
import 'package:doc_delete/Admin Screens/technician_list_screen.dart';
import 'package:doc_delete/Admin%20Screens/add_technician_screen.dart';
import 'package:doc_delete/Admin%20Screens/signature_screen.dart';
import 'package:doc_delete/Models/customer_model.dart';
import 'package:doc_delete/Models/technician_model.dart';
import 'package:doc_delete/Models/user_model.dart';
import 'package:doc_delete/Screens/add_customer_screen.dart';
import 'package:doc_delete/Screens/customer_list_screen.dart';
import 'package:doc_delete/Screens/login_screen.dart';
import 'package:doc_delete/Widgets/confirm_dialog.dart';
import 'package:doc_delete/config/api_urls.dart';
import 'package:doc_delete/utils/session_manager.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

enum Admin {
  dashboard,
  technicians,
  customers,
  manifests,
  signature,
  addTechnician,
  editTechnician,
  addCustomer,
  editCustomer,
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  Admin selectedPage = Admin.dashboard;
  TechnicianModel? currentEditingTechnician;
  CustomerModel? currentEditingCustomer;
  UserModel? loggedUser;
  int customerCount = 0;
  int technicianCount = 0;
  int manifestCount = 0;
  bool isLoading = false;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // ✅ Single breakpoint used everywhere
  static const double _mobileBreakpoint = 600;

  @override
  void initState() {
    super.initState();
    loadUser();
    loadDashboardData();
  }

  void showLoader() => setState(() => isLoading = true);
  void hideLoader() => setState(() => isLoading = false);

  Future<void> loadUser() async {
    final user = await SessionManager.getUser();
    setState(() => loggedUser = user);
  }

  Future<void> loadDashboardData() async {
    showLoader();
    await Future.wait([
      fetchTechnicianCount(),
      fetchCustomerCount(),
      fetchManifestCount(),
    ]);
    hideLoader();
  }

  Future<void> fetchTechnicianCount() async {
    try {
      final response = await http.get(Uri.parse(ApiUrls.technician));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => technicianCount = data["data"].length);
      }
    } catch (e) {
      debugPrint("Error fetching technicians: $e");
    }
  }

  Future<void> fetchCustomerCount() async {
    try {
      final response = await http.get(Uri.parse(ApiUrls.customer));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => customerCount = data["data"].length);
      }
    } catch (e) {
      debugPrint("Error fetching customers: $e");
    }
  }

  Future<void> fetchManifestCount() async {
    try {
      int? adminID = await SessionManager.getUserId();
      final response = await http.get(
        Uri.parse("${ApiUrls.getAllManifest}?is_admin=$adminID"),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          manifestCount = (data["status"] == true && data["data"] != null)
              ? (data["data"] as List).length
              : 0;
        });
      }
    } catch (e) {
      debugPrint("Error fetching manifests: $e");
    }
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

  void _navigateTo(Admin page) {
    setState(() => selectedPage = page);
    final width = MediaQuery.of(context).size.width;
    if (width < _mobileBreakpoint) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < _mobileBreakpoint;

    if (isMobile) {
      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color(0xffF4F7FB),
        drawer: Drawer(
          backgroundColor: AppColors.darkGreen,
          child: SafeArea(child: _sidebarContent(240)),
        ),
        body: Column(
          children: [
            if (selectedPage == Admin.dashboard) _mobileHeader(),
            Expanded(
              child: isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: AppColors.darkGreen,
                      ),
                    )
                  : _getScreen(),
            ),
          ],
        ),
      );
    } else {
      final double sidebarWidth = width > 1400
          ? 280
          : (width > 1000 ? 240 : 200);

      return Scaffold(
        backgroundColor: const Color(0xffF4F7FB),
        body: Row(
          children: [
            Container(
              width: sidebarWidth,
              color: AppColors.darkGreen,
              child: SafeArea(child: _sidebarContent(sidebarWidth)),
            ),
            Expanded(
              child: Column(
                children: [
                  if (selectedPage == Admin.dashboard) _laptopHeader(width),
                  Expanded(
                    child: isLoading
                        ? Center(
                            child: CircularProgressIndicator(
                              color: AppColors.darkGreen,
                            ),
                          )
                        : _getScreen(),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  // ─── MOBILE HEADER ────────────────────────────────────────────────────────
  Widget _mobileHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      decoration: const BoxDecoration(
        color: AppColors.darkGreen,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(25),
          bottomRight: Radius.circular(25),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            InkWell(
              onTap: () => _scaffoldKey.currentState?.openDrawer(),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.menu, color: Colors.white),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "WELCOME ${loggedUser?.name ?? "ADMIN"}",
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    "Manage your system easily",
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── LAPTOP HEADER ────────────────────────────────────────────────────────
  Widget _laptopHeader(double width) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: width < 900 ? 20 : 40,
        vertical: width < 900 ? 45 : 50,
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
              "WELCOME ${loggedUser?.name ?? "ADMIN"}",
              overflow: TextOverflow.clip,
              style: TextStyle(
                fontSize: width < 900 ? 20 : 28,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              "Manage your system easily",
              style: TextStyle(
                fontSize: width < 900 ? 12 : 16,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── SHARED SIDEBAR CONTENT ───────────────────────────────────────────────
  Widget _sidebarContent(double sidebarWidth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),
                Text(
                  "DocDelete",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: sidebarWidth < 220 ? 16 : 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                _sideItem(
                  Icons.dashboard,
                  "Dashboard",
                  () => _navigateTo(Admin.dashboard),
                  selectedPage == Admin.dashboard,
                ),
                _sideItem(
                  Icons.person,
                  "Technicians",
                  () => _navigateTo(Admin.technicians),
                  selectedPage == Admin.technicians ||
                      selectedPage == Admin.addTechnician ||
                      selectedPage == Admin.editTechnician,
                ),
                _sideItem(
                  Icons.people,
                  "Customers",
                  () => _navigateTo(Admin.customers),
                  selectedPage == Admin.customers ||
                      selectedPage == Admin.addCustomer ||
                      selectedPage == Admin.editCustomer,
                ),
                _sideItem(
                  Icons.description,
                  "Manifests",
                  () => _navigateTo(Admin.manifests),
                  selectedPage == Admin.manifests,
                ),
                _sideItem(
                  Icons.draw_outlined,
                  "Admin Signature",
                  () => _navigateTo(Admin.signature),
                  selectedPage == Admin.signature,
                ),
              ],
            ),
          ),
        ),
        const Divider(color: Colors.white24),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loggedUser?.name ?? "",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Admin",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
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
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    "Logout",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sideItem(
    IconData icon,
    String title,
    VoidCallback onTap,
    bool isSelected,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          margin: const EdgeInsets.only(bottom: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: isSelected
                ? Colors.white.withOpacity(0.2)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  // ─── SCREEN ROUTER ────────────────────────────────────────────────────────
  Widget _getScreen() {
    switch (selectedPage) {
      case Admin.dashboard:
        return _dashboardContent(MediaQuery.of(context).size.width);
      case Admin.technicians:
        return TechnicianListScreen(
          onAddPressed: () =>
              setState(() => selectedPage = Admin.addTechnician),
          onEditPressed: (tech) => setState(() {
            currentEditingTechnician = tech;
            selectedPage = Admin.editTechnician;
          }),
        );
      case Admin.addTechnician:
        return AddTechnicianScreen(
          onSaved: () => setState(() => selectedPage = Admin.technicians),
        );
      case Admin.editTechnician:
        return AddTechnicianScreen(
          technician: currentEditingTechnician,
          onSaved: () => setState(() => selectedPage = Admin.technicians),
        );
      case Admin.customers:
        return CustomerListScreen(
          onAddPressed: () => setState(() => selectedPage = Admin.addCustomer),
          onEditPressed: (customer) => setState(() {
            currentEditingCustomer = customer;
            selectedPage = Admin.editCustomer;
          }),
        );
      case Admin.addCustomer:
        return AddCustomerScreen(
          onSaved: () => setState(() => selectedPage = Admin.customers),
        );
      case Admin.editCustomer:
        return AddCustomerScreen(
          customer: currentEditingCustomer,
          onSaved: () => setState(() => selectedPage = Admin.customers),
        );
      case Admin.manifests:
        return AllManifestListScreen();
      case Admin.signature:
        return SignatureScreen();
    }
  }

  // ─── DASHBOARD GRID ───────────────────────────────────────────────────────
  Widget _dashboardContent(double width) {
    final isMobile = width < _mobileBreakpoint; // ✅ consistent breakpoint

    // Mobile & tablet → 2 columns | Large screen (>1300) → 3 columns
    final int crossAxisCount = width > 1200 ? 3 : 2;

    // Aspect ratio: taller cards on mobile, wider on laptop
    final double aspectRatio = isMobile ? 1.4 : (width > 1300 ? 2.0 : 1.4);

    final items = [
      {
        "title": "Technicians",
        "value": technicianCount.toString(),
        "icon": Icons.person,
        "color": Colors.blue,
      },
      {
        "title": "Customers",
        "value": customerCount.toString(),
        "icon": Icons.people,
        "color": Colors.orange,
      },
      {
        "title": "Manifests",
        "value": manifestCount.toString(),
        "icon": Icons.description,
        "color": Colors.green,
      },
    ];

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : (width < 900 ? 20 : 40),
        vertical: isMobile ? 20 : 30,
      ),
      child: GridView.builder(
        itemCount: items.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: aspectRatio,
        ),
        itemBuilder: (context, index) {
          final item = items[index];
          return _dashboardCard(
            title: item["title"] as String,
            value: item["value"] as String,
            icon: item["icon"] as IconData,
            color: item["color"] as Color,
          );
        },
      ),
    );
  }

  Widget _dashboardCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.9), color.withOpacity(0.6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
