class ServiceItemModel {
  int departmentId;
  String unitType;
  String measure;
  String quantity;
  String serviceType;

  ServiceItemModel({
    required this.departmentId,
    required this.unitType,
    required this.measure,
    required this.quantity,
    required this.serviceType,
  });

  factory ServiceItemModel.fromJson(Map<String, dynamic> json) {
    return ServiceItemModel(
      departmentId: json["department_id"] ?? 0,
      unitType: json["unit_type"]?.toString() ?? "", // 🔥 FIX
      measure: json["measure"]?.toString() ?? "",
      quantity: json["quantity"]?.toString() ?? "",
      serviceType: json["service_type"]?.toString() ?? "",
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "department_id": departmentId,
      "unit_type": unitType,
      "measure": measure,
      "quantity": quantity,
      "service_type": serviceType, // ✅ STRING ONLY
    };
  }
}
