class UserModel {
  final int id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String? adminSign;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.adminSign,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json["id"],
      name: json["name"],
      email: json["email"],
      phone: json["phone"],
      role: json["role"],
      adminSign: json['admin_sign']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
      "email": email,
      "phone": phone,
      "role": role,
      "admin_sign": adminSign,
    };
  }
}
