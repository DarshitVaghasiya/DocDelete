import 'dart:convert';

import 'package:doc_delete/Models/customer_model.dart';
import 'package:doc_delete/Models/get_all_manifest_model.dart';
import 'package:doc_delete/Models/user_model.dart';
import 'package:doc_delete/PDF/manifest_pdf.dart';
import 'package:doc_delete/PDF/pdf_preview.dart';
import 'package:doc_delete/Technician%20Screens/service_form_screen.dart';
import 'package:doc_delete/Widgets/confirm_dialog.dart';
import 'package:doc_delete/Widgets/custom_appbar.dart';
import 'package:doc_delete/Widgets/custom_refresh.dart';
import 'package:doc_delete/config/api_urls.dart';
import 'package:doc_delete/utils/session_manager.dart';
import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

class AllManifestListScreen extends StatefulWidget {
  const AllManifestListScreen({super.key});

  @override
  State<AllManifestListScreen> createState() => _AllManifestListScreenState();
}

class _AllManifestListScreenState extends State<AllManifestListScreen> {
  List<GetAllManifestModel> manifestList = [];
  List<GetAllManifestModel> filteredList = [];
  bool isManifestLoading = false;
  List<UserModel> technicians = [];
  int? selectedTechnicianId;
  List<CustomerModel> customers = [];
  int? selectedCustomerId;

  /// 🔥 SEGMENT FILTER
  String selectedFilter = "pending"; // "pending" | "completed"

  @override
  void initState() {
    super.initState();
    fetchTechnicians();
    fetchCustomers();
    fetchAllManifests();
  }

  void _applyFilter() {
    if (selectedFilter == "pending") {
      filteredList = manifestList.where((m) => m.completed == 0).toList();
    } else if (selectedFilter == "completed") {
      filteredList = manifestList.where((m) => m.completed == 1).toList();
    } else {
      filteredList = List.from(manifestList);
    }
    setState(() {});
  }

