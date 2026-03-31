import 'package:doc_delete/Models/customer_model.dart';
import 'package:doc_delete/Models/department_model.dart';
import 'package:doc_delete/Models/service_model.dart';

class GetAllManifestModel {
  final int manifestID;
  final String manifestNo;
  final String customerName;
  final String serviceDate;
  final String technicianName;
  final String? createdAt;

  final CustomerModel customer;

  final List<DepartmentModel1> departments;
  final List<ServiceItemModel> units;
  final List<String> photos;
  final String? customerSign;
  final String? technicianSign;

  GetAllManifestModel({
    required this.manifestID,
    required this.manifestNo,
    required this.customerName,
    required this.serviceDate,
    this.createdAt,
    required this.technicianName,
    required this.customer,
    required this.departments,
    required this.units,
    required this.photos,
    this.customerSign,
    this.technicianSign,
  });

  factory GetAllManifestModel.fromJson(Map<String, dynamic> json) {
    return GetAllManifestModel(
      manifestID: int.tryParse(json['manifest_id'].toString()) ?? 0,
      manifestNo: json['manifest_no']?.toString() ?? "",
      customerName: json['customer_name']?.toString() ?? "",
      serviceDate: json['service_date']?.toString() ?? "",
      createdAt: json['created_at']?.toString(),
      technicianName: json['technician_name']?.toString() ?? "",
      customer: CustomerModel.fromJson(json['customer'] ?? {}),
      departments: (json['departments'] as List? ?? [])
          .map((e) => DepartmentModel1.fromJson(e))
          .toList(),
      units: (json['units'] as List? ?? [])
          .map((e) => ServiceItemModel.fromJson(e))
          .toList(),
      photos: (json['photos'] as List? ?? []).map((e) => e.toString()).toList(),
      customerSign: json['customer_sign']?.toString(),
      technicianSign: json['technician_sign']?.toString(),
    );
  }
}
