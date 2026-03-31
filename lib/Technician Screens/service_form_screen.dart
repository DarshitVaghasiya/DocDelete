import 'dart:convert';
import 'dart:io';
import 'package:doc_delete/Models/customer_model.dart';
import 'package:doc_delete/Models/department_model.dart';
import 'package:doc_delete/Models/get_all_manifest_model.dart';
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
import 'package:doc_delete/utils/session_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:signature/signature.dart';

class ServiceFormScreen extends StatefulWidget {
  final bool isEdit;
  final GetAllManifestModel? existManifest;
  final String? technicianName;
  const ServiceFormScreen({
    super.key,
    this.isEdit = false,
    this.existManifest,
    this.technicianName,
  });

  @override
  State<ServiceFormScreen> createState() => _ServiceFormScreenState();
}

class _ServiceFormScreenState extends State<ServiceFormScreen> {
  final ImagePicker _picker = ImagePicker();
  bool isLoading = false;
  bool isPageLoading = false;
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
  bool showAdminSignature = false;

  DateTime selectedDate = DateTime.now();
  String? boxSize;
  List<String> unit = ["SECURITY CONSOLE", "SECURITY CART", "BOXES", "OTHER"];
  List<String> boxSizes = ["12 x 10 x 15", "12 x 10 x 24"];

  String lastTapped = "";
  bool get isAdmin => loggedUser?.role == "admin";

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

  SignatureController adminController = SignatureController(penStrokeWidth: 3);

  Uint8List? customerSignBytes;
  Uint8List? techSignBytes;
  Uint8List? adminSignBytes;

  @override
  void initState() {
    super.initState();
    loadUser();
    dateController.text = DateFormat('MMMM d, yyyy').format(selectedDate);
    initData();
  }

  Future<void> initData() async {
    setState(() => isPageLoading = true);
    await fetchServiceFormData();
    if (widget.isEdit && widget.existManifest != null) {
      await setExistingData();
    }

    if (widget.isEdit) {
      showCustomerSignature = true;
      showTechSignature = true;
    } else {
      showCustomerSignature = false;
      showTechSignature = false;
    }
    setState(() => isPageLoading = false);
  }

  Future<void> loadUser() async {
    final user = await SessionManager.getUser();

    if (!mounted) return;

    setState(() {
      loggedUser = user;
    });
  }

  Future<void> setExistingData() async {
    final m = widget.existManifest!;

    /// ✅ BASIC DATA
    nameController.text = m.customerName;
    addressController.text = AddressFormatter.format(m.customer.address);
    contactController.text = m.customer.contactPerson;
    phoneController.text = m.customer.phone;
    emailController.text = m.customer.email;

    selectedDate = DateTime.parse(m.serviceDate);
    dateController.text = DateFormat('MMMM d, yyyy').format(selectedDate);

    /// ✅ DROPDOWN SELECT (IMPORTANT)
    final match = customer.where((c) => c.id == m.customer.id).toList();

    if (match.isNotEmpty) {
      selectedClient = match.first;
    } else {
      selectedClient = null; // 🔥 IMPORTANT
    }

    /// ✅ SERVICE ITEMS
    serviceItems = m.units.map((item) {
      return ServiceItemModel(
        departmentId: item.departmentId,
        unitType: item.unitType,
        measure: item.measure,
        quantity: item.quantity,
        serviceType: item.serviceType,
      );
    }).toList();

    /// ✅ SERVICE TYPE CHECKBOXES
    for (var item in m.units) {
      if (item.serviceType.contains("DOCUMENT DESTRUCTION")) {
        destruction = true;
      }
      if (item.serviceType.contains("DOCUMENT STORAGE")) {
        storage = true;
      }
      if (item.serviceType.contains("E-WASTE")) {
        eWaste = true;
      }
      if (item.serviceType.contains("SERVICE DELIVERY TICKET")) {
        serviceTicket = true;
      }
    }
    departments = selectedClient?.departments ?? [];

    /// ✅ PHOTOS (existing show karva hoy to)
    // NOTE: aa URL hoy to network image use karvu pade
    // currently tame skip kari sako cho
    if (m.customerSign!.isNotEmpty) {
      customerSignBytes = base64Decode(m.customerSign!);
    }

    if (m.technicianSign!.isNotEmpty) {
      techSignBytes = base64Decode(m.technicianSign!);
    }

    showCustomerSignature = true;
    showTechSignature = true;
  }

