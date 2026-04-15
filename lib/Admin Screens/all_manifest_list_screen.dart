import 'dart:convert';
import 'package:doc_delete/Admin%20Screens/image_preview.dart';
import 'package:doc_delete/Models/customer_model.dart';
import 'package:doc_delete/Models/get_all_manifest_model.dart';
import 'package:doc_delete/Models/user_model.dart';
import 'package:doc_delete/PDF/manifest_pdf.dart';
import 'package:doc_delete/PDF/pdf_preview.dart';
import 'package:doc_delete/Technician%20Screens/service_form_screen.dart';
import 'package:doc_delete/Widgets/confirm_dialog.dart';
import 'package:doc_delete/Widgets/custom_appbar.dart';
import 'package:doc_delete/Widgets/custom_iconbutton.dart';
import 'package:doc_delete/config/api_urls.dart';
import 'package:doc_delete/utils/session_manager.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

class AllManifestListScreen extends StatefulWidget {
  const AllManifestListScreen({super.key});

  @override
  State<AllManifestListScreen> createState() => _AllManifestListScreenState();
}

class _AllManifestListScreenState extends State<AllManifestListScreen>
    with SingleTickerProviderStateMixin {
  List<GetAllManifestModel> manifestList = [];
  List<GetAllManifestModel> filteredList = [];
  bool isManifestLoading = false;
  List<UserModel> technicians = [];
  int? selectedTechnicianId;
  List<CustomerModel> customers = [];
  int? selectedCustomerId;
  String selectedFilter = "pending";
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    fetchTechnicians();
    fetchCustomers();
    fetchAllManifests();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _applyFilter() {
    if (selectedFilter == "pending") {
      filteredList = manifestList.where((m) => m.completed == 0).toList();
    } else if (selectedFilter == "completed") {
      filteredList = manifestList.where((m) => m.completed == 1).toList();
    } else {
      filteredList = List.from(manifestList);
    }
    setState(() {});
    _animController.forward(from: 0);
  }

  Future<void> fetchAllManifests() async {
    setState(() => isManifestLoading = true);
    try {
      int? adminID = await SessionManager.getUserId();
      String url = "${ApiUrls.getAllManifest}?is_admin=$adminID";
      if (selectedTechnicianId != null) {
        url += "&technician_id=$selectedTechnicianId";
      }
      if (selectedCustomerId != null) url += "&customer_id=$selectedCustomerId";

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
          manifestList = list;
          _applyFilter();
        }
      }
    } catch (e) {
      debugPrint("Manifest Error: $e");
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
          final data = json["data"];
          final List rawList = data is List
              ? data
              : (data["users"] as List? ?? []);
          setState(() {
            technicians = rawList.map((e) => UserModel.fromJson(e)).toList();
            technicians.sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );
          });
        }
      }
    } catch (e) {
      debugPrint("Technician Error: $e");
    }
  }

  Future<void> fetchCustomers() async {
    try {
      final res = await http.get(Uri.parse(ApiUrls.customer));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (json["status"] == true) {
          final data = json["data"];
          final List rawList = data is List
              ? data
              : (data["customers"] as List? ?? []);
          setState(() {
            customers = rawList.map((e) => CustomerModel.fromJson(e)).toList();
            customers.sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );
          });
        }
      }
    } catch (e) {
      debugPrint("Customer Error: $e");
    }
  }

  Map<String, List<GetAllManifestModel>> groupByDate(
    List<GetAllManifestModel> list,
  ) {
    Map<String, List<GetAllManifestModel>> grouped = {};
    for (var m in list) {
      if (!grouped.containsKey(m.serviceDate)) grouped[m.serviceDate] = [];
      grouped[m.serviceDate]!.add(m);
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

  Future<void> deleteManifest(int manifestId) async {
    int? userID = await SessionManager.getUserId();
    try {
      final response = await http.delete(
        Uri.parse(ApiUrls.manifest),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "id": manifestId,
          "technician_id": userID,
          "is_admin": userID,
        }),
      );
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
          manifestList.removeWhere((m) => m.manifestID == manifestId);
          _applyFilter();
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
      }
    }
  }

  int get pendingCount => manifestList.where((m) => m.completed == 0).length;
  int get completedCount => manifestList.where((m) => m.completed == 1).length;

  void _showImagesBottomSheet(GetAllManifestModel m) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(40),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 900,
              height: 600,
              color: Colors.white,
              child: ImageViewerSheet(
                manifestNo: m.manifestNo,
                photos: m.photos,
              ),
            ),
          ),
        );
      },
    );
  }

  // ✅ AFTER (fixed)
  Future<void> _createAllPdfForGroup(
    List<GetAllManifestModel> manifests,
  ) async {
    setState(() => isManifestLoading = true);
    try {
      final futures = manifests.map(
        (m) => getManifestById(manifestId: m.manifestID), // ✅ correct function
      );
      final results = await Future.wait(futures);

      List<GetAllManifestModel> fullManifests = results
          .whereType<GetAllManifestModel>()
          .toList();

      // ✅ tech names from actual fetched manifests
      final techNames = fullManifests.map((m) => m.technicianName).toList();

      if (fullManifests.isEmpty) {
        setState(() => isManifestLoading = false);
        return;
      }

      final combinedBytes = await generateAllManifestsPdf(
        fullManifests,
        technicianNames: techNames,
      );

      setState(() => isManifestLoading = false);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              WebPdfViewerScreen(bytes: combinedBytes, customerEmail: null),
        ),
      );
    } catch (e) {
      setState(() => isManifestLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: AppColors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CustomAppBar(title: "Manifests"),
        Expanded(
          child: isManifestLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.darkGreen),
                )
              : CustomScrollView(
                  slivers: [
                    /// ─── FILTERS ───
                    SliverToBoxAdapter(child: _filtersSection()),

                    /// ─── SEGMENT TABS ───
                    SliverToBoxAdapter(child: _segmentTabs()),

                    const SliverToBoxAdapter(child: SizedBox(height: 8)),

                    /// ─── COUNT ROW ───
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 4,
                        ),
                        child: Row(
                          children: [
                            Text(
                              "${filteredList.length} ${selectedFilter == 'pending' ? 'Pending' : 'Completed'} Manifest${filteredList.length == 1 ? '' : 's'}",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.darkGreen,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 8)),

                    /// ─── EMPTY STATE ───
                    if (filteredList.isEmpty)
                      SliverFillRemaining(child: _emptyState())
                    else
                      _groupedList(),

                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                ),
        ),
      ],
    );
  }

  /// ── FILTER SECTION ──
  Widget _filtersSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _dropdownBox(
              hint: "All Technicians",
              icon: Icons.person_outline,
              value: selectedTechnicianId,
              items: [
                const DropdownMenuItem<int>(
                  value: null,
                  child: Text("All Technicians"),
                ),
                ...technicians.map(
                  (t) =>
                      DropdownMenuItem<int>(value: t.id, child: Text(t.name)),
                ),
              ],
              onChanged: (v) {
                setState(() {
                  selectedTechnicianId = v;
                  selectedCustomerId = null;
                });
                fetchAllManifests();
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _dropdownBox(
              hint: "All Customers",
              icon: Icons.business_outlined,
              value: selectedCustomerId,
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text("All Customers"),
                ),
                ...customers.map(
                  (c) =>
                      DropdownMenuItem<int?>(value: c.id, child: Text(c.name)),
                ),
              ],
              onChanged: (v) {
                setState(() {
                  selectedCustomerId = v;
                  selectedTechnicianId = null;
                });
                fetchAllManifests();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropdownBox<T>({
    required String hint,
    required IconData icon,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.darkGreen),
          const SizedBox(width: 6),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                key: ValueKey(value),
                value: value,
                dropdownColor: Colors.white,
                isExpanded: true,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF2D3436),
                  fontWeight: FontWeight.w500,
                ),
                items: items,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ── SEGMENT TABS ──
  Widget _segmentTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            _tabItem(
              label: "Pending",
              value: "pending",
              activeColor: const Color(0xFFE67E22),
            ),
            _tabItem(
              label: "Completed",
              value: "completed",
              activeColor: AppColors.darkGreen,
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabItem({
    required String label,
    required String value,
    required Color activeColor,
  }) {
    final bool isActive = selectedFilter == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => selectedFilter = value);
          _applyFilter();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: isActive ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isActive ? Colors.white : Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ── GROUPED LIST ──
  Widget _groupedList() {
    final grouped = groupByDate(filteredList);
    final dates = grouped.keys.toList();
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final date = dates[index];
        final manifests = grouped[date]!;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 3,
                        height: 16,
                        decoration: BoxDecoration(
                          color: AppColors.darkGreen,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('MMMM d, yyyy').format(DateTime.parse(date)),
                        style: const TextStyle(
                          color: Color(0xFF2D3436),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                  if (selectedFilter == "completed")
                    GestureDetector(
                      onTap: () => _createAllPdfForGroup(manifests),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.darkGreen.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.darkGreen.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.picture_as_pdf_outlined,
                              size: 13,
                              color: AppColors.darkGreen,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "Create All PDF",
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.darkGreen,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              ...manifests.asMap().entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _manifestCard(e.value, e.key),
                ),
              ),
            ],
          ),
        );
      }, childCount: dates.length),
    );
  }

  /// ── MANIFEST CARD ──
  Widget _manifestCard(GetAllManifestModel m, int cardIndex) {
    final bool isCompleted = m.completed == 1;
    final Color accentColor = isCompleted
        ? AppColors.darkGreen
        : const Color(0xFFE67E22);

    return GestureDetector(
      onTap: () async {
        if (m.completed == 1) {
          setState(() => isManifestLoading = true);
          try {
            final manifest = await getManifestById(manifestId: m.manifestID);
            if (manifest == null) {
              setState(() => isManifestLoading = false);
              return;
            }
            final bytes = await generateManifestPdf(
              manifest,
              technicianName: m.technicianName,
            );
            setState(() => isManifestLoading = false);
            if (!mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => WebPdfViewerScreen(
                  bytes: bytes,
                  customerEmail: m.customer.email,
                ),
              ),
            );
          } catch (e) {
            setState(() => isManifestLoading = false);
          }
        } else {
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ServiceFormScreen(
                isEdit: true,
                existManifest: m,
                technicianName: m.technicianName,
              ),
            ),
          ).then((_) => fetchAllManifests());
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.08),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                /// ─── LEFT ACCENT BAR ───
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                ),

                /// ─── CARD CONTENT ───
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            /// Avatar
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: accentColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  m.customer.name.isNotEmpty
                                      ? m.customer.name[0].toUpperCase()
                                      : "?",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: accentColor,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),

                            /// Name + manifest no
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m.customer.name,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF2D3436),
                                      letterSpacing: -0.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "#${m.manifestNo}",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: accentColor,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Row(
                              children: [
                                /// View Photos
                                CustomIconButton(
                                  icon: Icons.photo_library_outlined,
                                  iconSize: 20,
                                  label: "Photos",
                                  padding: EdgeInsets.all(6),
                                  color: AppColors.darkGreen.withOpacity(0.15),
                                  textColor: AppColors.darkGreen,
                                  onTap: () => _showImagesBottomSheet(m),
                                ),
                                if (!isCompleted) ...[
                                  const SizedBox(width: 6),
                                  CustomIconButton(
                                    icon: Icons.delete_outline_rounded,
                                    padding: EdgeInsets.all(4),
                                    color: AppColors.red.withOpacity(0.15),
                                    textColor: AppColors.red,
                                    onTap: () {
                                      ConfirmDialog.show(
                                        context: context,
                                        title: "Delete Manifest",
                                        message:
                                            "Are you sure you want to delete ${m.manifestNo}?",
                                        confirmText: "Delete",
                                        confirmColor: AppColors.red,
                                        onConfirm: () =>
                                            deleteManifest(m.manifestID),
                                      );
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 5),
                        Divider(color: Colors.grey.shade200, height: 1),
                        const SizedBox(height: 5),

                        /// ─── BOTTOM ROW: Date + Technician + Actions ───
                        Row(
                          children: [
                            /// Date chip
                            _infoChip(
                              icon: Icons.calendar_today_outlined,
                              label: DateFormat(
                                'MMM d, yyyy',
                              ).format(DateTime.parse(m.serviceDate)),
                            ),
                            const SizedBox(width: 8),

                            /// Technician chip
                            Expanded(
                              child: _infoChip(
                                icon: Icons.person_outline_rounded,
                                label: m.technicianName,
                                expand: true,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoChip({
    required IconData icon,
    required String label,
    bool expand = false,
  }) {
    Widget chip = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.grey.shade500),
        const SizedBox(width: 4),
        expand
            ? Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              )
            : Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
      ],
    );
    return expand
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [Flexible(child: chip)],
          )
        : chip;
  }

  /// ── EMPTY STATE ──
  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: AppColors.darkGreen.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.description_outlined,
              size: 42,
              color: AppColors.darkGreen.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "No ${selectedFilter == 'pending' ? 'Pending' : 'Completed'} Manifests",
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2D3436),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            selectedFilter == 'pending'
                ? "All manifests are completed!"
                : "No completed manifests yet.",
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