  Future<void> fetchAllManifests() async {
    setState(() => isManifestLoading = true);

    try {
      int? adminID = await SessionManager.getUserId();
      String url = "${ApiUrls.getAllManifest}?is_admin=$adminID";

      if (selectedTechnicianId != null) {
        url += "&technician_id=$selectedTechnicianId";
      }
      if (selectedCustomerId != null) url += "&customer_id=$selectedCustomerId";

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        if (json["status"] == true) {
          final data = json["data"] as List;
          final list = data
              .map((e) => GetAllManifestModel.fromJson(e))
              .toList();

          list.sort(
            (a, b) => DateTime.parse(
              b.serviceDate,
            ).compareTo(DateTime.parse(a.serviceDate)),
          );

          manifestList = list;
          _applyFilter(); // 🔥 filter apply
        }
      }
    } catch (e) {
      print("Manifest Error: $e");
    } finally {
      setState(() => isManifestLoading = false);
    }
  }

  Future<void> fetchTechnicians() async {
    try {
      final res = await http.get(Uri.parse(ApiUrls.technician));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (json["status"] == true) {
          final data = json["data"];

          // ✅ data List છે કે Map — બંને handle કરો
          final List rawList = data is List
              ? data
              : (data["users"] as List? ?? []);

          setState(() {
            technicians = rawList.map((e) => UserModel.fromJson(e)).toList();
            technicians.sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );
          });
        }
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> fetchCustomers() async {
    try {
      final res = await http.get(Uri.parse(ApiUrls.customer));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (json["status"] == true) {
          final data = json["data"];

          // ✅ data List છે કે Map — બંને handle કરો
          final List rawList = data is List
              ? data
              : (data["customers"] as List? ?? []);

          setState(() {
            customers = rawList.map((e) => CustomerModel.fromJson(e)).toList();
            customers.sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );
          });
        }
      }
    } catch (e) {
      print("Customer Error: $e");
    }
  }

  Map<String, List<GetAllManifestModel>> groupByDate(
    List<GetAllManifestModel> list,
  ) {
    Map<String, List<GetAllManifestModel>> grouped = {};
    for (var m in list) {
      if (!grouped.containsKey(m.serviceDate)) grouped[m.serviceDate] = [];
      grouped[m.serviceDate]!.add(m);
    }
    return grouped;
  }

  Future<GetAllManifestModel?> getManifestById({
    required int manifestId,
  }) async {
    int? adminID = await SessionManager.getUserId();
    final response = await http.get(
      Uri.parse(
        "${ApiUrls.getAllManifest}?is_admin=$adminID&manifest_id=$manifestId",
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
    int? userID = await SessionManager.getUserId();
    try {
      final response = await http.delete(
        Uri.parse(ApiUrls.manifest),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "id": manifestId,
          "technician_id": userID,
          "is_admin": userID,
        }),
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
          manifestList.removeWhere((m) => m.manifestID == manifestId);
          _applyFilter();
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

  /// 🔥 COUNTS
  int get pendingCount => manifestList.where((m) => m.completed == 0).length;
  int get completedCount => manifestList.where((m) => m.completed == 1).length;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final groupedData = groupByDate(filteredList);
    final dates = groupedData.keys.toList();

    return Scaffold(
      backgroundColor: const Color(0xffF4F7FB),
      appBar: CustomAppBar(title: "Manifests List"),
      body: isManifestLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.darkGreen),
            )
          : Padding(
              padding: EdgeInsets.symmetric(horizontal: width * .05),
              child: Column(
                children: [
                  SizedBox(height: width * .03),

                  /// 🔒 FIXED — Segment Buttons (scroll નહીં થાય)
                  _segmentButtons(),

                  const SizedBox(height: 14),

                  /// 🔥 SCROLLABLE — બાકી બધું
                  Expanded(
                    child: CustomRefresh(
                      onRefresh: fetchAllManifests,
                      child: CustomScrollView(
                        slivers: [
                          /// ─── TECHNICIAN DROPDOWN ───
                          SliverToBoxAdapter(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  key: ValueKey(selectedTechnicianId),
                                  value: selectedTechnicianId,
                                  dropdownColor: Colors.white,
                                  isExpanded: true,
                                  items: [
                                    const DropdownMenuItem<int>(
                                      value: null,
                                      child: Text("All Technician"),
                                    ),
                                    ...technicians.map<DropdownMenuItem<int>>((
                                      tech,
                                    ) {
                                      return DropdownMenuItem<int>(
                                        value: tech.id,
                                        child: Text(tech.name),
                                      );
                                    }),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      selectedTechnicianId = value;
                                      selectedCustomerId = null;
                                    });
                                    fetchAllManifests();
                                  },
                                ),
                              ),
                            ),
                          ),

                          const SliverToBoxAdapter(
                            child: Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 6),
                                child: Text(
                                  "OR",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ),

                          /// ─── CUSTOMER DROPDOWN ───
                          SliverToBoxAdapter(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int?>(
                                  key: ValueKey(selectedCustomerId),
                                  value: selectedCustomerId,
                                  dropdownColor: AppColors.white,
                                  isExpanded: true,
                                  items: [
                                    const DropdownMenuItem<int?>(
                                      value: null,
                                      child: Text("All Customers"),
                                    ),
                                    ...customers.map<DropdownMenuItem<int?>>((
                                      c,
                                    ) {
                                      return DropdownMenuItem<int?>(
                                        value: c.id,
                                        child: Text(c.name),
                                      );
                                    }),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      selectedCustomerId = value;
                                      selectedTechnicianId = null;
                                    });
                                    fetchAllManifests();
                                  },
                                ),
                              ),
                            ),
                          ),

                          /// ─── HEADER ───
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Text(
                                "Total Manifests (${filteredList.length})",
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),

                          /// ─── EMPTY STATE ───
                          if (filteredList.isEmpty)
                            SliverFillRemaining(
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.description_outlined,
                                      size: 60,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      "No manifests available",
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            /// ─── GROUPED LIST ───
                            SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final dates = groupByDate(
                                    filteredList,
                                  ).keys.toList();
                                  final groupedData = groupByDate(filteredList);
                                  final date = dates[index];
                                  final manifests = groupedData[date]!;

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        child: Text(
                                          DateFormat(
                                            'MMMM d, yyyy',
                                          ).format(DateTime.parse(date)),
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                      ...manifests.map(
                                        (m) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 10,
                                          ),
                                          child: _manifestCard(m),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                                childCount: groupByDate(
                                  filteredList,
                                ).keys.length,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  /// 🔥 SEGMENT BUTTONS WIDGET
  Widget _segmentButtons() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _segmentItem(
            label: "Pending",
            value: "pending",
            activeColor: const Color(0xFFE67E22), // Orange
          ),
          _segmentItem(
            label: "Completed",
            value: "completed",
            activeColor: AppColors.darkGreen,
          ),
        ],
      ),
    );
  }

  Widget _segmentItem({
    required String label,
    required String value,
    required Color activeColor,
  }) {
    final bool isActive = selectedFilter == value;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => selectedFilter = value);
          _applyFilter();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: activeColor.withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [],
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isActive ? Colors.white : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _manifestCard(GetAllManifestModel m) {
    final bool isCompleted = m.completed == 1;

    return GestureDetector(
      onTap: () async {
        if (m.completed == 1) {
          // ✅ Completed — PDF generate માટે full data જોઈએ, loader okay
          setState(() => isManifestLoading = true);
          try {
            final manifest = await getManifestById(manifestId: m.manifestID);
            if (manifest == null) {
              setState(() => isManifestLoading = false);
              return;
            }
            final bytes = await generateManifestPdf(
              manifest,
              technicianName: m.technicianName,
            );
            setState(() => isManifestLoading = false);
            if (!mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => WebPdfViewerScreen(
                  bytes: bytes,
                  customerEmail: m.customer.email,
                ),
              ),
            );
          } catch (e) {
            setState(() => isManifestLoading = false);
          }
        } else {
          // ✅ Pending — 'm' already available, NO loader, NO extra fetch
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ServiceFormScreen(
                isEdit: true,
                existManifest: m, // 🔥 directly pass
                technicianName: m.technicianName,
              ),
            ),
          ).then((_) => fetchAllManifests());
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 5),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isCompleted
                ? AppColors.darkGreen.withOpacity(0.5)
                : AppColors.orange.withOpacity(0.5),
          ),
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
            decoration: BoxDecoration(
              border: Border(
                /// 🔥 Pending = orange, Completed = green
                left: BorderSide(
                  color: isCompleted
                      ? AppColors.darkGreen
                      : const Color(0xFFE67E22),
                  width: 6,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              DateFormat(
                                'MMMM d, yyyy',
                              ).format(DateTime.parse(m.serviceDate)),
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        /// 🔥 Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? AppColors.darkGreen.withOpacity(0.1)
                                : const Color(0xFFE67E22).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isCompleted
                                    ? Icons.check_circle_rounded
                                    : Icons.schedule_rounded,
                                size: 11,
                                color: isCompleted
                                    ? AppColors.darkGreen
                                    : const Color(0xFFE67E22),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isCompleted ? "Completed" : "Pending",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isCompleted
                                      ? AppColors.darkGreen
                                      : const Color(0xFFE67E22),
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
                      if (!isCompleted) ...[
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
}