  Future<void> fetchServiceFormData() async {
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
        }
      }
    } catch (e) {
      debugPrint("Error: $e");
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

  void handleResponse(http.Response response) {
    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data["status"] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEdit
                ? "Manifest updated successfully"
                : "Manifest created successfully",
          ),
          backgroundColor: AppColors.darkGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    } else {
      showError(data["message"] ?? "Something went wrong");
    }
  }

  Future<void> createManifest() async {
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

    handleResponse(response);
  }

  Future<void> updateManifest() async {
    final images = await buildPhotos();
    int? technicianId = await SessionManager.getUserId();

    if (technicianId == null) {
      showError("Technician not found");
      return;
    }
    final request = ManifestModel(
      id: widget.existManifest?.manifestID, // 🔥 IMPORTANT
      technicianId: technicianId,
      customerId: selectedClient?.id,
      customerName: nameController.text,
      serviceDate: selectedDate.toString(),
      serviceItems: serviceItems,
      images: images,
      customerSign: await getSignatureBase64(customerController),
      technicianSign: await getSignatureBase64(techController),
      adminSign: await getSignatureBase64(adminController),
    );

    final response = await http.put(
      Uri.parse(ApiUrls.manifest),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(request.toJson()),
    );

    handleResponse(response);
  }

  Future<void> submitForm() async {
    if (!validateForm()) return;
    if (isLoading) return;

    setState(() => isLoading = true);

    try {
      if (widget.isEdit) {
        await updateManifest(); // 🔥 UPDATE
      } else {
        await createManifest(); // 🔥 CREATE
      }
    } catch (e) {
      showError("Error: $e");
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  bool validateForm() {
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

    if (serviceItems.isEmpty) {
      showError("Please add at least one item");
      return false;
    }

    // ✅ Admin edit mode ma sirf admin sign validate karvo
    if (widget.isEdit && isAdmin) {
      if (adminController.isEmpty) {
        showError("Please add admin signature");
        return false;
      }
    } else {
      // ✅ Normal mode ma customer + tech sign validate karva
      if (customerController.isEmpty) {
        showError("Please add customer signature");
        return false;
      }
      if (techController.isEmpty) {
        showError("Please add technician signature");
        return false;
      }
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: const Color(0xffF4F7FB),
      appBar: CustomAppBar(title: "Manifest Form"),
      body: isPageLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.darkGreen),
            )
          : Stack(
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
                                      labelStyle: TextStyle(
                                        color: AppColors.black,
                                      ),
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
                                              departments =
                                                  client?.departments ?? [];
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

                                    if (result != null &&
                                        result is CustomerModel) {
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
                                FocusScope.of(
                                  context,
                                ).requestFocus(FocusNode());
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
                              title: const Text(
                                "Confidential Document Destruction",
                              ),
                              value: destruction,
                              activeColor: AppColors.darkGreen,
                              controlAffinity: ListTileControlAffinity.trailing,
                              checkboxScaleFactor: 1.2,
                              onChanged: (v) =>
                                  setState(() => destruction = v!),
                            ),

                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                "Confidential Document Storage",
                              ),
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
                              onChanged: (v) =>
                                  setState(() => serviceTicket = v!),
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
                                Icon(
                                  Icons.apartment,
                                  color: AppColors.darkGreen,
                                ),
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

                            if (serviceItems.isNotEmpty)
                              const SizedBox(height: 20),

                            /// ITEMS LIST
                            ListView.separated(
                              reverse: true,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: serviceItems.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final item = serviceItems[index];

                                return Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.black.withOpacity(
                                          0.03,
                                        ),
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
                                        color: AppColors.darkGreen.withOpacity(
                                          0.1,
                                        ),
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
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
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
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

                      /// CUSTOMER  SIGNATURE
                      SectionWidget(
                        icon: Icons.draw_outlined,
                        title: nameController.text.isEmpty
                            ? "Customer Signature"
                            : "${nameController.text} Signature",
                        child: signatureBox(
                          customerController,
                          customerSignBytes,
                          isAdminView: widget.isEdit && isAdmin,
                        ),
                      ),
                      const SizedBox(height: 20),

                      /// TECHNICIAN SIGNATURE
                      SectionWidget(
                        icon: Icons.draw_outlined,
                        title:
                            "${widget.technicianName ?? "Technician"} Signature",
                        child: signatureBox(
                          techController,
                          techSignBytes,
                          isAdminView: widget.isEdit && isAdmin,
                        ),
                      ),

                      /// ADMIN SIGNATURE
                      if (isAdmin) ...[
                        const SizedBox(height: 20),
                        SectionWidget(
                          icon: Icons.draw_outlined,
                          title: "${loggedUser?.name ?? "Admin"} Signature",
                          child: signatureBox(adminController, adminSignBytes),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: isLoading
            ? SizedBox(
                height: 50,
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.darkGreen),
                ),
              ) // 🔥 loader
            : CustomElevatedButton(
                text: isAdmin
                    ? "Complete Form"
                    : widget.isEdit
                    ? "Update Form"
                    : "Submit Form",
                onPressed: submitForm,
              ),
      ),
    );
  }

  Widget signatureBox(
    SignatureController controller,
    Uint8List? existingBytes, {
    bool isAdminView = false, // 🔥 NEW
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          /// ✅ ADMIN VIEW → ONLY IMAGE
          if (isAdminView && existingBytes != null)
            SizedBox(
              height: 150,
              width: double.infinity,
              child: Image.memory(existingBytes, fit: BoxFit.scaleDown),
            )
          /// ✅ NORMAL FLOW
          else ...[
            existingBytes != null && controller.isEmpty
                ? Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Image.memory(existingBytes, fit: BoxFit.scaleDown),
                  )
                : Signature(
                    controller: controller,
                    height: 150,
                    backgroundColor: Colors.grey.shade100,
                  ),

            /// ❌ ADMIN ma hide karvu
            if (!isAdminView)
              CustomIconButton(
                label: "Clear",
                textColor: AppColors.red,
                onTap: () {
                  controller.clear();
                  setState(() {});
                },
              ),
          ],
        ],
      ),
    );
  }
}
