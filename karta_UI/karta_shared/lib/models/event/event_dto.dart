import 'package:json_annotation/json_annotation.dart';
import 'price_tier_dto.dart';
part 'event_dto.g.dart';
@JsonSerializable()
class EventDto {
  final String id;
  final String title;
  final String slug;
  final String? description;
  @JsonKey(name: 'venueId')
  final String? venueId;
  @JsonKey(name: 'venueName', defaultValue: '')
  final String venue;  // Maps from venueName for backwards compatibility
  final String city;
  final String country;
  @JsonKey(name: 'startsAt')
  final DateTime startsAt;
  @JsonKey(name: 'endsAt')
  final DateTime? endsAt;
  @JsonKey(name: 'categoryId')
  final String? categoryId;
  @JsonKey(name: 'categoryName', defaultValue: '')
  final String category;  // Maps from categoryName for backwards compatibility
  final String? tags;
  final String status;
  @JsonKey(name: 'coverImageUrl')
  final String? coverImageUrl;
  @JsonKey(name: 'createdAt')
  final DateTime createdAt;
  @JsonKey(name: 'priceTiers')
  final List<PriceTierDto> priceTiers;
  const EventDto({
    required this.id,
    required this.title,
    required this.slug,
    this.description,
    this.venueId,
    required this.venue,
    required this.city,
    required this.country,
    required this.startsAt,
    this.endsAt,
    this.categoryId,
    required this.category,
    this.tags,
    required this.status,
    this.coverImageUrl,
    required this.createdAt,
    required this.priceTiers,
  });
  factory EventDto.fromJson(Map<String, dynamic> json) {
    try {
      final modifiedJson = Map<String, dynamic>.from(json);
      if (modifiedJson['venueName'] == null && modifiedJson['venue'] != null) {
        modifiedJson['venueName'] = modifiedJson['venue'];
      }
      if (modifiedJson['categoryName'] == null && modifiedJson['category'] != null) {
        modifiedJson['categoryName'] = modifiedJson['category'];
      }

      return _$EventDtoFromJson(modifiedJson);
    } catch (e, stackTrace) {
      print('Error parsing EventDto: $e');
      print('Stack trace: $stackTrace');
      print('JSON data: $json');
      try {
        final id = json['id']?.toString() ?? json['Id']?.toString() ?? '';
        final title = json['title']?.toString() ?? json['Title']?.toString() ?? '';
        final slug = json['slug']?.toString() ?? json['Slug']?.toString() ?? '';
        final description = json['description']?.toString() ?? json['Description']?.toString();
        final venueId = json['venueId']?.toString() ?? json['VenueId']?.toString();
        final venue = json['venueName']?.toString() ??
                      json['VenueName']?.toString() ??
                      json['venue']?.toString() ??
                      json['Venue']?.toString() ?? '';

        final city = json['city']?.toString() ?? json['City']?.toString() ?? '';
        final country = json['country']?.toString() ?? json['Country']?.toString() ?? '';
        final categoryId = json['categoryId']?.toString() ?? json['CategoryId']?.toString();
        final category = json['categoryName']?.toString() ??
                         json['CategoryName']?.toString() ??
                         json['category']?.toString() ??
                         json['Category']?.toString() ?? '';

        final tags = json['tags']?.toString() ?? json['Tags']?.toString();
        final status = json['status']?.toString() ?? json['Status']?.toString() ?? '';
        final coverImageUrl = json['coverImageUrl']?.toString() ?? json['CoverImageUrl']?.toString();
        final startsAtStr = json['startsAt']?.toString() ?? json['StartsAt']?.toString() ?? '';
        final startsAt = DateTime.parse(startsAtStr);
        final endsAtStr = json['endsAt']?.toString() ?? json['EndsAt']?.toString();
        final endsAt = endsAtStr != null ? DateTime.parse(endsAtStr) : null;
        final createdAtStr = json['createdAt']?.toString() ?? json['CreatedAt']?.toString() ?? '';
        final createdAt = DateTime.parse(createdAtStr);
        final priceTiersJson = json['priceTiers'] ?? json['PriceTiers'];
        final priceTiers = priceTiersJson != null
            ? (priceTiersJson as List<dynamic>)
                .map((e) => PriceTierDto.fromJson(e as Map<String, dynamic>))
                .toList()
            : <PriceTierDto>[];
        return EventDto(
          id: id,
          title: title,
          slug: slug,
          description: description,
          venueId: venueId,
          venue: venue,
          city: city,
          country: country,
          startsAt: startsAt,
          endsAt: endsAt,
          categoryId: categoryId,
          category: category,
          tags: tags,
          status: status,
          coverImageUrl: coverImageUrl,
          createdAt: createdAt,
          priceTiers: priceTiers,
        );
      } catch (fallbackError) {
        print('Fallback parsing also failed: $fallbackError');
        rethrow;
      }
    }
  }
  Map<String, dynamic> toJson() => _$EventDtoToJson(this);
  bool get isUpcoming => startsAt.isAfter(DateTime.now());
  bool get isPast => endsAt != null ? endsAt!.isBefore(DateTime.now()) : startsAt.isBefore(DateTime.now());
  bool get isPublished => status == 'Published';
  bool get isDraft => status == 'Draft';
  List<String> get tagList => tags?.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList() ?? [];
  int get totalCapacity => priceTiers.fold(0, (sum, tier) => sum + tier.capacity);
  int get totalSold => priceTiers.fold(0, (sum, tier) => sum + tier.sold);
  int get totalAvailable => totalCapacity - totalSold;
}
