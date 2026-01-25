using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;

namespace Karta.Service.DTO;

public record ReviewDto(
    Guid Id,
    Guid EventId,
    string UserId,
    string UserName,
    int Rating,
    string Title,
    string Content,
    DateTime CreatedAt,
    DateTime? UpdatedAt
);

public record EventReviewsDto(
    double AverageRating,
    int TotalCount,
    IReadOnlyList<ReviewDto> Reviews
);

public class CreateReviewRequest
{
    [Required]
    [Range(1, 5, ErrorMessage = "Rating must be between 1 and 5")]
    public int Rating { get; set; }

    [Required]
    [MaxLength(100, ErrorMessage = "Title cannot exceed 100 characters")]
    public string Title { get; set; } = "";

    [Required]
    [MaxLength(1000, ErrorMessage = "Content cannot exceed 1000 characters")]
    public string Content { get; set; } = "";
}

public class UpdateReviewRequest
{
    [Range(1, 5, ErrorMessage = "Rating must be between 1 and 5")]
    public int? Rating { get; set; }

    [MaxLength(100, ErrorMessage = "Title cannot exceed 100 characters")]
    public string? Title { get; set; }

    [MaxLength(1000, ErrorMessage = "Content cannot exceed 1000 characters")]
    public string? Content { get; set; }
}
