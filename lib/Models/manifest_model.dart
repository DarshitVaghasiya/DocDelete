import 'package:doc_delete/Models/service_model.dart';

class ManifestModel {
  final int? id;
  final int? technicianId;
  final int? customerId;
  final String? customerName;
  final String serviceDate;
  final List<ServiceItemModel> serviceItems;
  final List<Map<String, dynamic>> images;
  final String? customerSign;
  final String? technicianSign;
  final bool? adminCompleted;

  ManifestModel({
    this.id,
    this.technicianId,
    required this.customerId,
    this.customerName,
    required this.serviceDate,
    required this.serviceItems,
    required this.images,
    required this.customerSign,
    required this.technicianSign,
    this.adminCompleted,
  });

  Map<String, dynamic> toJson() {
    return {
      "manifest_id": id,
      "technician_id": technicianId,
      "customer_id": customerId,
      "customer_name": customerName,
      "service_date": serviceDate,
      "service_items": serviceItems.map((e) => e.toJson()).toList(),
      "images": images,
      "customer_sign": customerSign,
      "technician_sign": technicianSign,
      if (adminCompleted != null) "admin_completed": adminCompleted,
    };
  }
}
