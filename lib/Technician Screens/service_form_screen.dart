import 'dart:convert';
import 'dart:io';
import 'package:doc_delete/Models/customer_model.dart';
import 'package:doc_delete/Models/department_model.dart';
import 'package:doc_delete/Models/get_all_manifest_model.dart';
import 'package:doc_delete/Models/images_model.dart';
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
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:signature/signature.dart';
import 'dart:html' as html;

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

  DepartmentModel? selectedDepartment;
  List<DepartmentModel> departments = [];

  List<ServiceItemModel> serviceItems = [];

  List<PhotoModel> photos = [];
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
  int? editingIndex;

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
  TextEditingController customDepartmentController = TextEditingController();

  SignatureController customerController = SignatureController(
    penStrokeWidth: 3,
  );
  SignatureController techController = SignatureController(penStrokeWidth: 3);
  SignatureController adminController = SignatureController(penStrokeWidth: 3);

  // ✅ String — no decode, no freeze
  String? customerSignBase64;
  String? techSignBase64;
  String? adminSignBase64;
  String? customDepartmentName;

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
    setState(() => loggedUser = user);
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

    /// ✅ DROPDOWN SELECT
    final match = customer.where((c) => c.id == m.customer.id).toList();
    selectedClient = match.isNotEmpty ? match.first : null;

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

    departments = selectedClient?.departments ?? [];

    photos = m.photos.map((p) {
      final img = p.image is String
          ? base64Decode(
              p.image.contains(',') ? p.image.split(',').last : p.image,
            )
          : p.image;
      return PhotoModel(image: img, lat: p.lat, lng: p.lng);
    }).toList();

    // ✅ No base64Decode — directly String assign, zero freeze
    if (m.customerSign != null && m.customerSign!.isNotEmpty) {
      customerSignBase64 = m.customerSign;
    }
    if (m.technicianSign != null && m.technicianSign!.isNotEmpty) {
      techSignBase64 = m.technicianSign;
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
          customer.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
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

  Future<DepartmentModel?> _saveDepartment(String name) async {
    try {
      if (selectedClient == null) return null;

      final response = await http.post(
        Uri.parse(ApiUrls.departments),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "department_name": name,
          "customer_id": selectedClient!.id,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["status"] == true) {
          // ✅ data field hoy to seedho use karo
          if (data["data"] != null) {
            return DepartmentModel.fromJson(data["data"]);
          }

          // ✅ data nathi to customer na departments refetch karo
          final freshResponse = await http.get(
            Uri.parse(
              "${ApiUrls.departments}?customer_id=${selectedClient!.id}",
            ),
          );

          if (freshResponse.statusCode == 200) {
            final freshData = jsonDecode(freshResponse.body);
            if (freshData["status"] == true && freshData["data"] != null) {
              final List deptList = freshData["data"];
              // ✅ Name match karke actual DB id walo department lo
              final match = deptList
                  .map((e) => DepartmentModel.fromJson(e))
                  .where(
                    (d) => d.departmentName.toLowerCase() == name.toLowerCase(),
                  )
                  .toList();
              if (match.isNotEmpty) return match.first;
            }
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint("Save Department Error: $e");
      return null;
    }
  }

  Future<void> addItem() async {
    if (!(destruction ||
        storage ||
        eWaste ||
        serviceTicket ||
        customController.text.isNotEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select at least one service type"),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

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

    // ✅ Other department selected — custom name validate & save
    if (selectedDepartment!.id == 1) {
      if (customDepartmentController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enter department name")),
        );
        return;
      }

      // ✅ API call — department table ma save
      final newDept = await _saveDepartment(
        customDepartmentController.text.trim(),
      );

      if (newDept == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to save department"),
            backgroundColor: AppColors.red,
          ),
        );
        return;
      }

      // ✅ Local list ma pan add karo — dropdown ma dikhe
      setState(() {
        departments.add(newDept);
        selectedClient?.departments.add(newDept);
        selectedDepartment = newDept;
      });
    }

    List<String> types = [];
    if (destruction) types.add("DOCUMENT DESTRUCTION");
    if (storage) types.add("DOCUMENT STORAGE");
    if (eWaste) types.add("E-WASTE");
    if (serviceTicket) types.add("SERVICE DELIVERY TICKET");
    if (customController.text.isNotEmpty) types.add(customController.text);

    String serviceType = types.join(", ");

    ServiceItemModel item = ServiceItemModel(
      departmentId: selectedDepartment!.id!,
      unitType: unitType!,
      measure: measureController.text,
      quantity: quantityController.text,
      serviceType: serviceType,
    );

    setState(() {
      if (editingIndex != null) {
        serviceItems[editingIndex!] = item;
        editingIndex = null;
      } else {
        serviceItems.add(item);
      }

      unitType = null;
      boxSize = null;
      measureController.clear();
      quantityController.clear();
      selectedDepartment = null;
      customController.clear();
      customDepartmentController.clear(); // ✅ clear
      destruction = false;
      storage = false;
      eWaste = false;
      serviceTicket = false;
    });
  }

  void loadItemForEdit(int index) {
    final item = serviceItems[index];

    setState(() {
      editingIndex = index;

      // ✅ બધી values fill કરો
      unitType = item.unitType;
      measureController.text = item.measure;
      quantityController.text = item.quantity;

      // ✅ Department select કરો
      final match = departments
          .where((d) => d.id == item.departmentId)
          .toList();
      selectedDepartment = match.isNotEmpty ? match.first : null;

      // ✅ Service type checkboxes set કરો
      destruction = item.serviceType.contains("DOCUMENT DESTRUCTION");
      storage = item.serviceType.contains("DOCUMENT STORAGE");
      eWaste = item.serviceType.contains("E-WASTE");
      serviceTicket = item.serviceType.contains("SERVICE DELIVERY TICKET");

      // ✅ Custom description
      final knownTypes = [
        "DOCUMENT DESTRUCTION",
        "DOCUMENT STORAGE",
        "E-WASTE",
        "SERVICE DELIVERY TICKET",
      ];
      final custom = item.serviceType
          .split(", ")
          .where((t) => !knownTypes.contains(t))
          .join(", ");
      customController.text = custom;

      // ✅ Box size handle
      if (item.unitType == "BOXES") {
        boxSize = item.measure;
      }
    });

    // ✅ Scroll to top of service section — optional
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Item loaded for editing"),
        backgroundColor: AppColors.darkGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<Map<String, dynamic>?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint("❌ Location Service Disabled");
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint("❌ Location Permission Denied");
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint("❌ Location Permission Denied Forever");
        return null;
      }

      // Timeout સાથે મેળવો (મોબાઈલ પર અટકી ન જાય)
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      return {
        "latitude": position.latitude,
        "longitude": position.longitude,
        "address":
            "Lat: ${position.latitude.toStringAsFixed(4)}, "
            "Lng: ${position.longitude.toStringAsFixed(4)}",
      };
    } catch (e) {
      debugPrint("❌ Location Error: $e");
      return null;
    }
  }

  // ✅ Web માટે — dart:html વાપરીને
  Future<void> pickImageWeb({bool useCamera = false}) async {
    final input = html.FileUploadInputElement();
    input.accept = 'image/*';

    // ✅ capture માટે setAttribute વાપરો
    if (useCamera) input.setAttribute('capture', 'environment');

    html.document.body!.append(input);

    input.click();

    await input.onChange.first;

    input.remove();

    final files = input.files;
    if (files == null || files.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Getting Photo..."),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );

    final reader = html.FileReader();
    reader.readAsArrayBuffer(files[0]);
    await reader.onLoad.first;

    final bytes = reader.result as Uint8List;
    final locationData = await getCurrentLocation();

    if (!mounted) return;
    setState(() {
      photos.add(
        PhotoModel(
          image: bytes,
          lat: locationData?['latitude'],
          lng: locationData?['longitude'],
        ),
      );
    });

    final lastPhoto = photos.last;
    if (lastPhoto.lat == null || lastPhoto.lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠️ Location not available. Check GPS & Permission"),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ✅ Native માટે — image_picker વાપરીને
  Future<void> takeImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(
      source: source,
      imageQuality: 80,
    );

    if (image == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Getting Photo..."),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );

    final locationData = await getCurrentLocation();

    if (!mounted) return;
    setState(() {
      photos.add(
        PhotoModel(
          image: File(image.path),
          lat: locationData?['latitude'],
          lng: locationData?['longitude'],
        ),
      );
    });

    final lastPhoto = photos.last;
    if (lastPhoto.lat == null || lastPhoto.lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠️ Location not available. Check GPS & Permission"),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ✅ pickImage — Web અને Native બંને handle
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
                  // ✅ Web = dart:html | Native = image_picker
                  if (kIsWeb) {
                    pickImageWeb(useCamera: true);
                  } else {
                    takeImage(ImageSource.camera);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo),
                title: const Text("Gallery"),
                onTap: () {
                  Navigator.pop(context);
                  if (kIsWeb) {
                    pickImageWeb(useCamera: false);
                  } else {
                    takeImage(ImageSource.gallery);
                  }
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
    return base64Encode(compressedBytes);
  }

  Future<List<Map<String, dynamic>>> buildPhotos() async {
    List<Map<String, dynamic>> list = [];

    for (var photo in photos) {
      try {
        String base64 = "";

        if (photo.image is File) {
          base64 = await compressAndEncodeImage(photo.image);
        } else if (photo.image is Uint8List) {
          final compressed = await FlutterImageCompress.compressWithList(
            photo.image,
            quality: 60,
            minWidth: 1024,
            minHeight: 1024,
          );
          base64 = base64Encode(compressed);
        }

        list.add({"image": base64, "lat": photo.lat, "lng": photo.lng});
      } catch (e) {
        debugPrint("Image processing error: $e");
      }
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
        if (data['data'] is List) {
          final list = data['data'] as List;
          if (list.isNotEmpty) return GetAllManifestModel.fromJson(list[0]);
        } else if (data['data'] is Map) {
          return GetAllManifestModel.fromJson(data['data']);
        }
      }
    }
    return null;
  }

  Future<void> handleResponse(http.Response response) async {
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

      /// ✅ Admin edit complete → direct PDF open
      if (widget.isEdit && isAdmin && widget.existManifest != null) {
        setState(() {
          isPageLoading = true;
        });
        final manifest = await getManifestById(
          manifestId: widget.existManifest!.manifestID,
        );

        if (manifest == null) {
          setState(() => isPageLoading = false);
          return;
        }
        final bytes = await generateManifestPdf(
          manifest,
          technicianName: widget.existManifest!.technicianName,
        );
        setState(() {
          isPageLoading = false;
        });
        Navigator.pop(context, true);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => WebPdfViewerScreen(bytes: bytes)),
        );
      } else {
        Navigator.pop(context, true);
      }
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

    String? customerSign;
    String? techSign;

    customerSign = customerSignBase64;
    techSign = techSignBase64;

    customerSign = customerController.isNotEmpty
        ? await getSignatureBase64(customerController)
        : customerSignBase64;

    techSign = techController.isNotEmpty
        ? await getSignatureBase64(techController)
        : techSignBase64;

    final request = ManifestModel(
      id: widget.existManifest?.manifestID,
      technicianId: technicianId,
      customerId: selectedClient?.id,
      customerName: nameController.text,
      serviceDate: selectedDate.toString(),
      serviceItems: serviceItems,
      images: images,
      customerSign: customerSign,
      technicianSign: techSign,
      adminCompleted: isAdmin ? true : false,
    );

    final response = await http.put(
      Uri.parse(ApiUrls.manifest),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(request.toJson()),
    );

    handleResponse(response);
  }

  Future<void> _updateField(String fieldName, String value) async {
    if (selectedClient == null) {
      showError("Please select a customer first");
      return;
    }

    try {
      final response = await http.put(
        Uri.parse(ApiUrls.customer),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"id": selectedClient!.id, fieldName: value}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data["status"] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("$fieldName updated successfully"),
            backgroundColor: AppColors.darkGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        showError(data["message"] ?? "Failed to update $fieldName");
      }
    } catch (e) {
      showError("Error: $e");
    }
  }

  Future<void> submitForm() async {
    if (!validateForm()) return;
    if (isLoading) return;

    setState(() => isLoading = true);

    try {
      if (widget.isEdit) {
        await updateManifest();
      } else {
        await createManifest();
      }
    } catch (e) {
      showError("Error: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  bool validateForm() {
    if (nameController.text.isEmpty) {
      showError("Please add customer name");
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

    // ✅ String null check
    final hasCustomerSign =
        customerController.isNotEmpty || customerSignBase64 != null;
    if (!hasCustomerSign) {
      showError("Please add customer signature");
      return false;
    }

    final hasTechSign = techController.isNotEmpty || techSignBase64 != null;
    if (!hasTechSign) {
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
                                        : selectedClient,
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
                                      style: const TextStyle(
                                        color: Colors.grey,
                                      ),
                                    ),
                                    items: customer.map((client) {
                                      return DropdownMenuItem(
                                        value: client,
                                        child: Text(client.name),
                                      );
                                    }).toList(),
                                    onChanged: customer.isEmpty
                                        ? null
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
                                      setState(() => customer.add(result));
                                    }
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            textFormField(
                              labelText: "Customer Name",
                              controller: nameController,
                              onChanged: (val) => setState(() {}),
                            ),

                            _buildRow(
                              title: "Address",
                              controller: addressController,
                              onUpdateTap: () => _updateField(
                                "address",
                                addressController.text.trim(),
                              ),
                            ),
                            _buildRow(
                              title: "Contact Person",
                              controller: contactController,
                              onUpdateTap: () => _updateField(
                                "contact_person",
                                contactController.text.trim(),
                              ),
                            ),
                            _buildRow(
                              title: "Phone Number",
                              controller: phoneController,
                              onUpdateTap: () => _updateField(
                                "phone",
                                phoneController.text.trim(),
                              ),
                            ),
                            _buildRow(
                              title: "Email Address",
                              controller: emailController,
                              onUpdateTap: () => _updateField(
                                "email",
                                emailController.text.trim(),
                              ),
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

                            if (unitType != "BOXES")
                              textFormField(
                                labelText: "Measure / Volume",
                                controller: measureController,
                              ),

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

                            DropdownButtonFormField<DepartmentModel>(
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
                              items: [
                                ...departments.map((dept) {
                                  return DropdownMenuItem<DepartmentModel>(
                                    value: dept,
                                    child: Text(dept.departmentName),
                                  );
                                }),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  selectedDepartment = value;
                                  customDepartmentName = null; // reset
                                });
                              },
                            ),

                            // ✅ "Other" select થાય ત્યારે જ TextField show થશે
                            if (selectedDepartment?.id == 1) ...[
                              const SizedBox(height: 12),
                              textFormField(
                                labelText: "Enter Department Name",
                                controller: customDepartmentController,
                              ),
                            ],

                            SizedBox(
                              height: selectedDepartment?.id == 1 ? 8 : 20,
                            ),
                            Row(
                              children: [
                                CustomIconButton(
                                  backgroundColor: AppColors.darkGreen,
                                  textColor: AppColors.white,
                                  icon: editingIndex != null
                                      ? Icons.check
                                      : Icons.add,
                                  label: editingIndex != null
                                      ? "Update Item"
                                      : "Add Item and Department",
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  onTap: addItem,
                                ),
                                const SizedBox(width: 10),
                                // ✅ Cancel edit button — edit mode માં show કરો
                                if (editingIndex != null) ...[
                                  CustomIconButton(
                                    borderColor: AppColors.red,
                                    textColor: AppColors.red,
                                    icon: Icons.close,
                                    label: "Cancel Edit",
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    onTap: () {
                                      setState(() {
                                        editingIndex = null;
                                        unitType = null;
                                        boxSize = null;
                                        measureController.clear();
                                        quantityController.clear();
                                        selectedDepartment = null;
                                        customController.clear();
                                        destruction = false;
                                        storage = false;
                                        eWaste = false;
                                        serviceTicket = false;
                                      });
                                    },
                                  ),
                                ],
                              ],
                            ),
                            if (serviceItems.isNotEmpty)
                              const SizedBox(height: 20),

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
                                      color: AppColors.darkGreen.withOpacity(
                                        0.5,
                                      ),
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
                                    onTap: () => loadItemForEdit(index),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
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
                                    title: Text(
                                      getDepartmentName(item.departmentId),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 3),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.serviceType,
                                            style: const TextStyle(
                                              fontSize: 14,
                                            ),
                                          ),
                                          SizedBox(height: 3),
                                          Row(
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
                                                    ? " | Box Size: ${item.measure} | Qty: ${item.quantity}"
                                                    : " | Measure: ${item.measure} | Qty: ${item.quantity}",
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey.shade800,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    trailing: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(20),
                                        onTap: () => setState(
                                          () => serviceItems.removeAt(index),
                                        ),
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
                          onPressed: pickImage,
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

                            /// PHOTOS Section ma GridView.builder replace karo
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
                                final photo = photos[index];

                                return Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: AspectRatio(
                                        aspectRatio: 1,
                                        child: _buildPhotoWidget(
                                          photo.image,
                                        ), // ← New Helper
                                      ),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: GestureDetector(
                                        onTap: () => setState(
                                          () => photos.removeAt(index),
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            color: Colors.white,
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

                      /// CUSTOMER & TECHNICIAN SIGNATURE
                      SectionWidget(
                        icon: Icons.draw_outlined,
                        title: "Customer & Technician Signature",
                        child: Column(
                          children: [
                            signatureBox(
                              controller: customerController,
                              label: nameController.text.isEmpty
                                  ? "Customer Signature"
                                  : "${nameController.text} Signature",
                              roleLabel: "Required",
                              icon: Icons.person_outline_rounded,
                              existingBase64: customerSignBase64, // ✅ String
                              isAdminView: widget.isEdit && isAdmin,
                              onReSigned: () =>
                                  setState(() => customerSignBase64 = null),
                            ),
                            const SizedBox(height: 20),
                            signatureBox(
                              controller: techController,
                              label:
                                  "${widget.technicianName ?? loggedUser?.name ?? "Technician"} Signature",
                              roleLabel: "Required",
                              icon: Icons.person_outline_rounded,
                              existingBase64: techSignBase64, // ✅ String
                              isAdminView: widget.isEdit && isAdmin,
                              onReSigned: () =>
                                  setState(() => techSignBase64 = null),
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
            ? const SizedBox(
                height: 50,
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.darkGreen),
                ),
              )
            : CustomElevatedButton(
                text: isAdmin
                    ? "Approve"
                    : widget.isEdit
                    ? "Update Form"
                    : "Submit Form",
                onPressed: submitForm,
              ),
      ),
    );
  }

  Widget _buildPhotoWidget(dynamic image) {
    if (image is Uint8List) {
      return Image.memory(image, fit: BoxFit.cover);
    } else if (image is File) {
      return Image.file(image, fit: BoxFit.cover);
    } else if (image is String && image.isNotEmpty) {
      // ✅ Edit mode ma base64 string aave che
      return Image.memory(
        base64Decode(image.contains(',') ? image.split(',').last : image),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.broken_image_rounded, color: Colors.red, size: 40),
      );
    } else {
      return const Icon(Icons.broken_image, color: Colors.red, size: 40);
    }
  }

  Widget signatureBox({
    required SignatureController controller,
    required String label,
    required String roleLabel,
    required IconData icon,
    String? existingBase64,
    bool isAdminView = false,
    VoidCallback? onReSigned,
  }) {
    final bool showExisting = existingBase64 != null && controller.isEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAdminView
              ? AppColors.darkGreen.withOpacity(0.4)
              : Colors.grey.shade200,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkGreen.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// ─── HEADER ───
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isAdminView
                  ? AppColors.darkGreen.withOpacity(0.08)
                  : Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade100, width: 1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.darkGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: AppColors.darkGreen),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2D3436),
                      ),
                    ),
                    Text(
                      roleLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const Spacer(),

                /// ✅ Signed badge
                if (existingBase64 != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.darkGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 12,
                          color: AppColors.darkGreen,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "Signed",
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.darkGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          /// ─── SIGNATURE AREA ───
          Padding(
            padding: const EdgeInsets.all(12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: isAdminView && existingBase64 != null
                  /// 🔒 ADMIN VIEW — only image, no re-sign
                  ? Container(
                      height: 160,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Image.network(
                        "data:image/png;base64,$existingBase64",
                        fit: BoxFit.scaleDown,
                      ),
                    )
                  : showExisting
                  /// 🖼 Existing signature — Re-sign option
                  ? Stack(
                      children: [
                        Container(
                          height: 160,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Image.network(
                            "data:image/png;base64,$existingBase64",
                            fit: BoxFit.scaleDown,
                          ),
                        ),
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () {
                              controller.clear();
                              onReSigned?.call();
                              setState(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.red.withOpacity(0.3),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.refresh_rounded,
                                    size: 13,
                                    color: AppColors.red,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "Re-sign",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.red,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  /// ✏️ Draw signature pad
                  : Stack(
                      children: [
                        Signature(
                          controller: controller,
                          height: 160,
                          backgroundColor: Colors.grey.shade50,
                        ),
                        if (controller.isEmpty)
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.draw_outlined,
                                  size: 28,
                                  color: Colors.grey.shade300,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "Sign here",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade400,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (!isAdminView)
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () {
                                controller.clear();
                                setState(() {});
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.red.withOpacity(0.3),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.06),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.clear_rounded,
                                      size: 13,
                                      color: AppColors.red,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "Clear",
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.red,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow({
    required String title,
    required TextEditingController controller,
    required VoidCallback onUpdateTap,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: textFormField(
            labelText: title,
            controller: controller,
            maxLines: null,
            keyboardType: TextInputType.multiline,
          ),
        ),
        const SizedBox(width: 10),
        CustomIconButton(
          label: "UPDATE",
          backgroundColor: AppColors.darkGreen,
          textColor: AppColors.white,
          onTap: onUpdateTap,
        ),
      ],
    );
  }
}
