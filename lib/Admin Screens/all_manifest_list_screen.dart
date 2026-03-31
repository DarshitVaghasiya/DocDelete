import 'dart:convert';

import 'package:doc_delete/Models/get_all_manifest_model.dart';
import 'package:doc_delete/PDF/manifest_pdf.dart';
import 'package:doc_delete/PDF/pdf_preview.dart';
import 'package:doc_delete/Technician%20Screens/service_form_screen.dart';
import 'package:doc_delete/Widgets/confirm_dialog.dart';
import 'package:doc_delete/Widgets/custom_appbar.dart';
import 'package:doc_delete/config/api_urls.dart';
import 'package:doc_delete/utils/session_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:html' as html;

import 'package:intl/intl.dart';

class AllManifestListScreen extends StatefulWidget {
  const AllManifestListScreen({super.key});

  @override
  State<AllManifestListScreen> createState() => _AllManifestListScreenState();
}

class _AllManifestListScreenState extends State<AllManifestListScreen> {
  List<GetAllManifestModel> manifestList = [];
  bool isManifestLoading = false;
  List technicians = [];
  int? selectedTechnicianId;
  List customers = [];
  int? selectedCustomerId;

  @override
  void initState() {
    super.initState();
    fetchTechnicians();
    fetchCustomers();
    fetchAllManifests();
  }

  Future<void> fetchAllManifests() async {
    setState(() => isManifestLoading = true);

    try {
      int? adminID = await SessionManager.getUserId();
      String url = "${ApiUrls.getAllManifest}?is_admin=$adminID";

      if (selectedTechnicianId != null) {
        url += "&technician_id=$selectedTechnicianId";
      }

      if (selectedCustomerId != null) {
        url += "&customer_id=$selectedCustomerId";
      }

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

          setState(() {
            manifestList = list;
          });
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
          setState(() {
            technicians = json["data"];
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
          setState(() {
            customers = json["data"];
          });
        }
      }
    } catch (e) {
      print("Customer Error: $e");
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
        // 🔥 CASE 1: data is LIST
        if (data['data'] is List) {
          final list = data['data'] as List;
          if (list.isNotEmpty) {
            return GetAllManifestModel.fromJson(list[0]);
          }
        }
        // 🔥 CASE 2: data is OBJECT
        else if (data['data'] is Map) {
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
          "is_admin": userID, // ✅
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
    final groupedData = groupByDate();
    final dates = groupedData.keys.toList();
    return Scaffold(
      backgroundColor: const Color(0xffF4F7FB),
      appBar: CustomAppBar(title: "Manifests List"),
      body: isManifestLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.darkGreen),
            )
          : Padding(
              padding: EdgeInsets.symmetric(
                horizontal: width * .05,
                vertical: width * .02,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
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
                        hint: const Text("Select Technician"),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem<int>(
                            value: null, // 🔥 IMPORTANT
                            child: Text("All Manifest"),
                          ),
                          ...technicians.map<DropdownMenuItem<int>>((tech) {
                            return DropdownMenuItem<int>(
                              value: tech["id"],
                              child: Text(tech["name"]),
                            );
                          }).toList(),
                        ],
                        onChanged: (value) {
                          setState(() {
                            selectedTechnicianId = value;

                            /// 🔥 RESET CUSTOMER
                            selectedCustomerId = null;
                          });

                          fetchAllManifests();
                        },
                      ),
                    ),
                  ),

                  Center(
                    child: Text(
                      "OR",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
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
                        hint: const Text("Select Customer"),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text("All Customers"),
                          ),
                          ...customers.map<DropdownMenuItem<int?>>((c) {
                            return DropdownMenuItem<int?>(
                              value: c["id"],
                              child: Text(c["name"]),
                            );
                          }).toList(),
                        ],
                        onChanged: (value) {
                          setState(() {
                            selectedCustomerId = value;

                            /// 🔥 RESET TECHNICIAN
                            selectedTechnicianId = null;
                          });

                          fetchAllManifests();
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  /// HEADER
                  Text(
                    "Total Manifests (${manifestList.length})",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 10),

                  /// LIST AREA
                  Expanded(
                    child: manifestList.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.description_outlined,
                                  size: 60,
                                  color: Colors.grey.shade400,
                                ),
                                SizedBox(height: 12),
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
                        : ListView.builder(
                            itemCount: dates.length,
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
                ],
              ),
            ),
    );
  }

  Widget _manifestCard(GetAllManifestModel m) {
    return GestureDetector(
      onTap: () async {
        final manifest = await getManifestById(manifestId: m.manifestID);

        if (manifest != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ServiceFormScreen(
                isEdit: true,
                existManifest: manifest,
                technicianName: m.technicianName,
              ),
            ),
          ).then((_) {
            fetchAllManifests(); // 🔄 refresh after update
          });
        }
      },
      /*   onTap: () async {
        setState(() => isManifestLoading = true);

        final manifest = await getManifestById(manifestId: m.manifestID);

        if (manifest != null) {
          final bytes = await generateManifestPdf(
            manifest,
            technicianName: m.technicianName,
          );

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WebPdfViewerScreen(
                bytes: bytes,
                customerEmail: m.customer.email,
              ),
            ),
          );
        }

        setState(() => isManifestLoading = false);
      },*/
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
