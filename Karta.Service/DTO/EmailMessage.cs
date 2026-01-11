using System;
namespace Karta.Service.DTO
{
    public enum EmailType
    {
        Confirmation,
        PasswordReset,
        TicketConfirmation,
        Welcome,
        CategoryRecommendation
    }
    public record EmailMessage(
        string ToEmail,
        string Subject,
        string Body,
        EmailType Type,
        DateTime CreatedAt = default
    )
    {
        public DateTime CreatedAt { get; init; } = CreatedAt == default ? DateTime.UtcNow : CreatedAt;
    }
    public record EmailResult(
        bool Success,
        string? ErrorMessage = null,
        DateTime ProcessedAt = default
    )
    {
        public DateTime ProcessedAt { get; init; } = ProcessedAt == default ? DateTime.UtcNow : ProcessedAt;
    }
}