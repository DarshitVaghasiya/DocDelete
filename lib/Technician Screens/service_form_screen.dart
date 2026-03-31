import 'dart:convert';
import 'dart:io';
import 'package:doc_delete/Models/customer_model.dart';
import 'package:doc_delete/Models/department_model.dart';
import 'package:doc_delete/Models/manifest_model.dart';
import 'package:doc_delete/Models/service_model.dart';
import 'package:doc_delete/Models/user_model.dart';
import 'package:doc_delete/PDF/manifest_pdf.dart';
import 'package:doc_delete/PDF/pdf_preview.dart';
import 'package:doc_delete/Screens/add_customer_screen.dart';
import 'package:doc_delete/Widgets/custom_appbar.dart';
import 'package:doc_delete/Widgets/custom_elevated_button.dart';
import 'package:doc_delete/Widgets/custom_iconbutton.dart';
import 'package:doc_delete/Widgets/custom_textformfield.dart';
import 'package:doc_delete/Widgets/section_widget.dart';
import 'package:doc_delete/config/api_urls.dart';
import 'package:doc_delete/config/get_all_manifest_api.dart'
    show ManifestService;
import 'package:doc_delete/utils/session_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:signature/signature.dart';

class ServiceFormScreen extends StatefulWidget {
  const ServiceFormScreen({super.key});

  @override
  State<ServiceFormScreen> createState() => _ServiceFormScreenState();
}

class _ServiceFormScreenState extends State<ServiceFormScreen> {
  final ImagePicker _picker = ImagePicker();
  bool isLoading = false;
  UserModel? loggedUser;

  CustomerModel? selectedClient;
  List<CustomerModel> customer = [];

  DepartmentModel1? selectedDepartment;
  List<DepartmentModel1> departments = [];

  List<ServiceItemModel> serviceItems = [];

  List<dynamic> photos = [];
  String? unitType;

  bool destruction = false;
  bool storage = false;
  bool eWaste = false;
  bool serviceTicket = false;
  bool showCustomerSignature = false;
  bool showTechSignature = false;

  DateTime selectedDate = DateTime.now();
  String? boxSize;
  List<String> unit = ["SECURITY CONSOLE", "SECURITY CART", "BOXES", "OTHER"];
  List<String> boxSizes = ["12 x 10 x 15", "12 x 10 x 24"];

  String lastTapped = "";

  /// CLIENT CONTROLLERS
  TextEditingController nameController = TextEditingController();
  TextEditingController addressController = TextEditingController();
  TextEditingController contactController = TextEditingController();
  TextEditingController phoneController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController dateController = TextEditingController();

  /// SERVICE CONTROLLERS
  TextEditingController customController = TextEditingController();
  TextEditingController measureController = TextEditingController();
  TextEditingController quantityController = TextEditingController();
  TextEditingController qtyController = TextEditingController();

  SignatureController customerController = SignatureController(
    penStrokeWidth: 3,
  );

  SignatureController techController = SignatureController(penStrokeWidth: 3);

  @override
  void initState() {
    super.initState();
    loadUser();
    dateController.text = DateFormat('MMMM d, yyyy').format(selectedDate);
    fetchServiceFormData();
  }

  Future<void> loadUser() async {
    final user = await SessionManager.getUser();

    if (!mounted) return;

    setState(() {
      loggedUser = user;
    });
  }

