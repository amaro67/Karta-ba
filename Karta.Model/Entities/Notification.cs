using System;
namespace Karta.Model.Entities
{
    public enum NotificationType
    {
        OrderUpdate,
        EventChange,
        TicketIssued,
        TicketCancelled,
        SystemAnnouncement
    }

    public class Notification
    {
        public Guid Id { get; set; }
        public string UserId { get; set; } = "";
        public string Title { get; set; } = "";
        public string Content { get; set; } = "";
        public NotificationType Type { get; set; }
        public bool IsRead { get; set; }
        public Guid? RelatedEntityId { get; set; }
        public string? RelatedEntityType { get; set; }
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public ApplicationUser? User { get; set; }
    }
}
