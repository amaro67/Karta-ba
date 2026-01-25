using System;
using System.ComponentModel.DataAnnotations;
namespace Karta.Service.DTO;

public record VenueDto(
    Guid Id,
    string Name,
    string Address,
    string City,
    string Country,
    int? Capacity,
    double? Latitude,
    double? Longitude,
    string CreatedBy,
    DateTime CreatedAt,
    int EventCount
);

public class CreateVenueRequest
{
    [Required]
    [MaxLength(200)]
    public string Name { get; set; } = "";

    [Required]
    [MaxLength(300)]
    public string Address { get; set; } = "";

    [Required]
    [MaxLength(100)]
    public string City { get; set; } = "";

    [Required]
    [MaxLength(100)]
    public string Country { get; set; } = "";

    public int? Capacity { get; set; }

    public double? Latitude { get; set; }

    public double? Longitude { get; set; }
}

public class UpdateVenueRequest
{
    [MaxLength(200)]
    public string? Name { get; set; }

    [MaxLength(300)]
    public string? Address { get; set; }

    [MaxLength(100)]
    public string? City { get; set; }

    [MaxLength(100)]
    public string? Country { get; set; }

    public int? Capacity { get; set; }

    public double? Latitude { get; set; }

    public double? Longitude { get; set; }
}
