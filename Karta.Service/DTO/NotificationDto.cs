using System;
using System.ComponentModel.DataAnnotations;
namespace Karta.Service.DTO;

public record NotificationDto(
    Guid Id,
    string UserId,
    string Title,
    string Content,
    string Type,
    bool IsRead,
    Guid? RelatedEntityId,
    string? RelatedEntityType,
    DateTime CreatedAt
);

public class CreateNotificationRequest
{
    [Required]
    [MaxLength(200)]
    public string Title { get; set; } = "";

    [Required]
    [MaxLength(2000)]
    public string Content { get; set; } = "";

    [MaxLength(50)]
    public string Type { get; set; } = "SystemAnnouncement";
}
