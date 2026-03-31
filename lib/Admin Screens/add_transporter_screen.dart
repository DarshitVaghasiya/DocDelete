/*
import 'dart:convert';
import 'dart:typed_data';
import 'package:doc_delete/Models/transporter_model.dart';
import 'package:doc_delete/Widgets/custom_appbar.dart';
import 'package:doc_delete/Widgets/custom_iconbutton.dart';
import 'package:doc_delete/Widgets/custom_textformfield.dart';
import 'package:doc_delete/Widgets/section_widget.dart';
import 'package:doc_delete/config/api_urls.dart';
import 'package:doc_delete/utils/session_manager.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:signature/signature.dart';

class AddTransporterScreen extends StatefulWidget {
  final TransporterModel? transporter;

  const AddTransporterScreen({super.key, this.transporter});

  @override
  State<AddTransporterScreen> createState() => _AddTransporterScreenState();
}

class _AddTransporterScreenState extends State<AddTransporterScreen> {
  final _formKey = GlobalKey<FormState>();
  bool isEditing = false;

  Uint8List? _existingSignatureBytes;
  bool _newSignatureDrawn = false;

  final nameController = TextEditingController();
  final contactController = TextEditingController();
  final phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    */
/*

    signatureController = SignatureController(penStrokeWidth: 3);

    signatureController.addListener(() {
      if (signatureController.isNotEmpty) {
        setState(() => _newSignatureDrawn = true);
      }
    });
*/ /*


    existingTransporter();
  }

  Future<String?> getSignatureBase64(SignatureController controller) async {
    final image = await controller.toPngBytes();
    if (image == null) return null;
    return base64Encode(image);
  }

  Future<void> existingTransporter() async {
    if (widget.transporter != null) {
      isEditing = false;

      nameController.text = widget.transporter!.name;
      contactController.text = widget.transporter!.contactPerson;
      phoneController.text = widget.transporter!.phone;

      */
/*  if (widget.transporter!.signature != null &&
          widget.transporter!.signature!.isNotEmpty) {
        _existingSignatureBytes = base64Decode(widget.transporter!.signature!);
        setState(() {});
      }*/ /*

    } else {
      isEditing = true;
    }
  }

  void saveTransporter() async {
    int? createdID = await SessionManager.getUserId();

    */
/*   String? signatureBase64;

    if (_newSignatureDrawn && signatureController.isNotEmpty) {
      // ✅ નવી signature વાપરો
      signatureBase64 = await getSignatureBase64(signatureController);
    } else if (_existingSignatureBytes != null) {
      // ✅ જૂની signature વાપરો
      signatureBase64 = base64Encode(_existingSignatureBytes!);
    }

    if (signatureBase64 == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please add signature")));
      return;
    }*/ /*


    TransporterModel technician = TransporterModel(
      id: widget.transporter?.id,
      createdId: createdID,
      name: nameController.text,
      contactPerson: contactController.text,
      phone: phoneController.text,
      //  signature: signatureBase64,
    );

    try {
      final response = widget.transporter == null
          ? await http.post(
              Uri.parse(ApiUrls.transporter),
              headers: {"Content-Type": "application/json"},
              body: jsonEncode(technician.toJson()),
            )
          : await http.put(
              Uri.parse(ApiUrls.transporter),
              headers: {"Content-Type": "application/json"},
              body: jsonEncode(technician.toJson()),
            );

      print(response.body);

      final data = jsonDecode(response.body);

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          data["status"] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.transporter == null
                    ? "Transporter saved successfully"
                    : "Transporter updated successfully",
              ),
              backgroundColor: AppColors.darkGreen,
            ),
          );

          Navigator.pop(context, true);
        }
      } else {
        String errorMsg = data["message"] ?? "Something went wrong";

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMsg), backgroundColor: AppColors.red),
          );
        }
      }
    } catch (e) {
      // 🔥 Network / exception error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: AppColors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF4F7FB),
      appBar: CustomAppBar(
        title: widget.transporter == null
            ? "Add Transporter"
            : "Edit Transporter",
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SectionWidget(
          icon: Icons.local_shipping,
          title: "Transporter Information",
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                textFormField(
                  labelText: "Transporter Name",
                  controller: nameController,
                  enabled: isEditing,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "Transporter name required";
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
                      return "Contact person required";
                    }
                    return null;
                  },
                ),

                textFormField(
                  labelText: "Contact Phone No.",
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  enabled: isEditing,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "Phone number required";
                    }
                    if (value.length < 10) {
                      return "Enter valid phone number";
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                */
/* signatureBox(signatureController, "Transporter Signature"),

                const SizedBox(height: 20),
*/ /*

                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: CustomIconButton(
                    label: widget.transporter == null
                        ? "Save Transporter"
                        : (isEditing
                              ? "Update Transporter"
                              : "Edit Transporter"),
                    backgroundColor: widget.transporter != null && !isEditing
                        ? AppColors.orange
                        : AppColors.darkGreen,
                    textColor: AppColors.white,
                    onTap: () {
                      if (widget.transporter != null && !isEditing) {
                        setState(() {
                          isEditing = true;
                        });
                      } else {
                        if (_formKey.currentState!.validate()) {
                          saveTransporter();
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget signatureBox(SignatureController controller, String title) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: IgnorePointer(
        ignoring: !isEditing,
        child: Column(
          children: [
            if (_existingSignatureBytes != null && !_newSignatureDrawn)
              Container(
                height: 150,
                width: double.infinity,
                color: Colors.grey.shade100,
                child: Image.memory(
                  _existingSignatureBytes!,
                  fit: BoxFit.scaleDown,
                ),
              )
            else
              Signature(
                controller: controller,
                height: 150,
                backgroundColor: Colors.grey.shade100,
              ),

            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                CustomIconButton(
                  label: "Clear",
                  textColor: AppColors.red,
                  onTap: () {
                    controller.clear();
                    setState(() {
                      _newSignatureDrawn = false;
                      // ✅ Clear કરો તો existing પણ clear
                      _existingSignatureBytes = null;
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
*/
