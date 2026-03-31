import 'dart:convert';

import 'package:doc_delete/Admin%20Screens/add_technician_screen.dart';
import 'package:doc_delete/Models/technician_model.dart';
import 'package:doc_delete/Widgets/confirm_dialog.dart';
import 'package:doc_delete/Widgets/custom_appbar.dart';
import 'package:doc_delete/Widgets/custom_iconbutton.dart';
import 'package:doc_delete/config/api_urls.dart';
import 'package:doc_delete/utils/session_manager.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class TechnicianListScreen extends StatefulWidget {
  const TechnicianListScreen({super.key});

  @override
  State<TechnicianListScreen> createState() => _TechnicianListScreenState();
}

class _TechnicianListScreenState extends State<TechnicianListScreen> {
  List<TechnicianModel> technician = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadTechnicians();
  }

  Future<void> loadTechnicians() async {
    setState(() {
      isLoading = true;
    });
    try {
      var data = await fetchTechnicians();
      setState(() {
        technician = data;
      });
    } catch (e) {
      debugPrint("Error loading technicians: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<List<TechnicianModel>> fetchTechnicians() async {
    int? userId = await SessionManager.getUserId();
    final response = await http.get(
      Uri.parse("${ApiUrls.technician}?user_id=$userId"),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      List list = data["data"] ?? [];
      return list.map((e) => TechnicianModel.fromJson(e)).toList();
    } else {
      return [];
    }
  }

  Future<void> deleteTechnician(int id) async {
    final response = await http.delete(
      Uri.parse(ApiUrls.technician),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"id": id}),
    );

    print(response.body);

    if (response.statusCode == 200) {
      loadTechnicians();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF4F7FB),
      appBar: CustomAppBar(
        title: "Technician List",
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 15),
            child: CustomIconButton(
              icon: Icons.add,
              backgroundColor: AppColors.white,
              textColor: AppColors.darkGreen,
              iconSize: 25,
              padding: const EdgeInsets.all(10),
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddTechnicianScreen(),
                  ),
                );

                if (result == true) {
                  loadTechnicians();
                }
              },
            ),
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.darkGreen),
            )
          : RefreshIndicator(
              onRefresh: loadTechnicians,
              child: technician.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.engineering,
                            size: 60,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "No Technicians Found",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: technician.length,
                      itemBuilder: (context, index) {
                        final tech = technician[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      AddTechnicianScreen(technician: tech),
                                ),
                              );

                              if (result == true) {
                                loadTechnicians();
                              }
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                /// 🔹 Top Row
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 26,
                                      backgroundColor: AppColors.darkGreen,
                                      child: Text(
                                        tech.name.isNotEmpty
                                            ? tech.name[0].toUpperCase()
                                            : "?",
                                        style: const TextStyle(
                                          color: AppColors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),

                                    const SizedBox(width: 12),

                                    /// Name + Email
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            tech.name,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            tech.email,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    /// Actions
                                    Row(
                                      children: [
                                        GestureDetector(
                                          onTap: () async {
                                            final result = await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    AddTechnicianScreen(
                                                      technician: tech,
                                                    ),
                                              ),
                                            );

                                            if (result == true) {
                                              loadTechnicians();
                                            }
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.withOpacity(
                                                0.1,
                                              ),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.edit,
                                              size: 18,
                                              color: AppColors.blue,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        GestureDetector(
                                          onTap: () {
                                            ConfirmDialog.show(
                                              context: context,
                                              title: "Delete Technician",
                                              message:
                                                  "Are you sure you want to delete ${tech.name}?",
                                              confirmText: "Delete",
                                              confirmColor: AppColors.red,
                                              onConfirm: () =>
                                                  deleteTechnician(tech.id!),
                                            );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withOpacity(
                                                0.1,
                                              ),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.delete,
                                              size: 18,
                                              color: AppColors.red,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 12),

                                /// 🔹 Address
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      size: 16,
                                      color: Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        AddressFormatter.format(tech.address),
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 6),

                                /// 🔹 Phone
                                Row(
                                  children: [
                                    Icon(
                                      Icons.phone,
                                      size: 16,
                                      color: Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(tech.phone),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
