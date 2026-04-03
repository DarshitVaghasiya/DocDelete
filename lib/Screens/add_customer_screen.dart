import 'dart:convert';

import 'package:doc_delete/Models/customer_model.dart';
import 'package:doc_delete/Models/department_model.dart';
import 'package:doc_delete/Widgets/custom_appbar.dart';
import 'package:doc_delete/Widgets/custom_elevated_button.dart';
import 'package:doc_delete/Widgets/custom_iconbutton.dart';
import 'package:doc_delete/Widgets/custom_refresh.dart';
import 'package:doc_delete/Widgets/custom_textformfield.dart';
import 'package:doc_delete/Widgets/section_widget.dart';
import 'package:doc_delete/config/api_urls.dart';
import 'package:doc_delete/utils/session_manager.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AddCustomerScreen extends StatefulWidget {
  final CustomerModel? customer;

  const AddCustomerScreen({super.key, this.customer});

  @override
  State<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  bool isEditing = false;

  final nameController = TextEditingController();
  final addressController = TextEditingController();
  final contactController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final departmentController = TextEditingController();

  List<DepartmentModel1> departments = [];

  @override
  void initState() {
    super.initState();
    existingCustomer();
    if (widget.customer != null && widget.customer!.id != null) {
      fetchDepartments(widget.customer!.id!);
    }
  }

  Future<void> existingCustomer() async {
    if (widget.customer != null) {
      isEditing = false;

      nameController.text = widget.customer!.name;
      addressController.text = AddressFormatter.format(
        widget.customer?.address ?? "",
      );
      contactController.text = widget.customer!.contactPerson;
      phoneController.text = widget.customer!.phone;
      emailController.text = widget.customer!.email;
    } else {
      isEditing = true;
    }
  }

  Future<void> saveCustomer() async {
    int? userId = await SessionManager.getUserId();

    CustomerModel customer = CustomerModel(
      id: widget.customer?.id,
      createdId: userId,
      name: nameController.text,
      address: addressController.text,
      contactPerson: contactController.text,
      phone: phoneController.text,
      email: emailController.text,
      departments: [], // 🔥 required (empty for now)
    );

    final response = widget.customer == null
        ? await http.post(
            Uri.parse(ApiUrls.customer),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(customer.toJson()),
          )
        : await http.put(
            Uri.parse(ApiUrls.customer),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(customer.toJson()),
          );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data["status"] == true) {
      int customerId = widget.customer?.id ?? int.parse(data["id"].toString());

      // 🔥 save departments after customer
      await saveDepartments(customerId);

      // 🔥 RETURN updated customer WITH departments
      CustomerModel updatedCustomer = CustomerModel(
        id: customerId,
        createdId: userId,
        name: nameController.text,
        address: addressController.text,
        contactPerson: contactController.text,
        phone: phoneController.text,
        email: emailController.text,
        departments: departments, // 🔥 IMPORTANT
      );

      if (mounted) Navigator.pop(context, updatedCustomer);
    } else {
      debugPrint("Error: ${response.body}");
    }
  }

  Future<void> saveDepartments(int customerId) async {
    for (var dept in departments) {
      if (dept.id != null) continue;

      await http.post(
        Uri.parse(ApiUrls.departments),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "customer_id": customerId,
          "department_name": dept.departmentName,
        }),
      );
    }
  }

  Future<void> fetchDepartments(int customerId) async {
    final response = await http.get(
      Uri.parse("${ApiUrls.departments}?customer_id=$customerId"),
    );

    final data = jsonDecode(response.body);

    if (data["status"] == true) {
      setState(() {
        departments = (data["data"] as List)
            .map((e) => DepartmentModel1.fromJson(e))
            .toList();
      });
    } else {
      print("Failed to load departments");
    }
  }

  Future<void> deleteDepartments(int id) async {
    await http.delete(
      Uri.parse(ApiUrls.departments),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"id": id}),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF4F7FB),
      appBar: CustomAppBar(
        title: widget.customer == null ? "Add Customer" : "Edit Customer",
      ),
      body: CustomRefresh(
        onRefresh: existingCustomer,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              SectionWidget(
                icon: Icons.people_alt_outlined,
                title: "Customer Information",
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      textFormField(
                        labelText: "Customer Name",
                        controller: nameController,
                        enabled: isEditing,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return "Customer Name required";
                          }
                          return null;
                        },
                      ),

                      textFormField(
                        labelText: "Address",
                        controller: addressController,
                        enabled: isEditing,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return "Address required";
                          }
                          return null;
                        },
                      ),

                      textFormField(
                        labelText: "Contact Person",
                        controller: contactController,
                        enabled: isEditing,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return "Contact Person required";
                          }
                          return null;
                        },
                      ),

                      textFormField(
                        labelText: "Phone",
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        enabled: isEditing,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return "Phone required";
                          }
                          return null;
                        },
                      ),

                      textFormField(
                        labelText: "Email",
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        enabled: isEditing,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return "Email required";
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              SectionWidget(
                icon: Icons.apartment,
                title: "Departments",
                child: Form(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      textFormField(
                        labelText: "Department Name",
                        controller: departmentController,
                        enabled: isEditing,
                      ),

                      const SizedBox(height: 12),

                      CustomIconButton(
                        label: "Add Department",
                        backgroundColor: isEditing
                            ? AppColors.darkGreen
                            : Colors.grey.shade400,
                        textColor: isEditing ? Colors.white : Colors.black45,

                        onTap: () {
                          if (!isEditing) return;
                          if (departmentController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Enter department name"),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            return;
                          }
                          if (departmentController.text.trim().isNotEmpty) {
                            setState(() {
                              departments.add(
                                DepartmentModel1(
                                  departmentName: departmentController.text
                                      .trim(),
                                ),
                              );
                              departmentController.clear();
                            });
                          }
                        },
                      ),

                      if (departments.isNotEmpty) const SizedBox(height: 20),

                      /// Empty State
                      if (departments.isEmpty)
                        Center(
                          child: Text(
                            "No departments added yet",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),

                      /// Department List
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: departments.length,
                        itemBuilder: (context, index) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.black.withOpacity(0.05),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                /// Icon
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.darkGreen.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.apartment,
                                    color: AppColors.darkGreen,
                                    size: 18,
                                  ),
                                ),

                                const SizedBox(width: 12),

                                /// Department Name
                                Expanded(
                                  child: Text(
                                    departments[index].departmentName,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),

                                /// Delete Button
                                GestureDetector(
                                  onTap: () async {
                                    if (!isEditing) return;

                                    final dept = departments[index];

                                    if (dept.id != null) {
                                      await deleteDepartments(dept.id!);
                                    }

                                    setState(() {
                                      departments.removeAt(index);
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.delete,
                                      color: !isEditing
                                          ? AppColors.grey
                                          : AppColors.red,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: CustomElevatedButton(
          text: widget.customer == null
              ? "Save Customer"
              : (isEditing ? "Update Customer" : "Edit Customer"),
          backgroundColor: widget.customer != null && !isEditing
              ? AppColors.orange
              : AppColors.darkGreen,
          onPressed: () {
            if (widget.customer != null && !isEditing) {
              setState(() {
                isEditing = true;
              });
            } else {
              if (_formKey.currentState!.validate()) {
                saveCustomer();
              }
            }
          },
        ),
      ),
    );
  }
}
