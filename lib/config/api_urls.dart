class ApiUrls {
  /// Base URL
  static const String baseUrl = "http://192.168.1.8/api/index.php";
  static const String sendEmail =
      "https://app.docdeletepr.com/api/send_pdf_email.php";

  /// Auth
  static const String login = "$baseUrl/login";

  /// Users
  static const String users = "$baseUrl/users";

  /// Technician
  static const String technician = "$baseUrl/technicians";

  /// Customers
  static const String customer = "$baseUrl/customers";

  /// Transporter
  static const String transporter = "$baseUrl/transporters";

  /// Departments
  static const String departments = "$baseUrl/departments";

  /// getServiceFormData
  static const String getServiceFormData = "$baseUrl/getServiceFormData";

  /// Manifests
  static const String manifest = "$baseUrl/manifests";

  /// GetAllManifests
  static const String getAllManifest = "$baseUrl/manifest";
}
