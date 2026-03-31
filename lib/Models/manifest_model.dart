import 'package:doc_delete/Models/service_model.dart';

class ManifestModel {
  final int technicianId;
  final int? customerId;
  final String? customerName; // 👈 ADD THIS
  final String serviceDate;
  final List<ServiceItemModel> serviceItems;
  final List<String> images;
  final String? customerSign;
  final String? technicianSign;

  ManifestModel({
    required this.technicianId,
    required this.customerId,
    this.customerName,
    required this.serviceDate,
    required this.serviceItems,
    required this.images,
    required this.customerSign,
    required this.technicianSign,
  });

  Map<String, dynamic> toJson() {
    return {
      "technician_id": technicianId,
      "customer_id": customerId,
      "customer_name": customerName,
      "service_date": serviceDate,
      "service_items": serviceItems.map((e) => e.toJson()).toList(),
      "image_name": images,
      "customer_sign": customerSign,
      "technician_sign": technicianSign,
    };
  }
}
