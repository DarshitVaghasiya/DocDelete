import 'dart:convert';
import 'package:doc_delete/Models/customer_model.dart';
import 'package:doc_delete/Widgets/confirm_dialog.dart';
import 'package:doc_delete/Widgets/custom_appbar.dart';
import 'package:doc_delete/Widgets/custom_iconbutton.dart';
import 'package:doc_delete/config/api_urls.dart';
import 'package:doc_delete/utils/session_manager.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'add_customer_screen.dart';

class CustomerListScreen extends StatefulWidget {
  final VoidCallback? onAddPressed;
  final Function(CustomerModel)? onEditPressed;

  const CustomerListScreen({super.key, this.onAddPressed, this.onEditPressed});
  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  List<CustomerModel> customer = [];
  bool isLoading = true;
  bool isAdmin = false;

  @override
  void initState() {
    super.initState();
    loadUserRole();
    fetchCustomers();
  }

  Future<void> loadUserRole() async {
    final user = await SessionManager.getUser();
    setState(() {
      isAdmin = user?.role == "admin"; // 🔥 role check
    });
  }

  Future<void> fetchCustomers() async {
    setState(() {
      isLoading = true;
    });
    try {
      final response = await http.get(Uri.parse(ApiUrls.customer));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List list = data["data"];
        List<CustomerModel> tempList = list
            .map((e) => CustomerModel.fromJson(e))
            .toList();

        // 👉 SORT HERE (A to Z)
        tempList.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );

        setState(() {
          customer = tempList;
        });
      }
    } catch (e) {
      debugPrint("Error fetching customers: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> deleteCustomers(int id) async {
    final response = await http.delete(
      Uri.parse(ApiUrls.customer),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"id": id}),
    );

    print(response.body);

    if (response.statusCode == 200) {
      fetchCustomers();
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content = Column(
      children: [
        CustomAppBar(
          title: "Customer List",
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
                  if (isAdmin) {
                    if (widget.onAddPressed != null) {
                      widget.onAddPressed!();
                    }
                  } else {
                    // 👉 Normal user → Navigator.push
                    final newCustomer = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddCustomerScreen(),
                      ),
                    );

                    if (newCustomer != null) {
                      fetchCustomers();
                    }
                  }
                },
              ),
            ),
          ],
        ),

        Expanded(
          child: isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.darkGreen),
                )
              : customer.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 60,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "No Customers Found",
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
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: customer.length,
                  itemBuilder: (context, index) {
                    final customers = customer[index];
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
                      child: GestureDetector(
                        onTap: () async {
                          if (isAdmin) {
                            if (widget.onEditPressed != null) {
                              widget.onEditPressed!(customers);
                            }
                          } else {
                            final updatedCustomer = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    AddCustomerScreen(customer: customers),
                              ),
                            );

                            if (updatedCustomer != null) {
                              fetchCustomers();
                            }
                          }
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            /// 🔹 Top Row (Avatar + Name + Actions)
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 26,
                                  backgroundColor: AppColors.darkGreen,
                                  child: Text(
                                    customers.name.isNotEmpty
                                        ? customers.name[0].toUpperCase()
                                        : "?",
                                    style: const TextStyle(
                                      color: AppColors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 12),

                                /// Name + Contact
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        customers.name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        customers.contactPerson,
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
                                        if (isAdmin) {
                                          if (widget.onEditPressed != null) {
                                            widget.onEditPressed!(customers);
                                          }
                                        } else {
                                          final updatedCustomer =
                                              await Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      AddCustomerScreen(
                                                        customer: customers,
                                                      ),
                                                ),
                                              );

                                          if (updatedCustomer != null) {
                                            fetchCustomers();
                                          }
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withOpacity(0.1),
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
                                          title: "Delete Customer",
                                          message:
                                              "Are you sure you want to delete ${customers.name}?",
                                          confirmText: "Delete",
                                          confirmColor: AppColors.red,
                                          onConfirm: () =>
                                              deleteCustomers(customers.id!),
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.1),
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
                                    AddressFormatter.format(customers.address),
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
                                Text(customers.phone),
                              ],
                            ),

                            const SizedBox(height: 6),

                            /// 🔹 Email
                            if (customers.email.isNotEmpty)
                              Row(
                                children: [
                                  Icon(
                                    Icons.email,
                                    size: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(child: Text(customers.email)),
                                ],
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
    if (isAdmin) {
      return Material(color: const Color(0xffF4F7FB), child: content);
    } else {
      return Scaffold(backgroundColor: const Color(0xffF4F7FB), body: content);
    }
  }
}