  Future<void> fetchServiceFormData() async {
    setState(() {
      isLoading = true;
    });

    try {
      int? technicianId = await SessionManager.getUserId();
      final response = await http.get(
        Uri.parse("${ApiUrls.getServiceFormData}?technician_id=$technicianId"),
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        if (json["status"] == true) {
          final data = json["data"];

          customer = (data["customers"] as List)
              .map((e) => CustomerModel.fromJson(e))
              .toList();

          setState(() {});
        }
      }
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
        dateController.text = "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }

  void addItem() {
    if (unitType == null || quantityController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Fill unit type and quantity")),
      );
      return;
    }

    if (selectedDepartment == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please select department")));
      return;
    }

    List<String> types = [];

    if (destruction) types.add("DOCUMENT DESTRUCTION");
    if (storage) types.add("DOCUMENT STORAGE");
    if (eWaste) types.add("E-WASTE");
    if (serviceTicket) types.add("SERVICE DELIVERY TICKET");
    if (customController.text.isNotEmpty) {
      types.add(customController.text);
    }

    String serviceType = types.join(", ");

    ServiceItemModel item = ServiceItemModel(
      departmentId: selectedDepartment!.id!, // ✅ FIX
      unitType: unitType!,
      measure: measureController.text,
      quantity: quantityController.text,
      serviceType: serviceType,
    );

    setState(() {
      serviceItems.add(item);
    });

    unitType = null;
    measureController.clear();
    quantityController.clear();
    selectedDepartment = null;
  }

  Future<void> takeImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(
      source: source,
      imageQuality: 80,
    );

    if (image != null) {
      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        setState(() => photos.add(bytes));
      } else {
        setState(() => photos.add(File(image.path)));
      }
    }
  }

  Future<void> pickImage() async {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text("Camera"),
                onTap: () {
                  Navigator.pop(context);
                  takeImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo),
                title: const Text("Gallery"),
                onTap: () {
                  Navigator.pop(context);
                  takeImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<String?> getSignatureBase64(SignatureController controller) async {
    final image = await controller.toPngBytes();
    if (image == null) return null;
    return base64Encode(image);
  }

  Future<String> compressAndEncodeImage(String path) async {
    final file = File(path);
    final originalBytes = await file.readAsBytes();
    final result = await FlutterImageCompress.compressWithFile(
      path,
      quality: 60,
      minWidth: 800,
      minHeight: 800,
    );

    final compressedBytes = result ?? originalBytes;
    final base64String = base64Encode(compressedBytes);
    return base64String;
  }

  Future<List<String>> buildPhotos() async {
    List<String> list = [];

    for (var photo in photos) {
      try {
        if (photo is File) {
          print("📸 File: ${photo.path}");

          final base64 = await compressAndEncodeImage(photo.path);
          list.add(base64);
        } else if (photo is Uint8List) {
          /// 🟢 COMPRESS
          final compressedBytes = await FlutterImageCompress.compressWithList(
            photo,
            quality: 50, // 🔥 try 40–60
            minWidth: 800,
            minHeight: 800,
          );

          /// 🟡 BASE64 SIZE
          final base64String = base64Encode(compressedBytes);
          list.add(base64String);
        }
        /// ❌ UNKNOWN TYPE
        else {
          print("❌ Unknown type: ${photo.runtimeType}");
        }
      } catch (e) {
        print("❌ Error: $e");
      }
      await Future.delayed(const Duration(milliseconds: 50));
    }
    return list;
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String getDepartmentName(int id) {
    try {
      return departments.firstWhere((d) => d.id == id).departmentName;
    } catch (e) {
      return "";
    }
  }

  Future<void> submitForm() async {
    if (!validateForm()) return;
    if (isLoading) return;
    setState(() => isLoading = true);

    await Future.delayed(Duration(milliseconds: 100));

    try {
      final images = await buildPhotos();

      int? technicianId = await SessionManager.getUserId();

      if (technicianId == null) {
        showError("Technician not found");
        return;
      }

      final request = ManifestModel(
        technicianId: technicianId,
        customerId: selectedClient?.id,
        customerName: nameController.text,
        serviceDate: selectedDate.toString(),
        serviceItems: serviceItems,
        images: images,
        customerSign: await getSignatureBase64(customerController),
        technicianSign: await getSignatureBase64(techController),
      );

      final response = await http.post(
        Uri.parse(ApiUrls.manifest),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(request.toJson()),
      );

      final data = jsonDecode(response.body);

      /// ✅ SUCCESS CONDITION
      if (response.statusCode == 200 && data["status"] == true) {
        if (mounted) {
          final navigator = Navigator.of(context);
          final manifest = await ManifestService.getManifest(
            technicianId: technicianId,
          );

          if (manifest == null) {
            showError("Manifest not found");
            return;
          }

          final bytes = await generateManifestPdf(
            manifest,
            technicianName: manifest.technicianName,
          );

          print("Success");
          Navigator.pop(context, true); // 🔥 only here

          if (!mounted) return;
          navigator.push(
            MaterialPageRoute(
              builder: (_) => WebPdfViewerScreen(
                bytes: bytes,
                customerEmail: manifest.customer.email,
              ),
            ),
          );
        }
      } else {
        showError(data["message"] ?? "Something went wrong");
      }
    } catch (e) {
      showError("Error: $e");
      print("Error: $e");
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  bool validateForm() {
    /// ✅ SERVICE TYPE

    if (nameController.text.isEmpty) {
      showError("Please add customer name");
      return false;
    }

    if (!destruction &&
        !storage &&
        !eWaste &&
        !serviceTicket &&
        customController.text.isEmpty) {
      showError("Please select at least one service type");
      return false;
    }

    if (unitType == "Boxes" && (boxSize == null || boxSize!.isEmpty)) {
      showError("Please select box size");
      return false;
    }

    /// 🔥 IMPORTANT → item add કરાવવું
    if (serviceItems.isEmpty) {
      showError("Please add at least one item");
      return false;
    }

    if (customerController.isEmpty) {
      showError("Please add customer signature");
      return false;
    }

    if (techController.isEmpty) {
      showError("Please add technician signature");
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: const Color(0xffF4F7FB),
      appBar: CustomAppBar(title: "Manifest Form"),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                /// CLIENT INFORMATION
                SectionWidget(
                  title: "Client Information",
                  icon: Icons.people_outlined,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<CustomerModel>(
                              isExpanded: true,
                              value: customer.isEmpty
                                  ? null
                                  : selectedClient, // 🔥 fix
                              dropdownColor: AppColors.white,
                              decoration: InputDecoration(
                                labelText: "Select Customer / Company",
                                filled: true,
                                fillColor: Colors.grey.shade100,
                                labelStyle: TextStyle(color: AppColors.black),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(8),
                                  ),
                                  borderSide: BorderSide(
                                    color: AppColors.black,
                                  ),
                                ),
                                focusedBorder: const OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(8),
                                  ),
                                  borderSide: BorderSide(
                                    color: AppColors.black,
                                    width: 1.2,
                                  ),
                                ),
                              ),

                              hint: Text(
                                customer.isEmpty
                                    ? "No customers available"
                                    : "Select Customer / Company",
                                style: TextStyle(color: Colors.grey),
                              ),

                              items: customer.map((client) {
                                return DropdownMenuItem(
                                  value: client,
                                  child: Text(client.name),
                                );
                              }).toList(),

                              onChanged: customer.isEmpty
                                  ? null // 🔥 disable dropdown
                                  : (client) {
                                      setState(() {
                                        selectedClient = client;

                                        addressController.text =
                                            AddressFormatter.format(
                                              client?.address ?? "",
                                            );
                                        contactController.text =
                                            client?.contactPerson ?? "";
                                        phoneController.text =
                                            client?.phone ?? "";
                                        emailController.text =
                                            client?.email ?? "";

                                        selectedDepartment = null;
                                        departments = client?.departments ?? [];
                                      });
                                    },
                            ),
                          ),

                          const SizedBox(width: 10),

                          CustomIconButton(
                            icon: Icons.add,
                            label: "ADD",
                            backgroundColor: AppColors.darkGreen,
                            textColor: AppColors.white,

                            onTap: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const AddCustomerScreen(),
                                ),
                              );

                              if (result != null && result is CustomerModel) {
                                setState(() {
                                  customer.add(result); // 🔥 add locally
                                });
                              }
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      textFormField(
                        labelText: "Customer Name",
                        controller: nameController,
                        onChanged: (val) {
                          setState(() {});
                        },
                      ),

                      textFormField(
                        labelText: "Address",
                        controller: addressController,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                      ),

                      textFormField(
                        labelText: "Contact Person",
                        controller: contactController,
                      ),

                      textFormField(
                        labelText: "Phone Number",
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                      ),

                      textFormField(
                        labelText: "Email Address",
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      textFormField(
                        labelText: "Select Date",
                        controller: dateController,
                        readOnly: true,
                        onTap: () {
                          FocusScope.of(context).requestFocus(FocusNode());
                          pickDate();
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                /// SERVICE TYPE
                SectionWidget(
                  title: "Select Service Type",
                  icon: Icons.miscellaneous_services_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text("Confidential Document Destruction"),
                        value: destruction,
                        activeColor: AppColors.darkGreen,
                        controlAffinity: ListTileControlAffinity.trailing,
                        checkboxScaleFactor: 1.2,
                        onChanged: (v) => setState(() => destruction = v!),
                      ),

                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text("Confidential Document Storage"),
                        value: storage,
                        activeColor: AppColors.darkGreen,
                        controlAffinity: ListTileControlAffinity.trailing,
                        checkboxScaleFactor: 1.2,
                        onChanged: (v) => setState(() => storage = v!),
                      ),

                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text("E-Waste Recycling"),
                        value: eWaste,
                        activeColor: AppColors.darkGreen,
                        controlAffinity: ListTileControlAffinity.trailing,
                        checkboxScaleFactor: 1.2,
                        onChanged: (v) => setState(() => eWaste = v!),
                      ),

                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text("Service Delivery Ticket"),
                        value: serviceTicket,
                        activeColor: AppColors.darkGreen,
                        controlAffinity: ListTileControlAffinity.trailing,
                        checkboxScaleFactor: 1.2,
                        onChanged: (v) => setState(() => serviceTicket = v!),
                      ),

                      const SizedBox(height: 10),

                      textFormField(
                        labelText: "Custom Description",
                        controller: customController,
                      ),
                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Icon(
                            Icons.miscellaneous_services_outlined,
                            color: AppColors.darkGreen,
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            "Units / Quantity",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      /// UNIT TYPE
                      DropdownButtonFormField<String>(
                        value: unitType,
                        dropdownColor: AppColors.white,
                        decoration: InputDecoration(
                          labelText: "Unit Type",
                          labelStyle: TextStyle(color: AppColors.black),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: AppColors.black,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: AppColors.black,
                            ),
                          ),
                        ),

                        items: unit.map((value) {
                          return DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),

                        onChanged: (value) {
                          setState(() {
                            unitType = value;
                            boxSize = null;

                            if (value == "SECURITY CONSOLE") {
                              measureController.text = "17.1 DRY GALLONS";
                            } else if (value == "SECURITY CART") {
                              measureController.text = "65 DRY GALLONS";
                            } else {
                              measureController.clear();
                            }
                          });
                        },
                      ),

                      if (unitType == "BOXES") ...[
                        const SizedBox(height: 15),

                        DropdownButtonFormField<String>(
                          value: boxSize,
                          dropdownColor: AppColors.white,
                          decoration: InputDecoration(
                            labelText: "Select Box Size",
                            labelStyle: TextStyle(color: AppColors.black),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.black,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.black,
                              ),
                            ),
                          ),
                          items: boxSizes.map((size) {
                            return DropdownMenuItem(
                              value: size,
                              child: Text(size),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              boxSize = value;
                              measureController.text = value ?? "";
                            });
                          },
                        ),
                      ],

                      const SizedBox(height: 15),

                      /// MEASURE
                      if (unitType != "BOXES")
                        textFormField(
                          labelText: "Measure / Volume",
                          controller: measureController,
                        ),

                      /// QUANTITY
                      textFormField(
                        labelText: "Quantity",
                        controller: quantityController,
                        keyboardType: TextInputType.number,
                      ),

                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Icon(Icons.apartment, color: AppColors.darkGreen),
                          const SizedBox(width: 10),
                          const Text(
                            "Departments",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      /// Department ENTRY
                      DropdownButtonFormField<DepartmentModel1>(
                        value: selectedDepartment,
                        dropdownColor: AppColors.white,
                        decoration: InputDecoration(
                          labelText: "Select Departments",
                          labelStyle: TextStyle(color: AppColors.black),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: AppColors.black,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: AppColors.black,
                            ),
                          ),
                        ),
                        items: departments.map((dept) {
                          return DropdownMenuItem<DepartmentModel1>(
                            value: dept,
                            child: Text(dept.departmentName),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedDepartment = value;
                          });
                        },
                      ),
                      const SizedBox(height: 20),

                      /// ADD ITEM BUTTON
                      CustomIconButton(
                        backgroundColor: AppColors.darkGreen,
                        textColor: AppColors.white,
                        icon: Icons.add,
                        label: "Add Item and Department",
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        onTap: () {
                          addItem();
                          //addDepartment();
                        },
                      ),

                      if (serviceItems.isNotEmpty) const SizedBox(height: 20),

                      /// ITEMS LIST
                      ListView.separated(
                        reverse: true,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: serviceItems.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = serviceItems[index];

                          return Container(
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.shade300),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.black.withOpacity(0.03),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),

                              // 🔹 ICON
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.darkGreen.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.inventory_2_outlined,
                                  color: AppColors.darkGreen,
                                  size: 22,
                                ),
                              ),

                              // 🔹 TITLE
                              title: Text(
                                getDepartmentName(item.departmentId),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),

                              // 🔹 SUBTITLE (BETTER STRUCTURE)
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.unitType,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.unitType == "Boxes"
                                          ? "Box Size: ${item.measure} | Qty: ${item.quantity}"
                                          : "Measure: ${item.measure} | Qty: ${item.quantity}",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // 🔹 DELETE BUTTON (BETTER UX)
                              trailing: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () {
                                    setState(() {
                                      serviceItems.removeAt(index);
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.08),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.delete_outline,
                                      color: AppColors.red,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                /// PHOTOS
                SectionWidget(
                  title: "Photos",
                  icon: Icons.image_outlined,
                  trailing: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.darkGreen,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      pickImage();
                    },
                    icon: const Icon(Icons.camera_alt),
                    label: const Text("Take Photo"),
                  ),
                  child: Column(
                    children: [
                      if (photos.isEmpty)
                        Container(
                          height: 120,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade300),
                            color: Colors.grey.shade50,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.camera_alt_outlined,
                                size: 32,
                                color: Colors.grey.shade500,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "No photos added",
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Tap 'Take Photo' to capture",
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),

                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: photos.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: width < 400
                              ? 3
                              : width < 700
                              ? 4
                              : 6,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemBuilder: (context, index) {
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: AspectRatio(
                                  aspectRatio: 1, // 🔥 perfect square
                                  child: kIsWeb
                                      ? Image.memory(
                                          photos[index],
                                          fit: BoxFit.cover,
                                        )
                                      : Image.file(
                                          photos[index],
                                          fit: BoxFit.cover,
                                        ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      photos.removeAt(index);
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: AppColors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                /*         SectionWidget(
                  icon: Icons.local_shipping,
                  title: "Select Your Transporter",
                  child: Column(
                    children: [
                      */
                /*  DropdownButtonFormField<TransporterModel>(
                        value: selectedTransporter,
                        dropdownColor: AppColors.white,
                        decoration: InputDecoration(
                          labelText: "Select Transporter",
                          labelStyle: TextStyle(color: AppColors.black),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: AppColors.black,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: AppColors.black,
                            ),
                          ),
                        ),
                        items: transporter.map((t) {
                          return DropdownMenuItem(
                            value: t,
                            child: Text(t.name), // transporter name
                          );
                        }).toList(),

                        onChanged: (value) {
                          setState(() {
                            selectedTransporter = value;
                            showTransporterSignature = true;
                          });
                        },
                      ),*/
                /*
                    ],
                  ),
                ),

                const SizedBox(height: 20),*/

                /// SIGNATURE
                SectionWidget(
                  title: "Signatures",
                  icon: Icons.draw,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: CustomIconButton(
                              label: "Customer Signature",
                              backgroundColor: AppColors.darkGreen,
                              textColor: AppColors.white,
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 15,
                              ),
                              onTap: () {
                                setState(() {
                                  showCustomerSignature = true;
                                  lastTapped = "customer";
                                });
                              },
                            ),
                          ),

                          const SizedBox(width: 12),

                          Flexible(
                            child: CustomIconButton(
                              label: "Technician Signature",
                              backgroundColor: AppColors.darkGreen,
                              textColor: AppColors.white,
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 15,
                              ),
                              onTap: () {
                                setState(() {
                                  showTechSignature = true;
                                  lastTapped = "tech";
                                });
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 15),

                      /// Customer Signature Pad
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: Column(
                          children: [
                            if (lastTapped == "tech" && showTechSignature)
                              signatureBox(
                                techController,
                                "${loggedUser?.name ?? "Technician"} Signature",
                              ),

                            if (lastTapped == "tech" &&
                                showTechSignature &&
                                showCustomerSignature)
                              const SizedBox(height: 20),

                            if (lastTapped == "tech" && showCustomerSignature)
                              signatureBox(
                                customerController,
                                nameController.text.isEmpty
                                    ? "Customer Signature"
                                    : "${nameController.text} Signature",
                              ),

                            // ✅ Customer last tap
                            if (lastTapped == "customer" &&
                                showCustomerSignature)
                              signatureBox(
                                customerController,
                                nameController.text.isEmpty
                                    ? "Customer Signature"
                                    : "${nameController.text} Signature",
                              ),

                            if (lastTapped == "customer" &&
                                showCustomerSignature &&
                                showTechSignature)
                              const SizedBox(height: 20),

                            if (lastTapped == "customer" && showTechSignature)
                              signatureBox(
                                techController,
                                "${loggedUser?.name ?? "Technician"} Signature",
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.darkGreen,
                ), // 🔥 loader
              )
            : CustomElevatedButton(text: "Submit Form", onPressed: submitForm),
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
      child: Column(
        children: [
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
                  controller.clear(); // 🔥 Signature clear
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
