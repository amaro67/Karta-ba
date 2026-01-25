using System;
namespace Karta.Model.Entities
{
    public class Review
    {
        public Guid Id { get; set; }
        public string UserId { get; set; } = "";
        public Guid EventId { get; set; }
        public int Rating { get; set; }  // 1-5 stars
        public string Title { get; set; } = "";
        public string Content { get; set; } = "";
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime? UpdatedAt { get; set; }

        // Navigation properties
        public ApplicationUser User { get; set; } = null!;
        public Event Event { get; set; } = null!;
    }
}
