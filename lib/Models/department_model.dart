import 'dart:convert';
import 'package:signature/signature.dart';

class DepartmentModel1 {
  final int? id;
  final int? customerId;
  final String departmentName;

  DepartmentModel1({this.id, this.customerId, required this.departmentName});

  /// FROM JSON
  factory DepartmentModel1.fromJson(Map<String, dynamic> json) {
    return DepartmentModel1(
      id: int.tryParse(json['id'].toString()),
      customerId: int.tryParse(json['customer_id'].toString()),
      departmentName: json['department_name'] ?? '',
    );
  }

  /// TO JSON
  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "customer_id": customerId,
      "department_name": departmentName,
    };
  }
}
