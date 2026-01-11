using System;
namespace Karta.Model.Entities
{
    public class EventScannerAssignment
    {
        public Guid Id { get; set; }
        public Guid EventId { get; set; }
        public string ScannerUserId { get; set; } = string.Empty;
        public DateTime AssignedAt { get; set; } = DateTime.UtcNow;
        public Event Event { get; set; } = null!;
        public ApplicationUser Scanner { get; set; } = null!;
    }
}