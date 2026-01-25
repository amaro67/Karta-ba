class ReviewDto {
  final String id;
  final String eventId;
  final String userId;
  final String userName;
  final int rating;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ReviewDto({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.userName,
    required this.rating,
    required this.title,
    required this.content,
    required this.createdAt,
    this.updatedAt,
  });

  factory ReviewDto.fromJson(Map<String, dynamic> json) {
    return ReviewDto(
      id: json['id']?.toString() ?? json['Id']?.toString() ?? '',
      eventId: json['eventId']?.toString() ?? json['EventId']?.toString() ?? '',
      userId: json['userId']?.toString() ?? json['UserId']?.toString() ?? '',
      userName: json['userName']?.toString() ?? json['UserName']?.toString() ?? '',
      rating: json['rating'] ?? json['Rating'] ?? 0,
      title: json['title']?.toString() ?? json['Title']?.toString() ?? '',
      content: json['content']?.toString() ?? json['Content']?.toString() ?? '',
      createdAt: DateTime.tryParse(
        json['createdAt']?.toString() ?? json['CreatedAt']?.toString() ?? '',
      ) ?? DateTime.now(),
      updatedAt: json['updatedAt'] != null || json['UpdatedAt'] != null
          ? DateTime.tryParse(
              json['updatedAt']?.toString() ?? json['UpdatedAt']?.toString() ?? '',
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'eventId': eventId,
      'userId': userId,
      'userName': userName,
      'rating': rating,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}

class EventReviewsDto {
  final double averageRating;
  final int totalCount;
  final List<ReviewDto> reviews;

  EventReviewsDto({
    required this.averageRating,
    required this.totalCount,
    required this.reviews,
  });

  factory EventReviewsDto.fromJson(Map<String, dynamic> json) {
    final reviewsList = json['reviews'] ?? json['Reviews'] ?? [];
    return EventReviewsDto(
      averageRating: (json['averageRating'] ?? json['AverageRating'] ?? 0).toDouble(),
      totalCount: json['totalCount'] ?? json['TotalCount'] ?? 0,
      reviews: (reviewsList as List)
          .map((item) => ReviewDto.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CreateReviewRequest {
  final int rating;
  final String title;
  final String content;

  CreateReviewRequest({
    required this.rating,
    required this.title,
    required this.content,
  });

  Map<String, dynamic> toJson() {
    return {
      'rating': rating,
      'title': title,
      'content': content,
    };
  }
}

class UpdateReviewRequest {
  final int? rating;
  final String? title;
  final String? content;

  UpdateReviewRequest({
    this.rating,
    this.title,
    this.content,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (rating != null) json['rating'] = rating;
    if (title != null) json['title'] = title;
    if (content != null) json['content'] = content;
    return json;
  }
}
