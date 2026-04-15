import 'dart:convert';
import 'dart:math';
import 'package:doc_delete/Models/technician_model.dart';
import 'package:doc_delete/Widgets/custom_appbar.dart';
import 'package:doc_delete/Widgets/custom_elevated_button.dart';
import 'package:doc_delete/Widgets/custom_iconbutton.dart';
import 'package:doc_delete/Widgets/custom_textformfield.dart';
import 'package:doc_delete/Widgets/section_widget.dart';
import 'package:doc_delete/config/api_urls.dart';
import 'package:doc_delete/utils/session_manager.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

class AddTechnicianScreen extends StatefulWidget {
  final TechnicianModel? technician;
  final VoidCallback? onSaved;

  const AddTechnicianScreen({super.key, this.technician, this.onSaved});

  @override
  State<AddTechnicianScreen> createState() => _AddTechnicianScreenState();
}

class _AddTechnicianScreenState extends State<AddTechnicianScreen> {
  final _formKey = GlobalKey<FormState>();
  bool isEditing = false;

  final nameController = TextEditingController();
  final addressController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    existingTechnician();
  }

  void existingTechnician() {
    if (widget.technician != null) {
      isEditing = false;

      nameController.text = widget.technician!.name;
      addressController.text = AddressFormatter.format(
        widget.technician?.address ?? "",
      );
      phoneController.text = widget.technician!.phone;
      emailController.text = widget.technician!.email;
      passwordController.text = widget.technician!.password;
    } else {
      isEditing = true;
    }
  }

  String generatePassword() {
    const letters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
    Random random = Random();

    String namePart = String.fromCharCodes(
      Iterable.generate(
        5,
        (_) => letters.codeUnitAt(random.nextInt(letters.length)),
      ),
    );

    int number = random.nextInt(90) + 10;

    return "$namePart@$number";
  }

  void saveTechnician() async {
    int? userId = await SessionManager.getUserId();

    TechnicianModel technician = TechnicianModel(
      id: widget.technician?.id,
      userId: userId,
      name: nameController.text,
      address: addressController.text,
      phone: phoneController.text,
      email: emailController.text,
      password: passwordController.text,
    );

    final response = widget.technician == null
        ? await http.post(
            Uri.parse(ApiUrls.technician),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(technician.toJson()),
          )
        : await http.put(
            Uri.parse(ApiUrls.technician),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(technician.toJson()),
          );

    print(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      if (mounted) {
        if (widget.onSaved != null) {
          widget.onSaved!();
        }
      }
    } else {
      debugPrint("Error saving technician: ${response.body}");
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    addressController.dispose();
    phoneController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CustomAppBar(
          title: widget.technician == null
              ? "Add Technician"
              : "Edit Technician",
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SectionWidget(
              icon: Icons.person,
              title: "Technician Information",
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    textFormField(
                      labelText: "Technician Name",
                      controller: nameController,
                      enabled: isEditing,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return "Technician Name required";
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
                    textFormField(
                      labelText: "Password",
                      controller: passwordController,
                      keyboardType: TextInputType.visiblePassword,
                      enabled: isEditing,
                      obscureText: !isEditing,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return "Password required";
                        }
                        return null;
                      },
                    ),

                    Row(
                      children: [
                        Expanded(
                          child: CustomIconButton(
                            label: "Generate Password",
                            backgroundColor: isEditing
                                ? AppColors.darkGreen
                                : Colors.grey.shade400,
                            textColor: isEditing
                                ? AppColors.white
                                : Colors.black45,

                            onTap: () {
                              if (!isEditing) return;
                              passwordController.text = generatePassword();
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CustomIconButton(
                            label: "Share Password",
                            borderColor: isEditing
                                ? AppColors.black
                                : AppColors.grey,
                            textColor: isEditing
                                ? AppColors.black
                                : Colors.black45,
                            onTap: () {
                              if (!isEditing) return;
                              if (nameController.text.isEmpty ||
                                  emailController.text.isEmpty ||
                                  passwordController.text.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Please fill technician details",
                                    ),
                                  ),
                                );
                                return;
                              }

                              String message =
                                  """
                              Technician Login Details

                              Name: ${nameController.text}
                              Email: ${emailController.text}
                              Password: ${passwordController.text}

                              Please keep this password secure.
                              """;

                              Share.share(message);
                            },
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

        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: CustomElevatedButton(
                  text: widget.technician == null
                      ? "Save Technician"
                      : (isEditing ? "Update Technician" : "Edit Technician"),
                  backgroundColor: widget.technician != null && !isEditing
                      ? AppColors.orange
                      : AppColors.darkGreen,
                  onPressed: () {
                    if (widget.technician != null && !isEditing) {
                      setState(() {
                        isEditing = true;
                      });
                    } else {
                      if (_formKey.currentState!.validate()) {
                        saveTechnician();
                      }
                    }
                  },
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: CustomElevatedButton(
                  text: "Cancel",
                  backgroundColor: AppColors.red,
                  onPressed: () {
                    if (widget.onSaved != null) {
                      widget.onSaved!();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
