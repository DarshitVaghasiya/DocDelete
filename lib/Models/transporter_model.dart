/*
class TransporterModel {
  int? id;
  int? createdId;
  String name;
  String contactPerson;
  String phone;
  // String? signature;

  TransporterModel({
    this.id,
    this.createdId,
    required this.name,
    required this.contactPerson,
    required this.phone,
    // required this.signature,
  });

  // FROM JSON (API → APP)
  factory TransporterModel.fromJson(Map<String, dynamic> json) {
    return TransporterModel(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? ''),
      createdId: json['created_id'] is int
          ? json['created_id']
          : int.tryParse(json['created_id']?.toString() ?? ''),

      name: json['name']?.toString() ?? "",
      contactPerson: json['contact_person'] ?? "",
      phone: json['phone']?.toString() ?? "",
      //  signature: json['signature'] ?? "",
    );
  }

  // TO JSON (APP → API)
  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "created_id": createdId,
      "name": name,
      "contact_person": contactPerson,
      "phone": phone,
      // "signature": signature,
    };
  }
}
*/
