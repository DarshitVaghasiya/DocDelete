import 'dart:convert';
import 'package:doc_delete/Models/get_all_manifest_model.dart';
import 'package:doc_delete/Models/user_model.dart';
import 'package:doc_delete/PDF/manifest_pdf.dart';
import 'package:doc_delete/PDF/pdf_preview.dart';
import 'package:doc_delete/Widgets/confirm_dialog.dart';
import 'package:doc_delete/Widgets/custom_appbar.dart';
import 'package:doc_delete/config/api_urls.dart';
import 'package:doc_delete/utils/session_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class ManifestListScreen extends StatefulWidget {
  const ManifestListScreen({super.key});

  @override
  State<ManifestListScreen> createState() => _ManifestListScreenState();
}

class _ManifestListScreenState extends State<ManifestListScreen> {
  List<GetAllManifestModel> manifestList = [];
  bool isManifestLoading = false;
  bool isPdfLoading = false;
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
    setState(() {
      loggedUser = user;
    });
  }

  Future<void> fetchManifests() async {
    if (!mounted) return;
    setState(() => isManifestLoading = true);

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

          final list = data
              .map((e) => GetAllManifestModel.fromJson(e))
              .toList();

          list.sort(
            (a, b) => DateTime.parse(
              b.serviceDate,
            ).compareTo(DateTime.parse(a.serviceDate)),
          );

          if (!mounted) return;
          setState(() {
            manifestList = list;
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

  Map<String, List<GetAllManifestModel>> groupByDate() {
    Map<String, List<GetAllManifestModel>> grouped = {};

    for (var m in manifestList) {
      String date = m.serviceDate; // yyyy-mm-dd

      if (!grouped.containsKey(date)) {
        grouped[date] = [];
      }

      grouped[date]!.add(m);
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final groupedData = groupByDate();
    final dates = groupedData.keys.toList();
    return Scaffold(
      backgroundColor: const Color(0xffF4F7FB),
      appBar: CustomAppBar(title: "Manifest List"),
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: width * .05,
              vertical: 20,
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      "All Manifests",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: isManifestLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.darkGreen,
                          ),
                        )
                      : manifestList.isEmpty
                      ? Center(
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
                        )
                      : ListView.separated(
                          itemCount: dates.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final date = dates[index];
                            final manifests = groupedData[date]!;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                /// 🔥 DATE HEADER
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    date,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),

                                /// 🔥 LIST FOR THAT DATE
                                ...manifests.map(
                                  (m) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _manifestCard(m),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
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

  Widget _manifestCard(GetAllManifestModel m) {
    return GestureDetector(
      onTap: () async {
        if (isPdfLoading) return;

        setState(() => isPdfLoading = true);

        final navigator = Navigator.of(context);
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
          if (mounted) setState(() => isPdfLoading = false);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 5),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.darkGreen.withOpacity(0.2)),
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
                left: BorderSide(color: AppColors.darkGreen, width: 6),
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
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                m.customer.name,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2D3436),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
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
}
