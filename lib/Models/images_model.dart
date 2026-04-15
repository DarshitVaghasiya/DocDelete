class PhotoModel {
  final dynamic image;
  final double? lat;
  final double? lng;

  PhotoModel({required this.image, this.lat, this.lng});

  factory PhotoModel.fromJson(Map<String, dynamic> json) {
    return PhotoModel(
      image: json['image'] ?? "",
      lat: double.tryParse(json['latitude']?.toString() ?? ""),
      lng: double.tryParse(json['longitude']?.toString() ?? ""),
    );
  }
}
