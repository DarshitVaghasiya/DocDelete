import 'dart:convert';
import 'package:doc_delete/Models/get_all_manifest_model.dart';
import 'package:http/http.dart' as http;
import 'api_urls.dart';

class ManifestService {
  static Future<GetAllManifestModel?> getManifest({int? technicianId}) async {
    final uri = Uri.parse(ApiUrls.getAllManifest).replace(
      queryParameters: {
        if (technicianId != null) "technician_id": "$technicianId",
      },
    );
    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == true && data['data'] != null) {
          if (data['data'] is List && data['data'].isNotEmpty) {
            final first = data['data'][0];
            return GetAllManifestModel.fromJson(first);
          }
        }
      }
    } catch (e) {
      print("API Error: $e");
    }

    return null;
  }
}
