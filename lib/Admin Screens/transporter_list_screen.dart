/*
import 'dart:convert';
import 'package:doc_delete/Models/transporter_model.dart';
import 'package:doc_delete/Widgets/confirm_dialog.dart';
import 'package:doc_delete/Widgets/custom_appbar.dart';
import 'package:doc_delete/Widgets/custom_iconbutton.dart';
import 'package:doc_delete/config/api_urls.dart';
import 'package:doc_delete/utils/session_manager.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'add_transporter_screen.dart';

class TransporterListScreen extends StatefulWidget {
  const TransporterListScreen({super.key});

  @override
  State<TransporterListScreen> createState() => _TransporterListScreenState();
}

class _TransporterListScreenState extends State<TransporterListScreen> {
  List<TransporterModel> transporter = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadTransporters();
  }

  Future<void> loadTransporters() async {
    setState(() {
      isLoading = true;
    });
    try {
      var data = await fetchTransporters();
      setState(() {
        transporter = data;
      });
    } catch (e) {
      debugPrint("Error loading technicians: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<List<TransporterModel>> fetchTransporters() async {
    final response = await http.get(Uri.parse(ApiUrls.transporter));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      List list = data["data"] ?? [];
      return list.map((e) => TransporterModel.fromJson(e)).toList();
    } else {
      return [];
    }
  }

  Future<void> deleteTransporter(int id, int userID) async {
    final response = await http.delete(
      Uri.parse(ApiUrls.transporter),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"id": id, "created_id": userID}),
    );

    if (response.statusCode == 200) {
      loadTransporters();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF4F7FB),
      appBar: CustomAppBar(
        title: "Transporter List",
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
                    builder: (context) => AddTransporterScreen(),
                  ),
                );

                if (result == true) {
                  loadTransporters();
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
              onRefresh: loadTransporters,
              child: transporter.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.local_shipping,
                            size: 60,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "No Transporter Found",
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
                      itemCount: transporter.length,
                      itemBuilder: (context, index) {
                        final tran = transporter[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.black.withOpacity(0.05),
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
                                      AddTransporterScreen(transporter: tran),
                                ),
                              );

                              if (result == true) {
                                loadTransporters();
                              }
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                /// 🔹 Top Row
                                Row(
                                  children: [
                                    /// Avatar
                                    CircleAvatar(
                                      radius: 26,
                                      backgroundColor: AppColors.darkGreen,
                                      child: Text(
                                        tran.name.isNotEmpty
                                            ? tran.name[0].toUpperCase()
                                            : "?",
                                        style: const TextStyle(
                                          color: AppColors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),

                                    const SizedBox(width: 12),

                                    /// Name
                                    Expanded(
                                      child: Text(
                                        tran.name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),

                                    Row(
                                      children: [
                                        GestureDetector(
                                          onTap: () async {
                                            final result = await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    AddTransporterScreen(
                                                      transporter: tran,
                                                    ),
                                              ),
                                            );

                                            if (result == true) {
                                              loadTransporters();
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

                                        /// Delete Icon
                                        GestureDetector(
                                          onTap: () {
                                            ConfirmDialog.show(
                                              context: context,
                                              title: "Delete Transporter",
                                              message:
                                                  "Are you sure you want to delete ${tran.name}?",
                                              confirmText: "Delete",
                                              confirmColor: AppColors.red,
                                              onConfirm: () =>
                                                  deleteTransporter(
                                                    tran.id!,
                                                    tran.createdId!,
                                                  ),
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

                                /// 🔹 Contact Person
                                Row(
                                  children: [
                                    Icon(
                                      Icons.person,
                                      size: 16,
                                      color: Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(tran.contactPerson),
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
                                    Text(tran.phone),
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
*/
