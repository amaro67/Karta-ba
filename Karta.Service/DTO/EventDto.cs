using System;
using System.Collections.Generic;
namespace Karta.Service.DTO;
public record PriceTierDto(Guid Id, string Name, decimal Price, string Currency, int Capacity, int Sold);
public record EventDto(
    Guid Id,
    string Title,
    string Slug,
    string? Description,
    Guid? VenueId,
    string VenueName,
    string City,
    string Country,
    DateTimeOffset StartsAt,
    DateTimeOffset? EndsAt,
    Guid? CategoryId,
    string CategoryName,
    string? Tags,
    string Status,
    string? CoverImageUrl,
    DateTime CreatedAt,
    IReadOnlyList<PriceTierDto> PriceTiers
);