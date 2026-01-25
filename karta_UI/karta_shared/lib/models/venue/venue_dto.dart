class VenueDto {
  final String id;
  final String name;
  final String address;
  final String city;
  final String country;
  final int? capacity;
  final double? latitude;
  final double? longitude;
  final String createdBy;
  final DateTime createdAt;
  final int eventCount;

  VenueDto({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.country,
    this.capacity,
    this.latitude,
    this.longitude,
    required this.createdBy,
    required this.createdAt,
    required this.eventCount,
  });

  factory VenueDto.fromJson(Map<String, dynamic> json) {
    return VenueDto(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String? ?? '',
      city: json['city'] as String,
      country: json['country'] as String,
      capacity: json['capacity'] as int?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      createdBy: json['createdBy'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      eventCount: json['eventCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'city': city,
      'country': country,
      'capacity': capacity,
      'latitude': latitude,
      'longitude': longitude,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'eventCount': eventCount,
    };
  }

  String get fullAddress => '$address, $city, $country';

  @override
  String toString() => 'VenueDto(id: $id, name: $name, city: $city)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VenueDto && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
