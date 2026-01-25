using System;
using System.ComponentModel.DataAnnotations;
namespace Karta.Service.DTO;

public record CategoryDto(
    Guid Id,
    string Name,
    string Slug,
    string? Description,
    string? IconUrl,
    int DisplayOrder,
    bool IsActive,
    DateTime CreatedAt,
    int EventCount
);

public class CreateCategoryRequest
{
    [Required]
    [MaxLength(100)]
    public string Name { get; set; } = "";

    [MaxLength(500)]
    public string? Description { get; set; }

    [MaxLength(500)]
    public string? IconUrl { get; set; }

    public int DisplayOrder { get; set; } = 0;
}

public class UpdateCategoryRequest
{
    [MaxLength(100)]
    public string? Name { get; set; }

    [MaxLength(500)]
    public string? Description { get; set; }

    [MaxLength(500)]
    public string? IconUrl { get; set; }

    public int? DisplayOrder { get; set; }

    public bool? IsActive { get; set; }
}
