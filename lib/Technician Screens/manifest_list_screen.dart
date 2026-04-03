import 'dart:convert';
import 'package:doc_delete/Models/get_all_manifest_model.dart';
import 'package:doc_delete/Models/user_model.dart';
import 'package:doc_delete/PDF/manifest_pdf.dart';
import 'package:doc_delete/PDF/pdf_preview.dart';
import 'package:doc_delete/Widgets/confirm_dialog.dart';
import 'package:doc_delete/Widgets/custom_appbar.dart';
import 'package:doc_delete/config/api_urls.dart';
import 'package:doc_delete/utils/session_manager.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

import 'service_form_screen.dart';

class ManifestListScreen extends StatefulWidget {
  const ManifestListScreen({super.key});

  @override
  State<ManifestListScreen> createState() => _ManifestListScreenState();
}

class _ManifestListScreenState extends State<ManifestListScreen> {
  List<GetAllManifestModel> manifestList = [];
  List<GetAllManifestModel> filteredList = [];
  bool isManifestLoading = false;
  bool isPdfLoading = false;
  UserModel? loggedUser;

  /// 🔥 SEGMENT FILTER
  String selectedFilter = "pending"; // "pending" | "completed"

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

  Future<void> fetchManifests() async {
    if (!mounted) return;
    try {
      setState(() {
        isManifestLoading = true;
      });
      int? techId = await SessionManager.getUserId();
      if (techId == null) return;

      final response = await http.get(
        Uri.parse("${ApiUrls.getAllManifest}?technician_id=$techId"),
      );

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

          if (!mounted) return;
          manifestList = list;
          _applyFilter();
        }
      }
      setState(() {
        isManifestLoading = false;
      });
    } catch (e) {
      debugPrint("Manifest Error: $e");
    }
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
      appBar: CustomAppBar(title: "Manifest List"),
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: width * .05,
              vertical: width * .03,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// 🔥 SEGMENT BUTTONS
                _segmentButtons(),

                const SizedBox(height: 14),

                Text(
                  "Total Manifests (${filteredList.length})",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.darkGreen,
                    onRefresh: fetchManifests, // 🔥 your API call
                    child: isManifestLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.darkGreen,
                            ),
                          )
                        : filteredList.isEmpty
                        ? ListView(
                            // ⚠️ important: must be scrollable
                            children: [
                              SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.5,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.description_outlined,
                                      size: 60,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      "No manifests available",
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            physics:
                                const AlwaysScrollableScrollPhysics(), // 🔥 important
                            itemCount: dates.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final date = dates[index];
                              final manifests = groupedData[date]!;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                          ),
                  ),
                ),
              ],
            ),
          ),

          /// PDF Loading Overlay
          if (isPdfLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.darkGreen),
              ),
            ),
        ],
      ),
    );
  }

  /// 🔥 SEGMENT BUTTONS
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
            //  count: pendingCount,
            value: "pending",
            activeColor: const Color(0xFFE67E22),
          ),
          _segmentItem(
            label: "Completed",
            // count: completedCount,
            value: "completed",
            activeColor: AppColors.darkGreen,
          ),
        ],
      ),
    );
  }

  Widget _segmentItem({
    required String label,
    //  required int count,
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
        if (isCompleted) {
          // ✅ Completed — PDF generate માટે full data જોઈએ, loader okay
          setState(() => isPdfLoading = true);

          int? technicianId = await SessionManager.getUserId();
          if (technicianId == null) {
            setState(() => isPdfLoading = false);
            return;
          }

          try {
            final manifest = await getManifestById(
              technicianId: technicianId,
              manifestId: m.manifestID,
            );

            if (manifest == null) {
              setState(() => isPdfLoading = false);
              return;
            }

            final bytes = await generateManifestPdf(
              manifest,
              technicianName: m.technicianName,
            );

            if (!mounted) return;
            setState(() => isPdfLoading = false);

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
            debugPrint("PDF Error: $e");
            if (mounted) setState(() => isPdfLoading = false);
          }
        } else {
          // ✅ Pending — 'm' directly pass, NO loader, NO fetch
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
          ).then((_) => fetchManifests());
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
                /// 🔥 Pending = Orange, Completed = Green
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

                        /// 🔥 Status Badge
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
