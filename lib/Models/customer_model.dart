import 'department_model.dart';

class CustomerModel {
  int? id;
  int? createdId;
  String name;
  String address;
  String contactPerson;
  String phone;
  String email;

  List<DepartmentModel1> departments; // 🔥 NEW

  CustomerModel({
    this.id,
    this.createdId,
    required this.name,
    required this.address,
    required this.contactPerson,
    required this.phone,
    required this.email,
    required this.departments, // 🔥 NEW
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: json["id"] is int
          ? json["id"]
          : int.tryParse(json["id"]?.toString() ?? ''),
      createdId: json["created_id"] is int
          ? json["created_id"]
          : int.tryParse(json["created_id"]?.toString() ?? ''),

      name: json["name"]?.toString() ?? "",
      address: json["address"]?.toString() ?? "",
      contactPerson: json['contact_person'] ?? "",
      phone: json["phone"]?.toString() ?? "",
      email: json["email"]?.toString() ?? "",

      departments: (json["departments"] as List? ?? [])
          .map((e) => DepartmentModel1.fromJson(e))
          .toList(),
    );
  }
  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "created_id": createdId,
      "name": name,
      "address": address,
      "contact_person": contactPerson,
      "phone": phone,
      "email": email,

      // 🔥 Optional (if needed)
      "departments": departments.map((e) => e.toJson()).toList(),
    };
  }
}
