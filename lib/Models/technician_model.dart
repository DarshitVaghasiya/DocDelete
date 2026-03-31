class TechnicianModel {
  int? id;
  int? userId;
  String name;
  String address;
  String phone;
  String email;
  String password;

  TechnicianModel({
    this.id,
    this.userId,
    required this.name,
    required this.address,
    required this.phone,
    required this.email,
    required this.password,
  });

  factory TechnicianModel.fromJson(Map<String, dynamic> json) {
    return TechnicianModel(
      id: json["id"],
      userId: json["user_id"],
      name: json["name"] ?? "",
      address: json["address"] ?? "",
      phone: json["phone"] ?? "",
      email: json["email"] ?? "",
      password: json["password"] ?? "",
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "user_id": userId,
      "name": name,
      "address": address,
      "phone": phone,
      "email": email,
      "password": password,
    };
  }
}
