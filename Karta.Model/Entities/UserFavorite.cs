using System;
namespace Karta.Model.Entities
{
    public class UserFavorite
    {
        public Guid Id { get; set; }
        public string UserId { get; set; } = "";
        public Guid EventId { get; set; }
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public ApplicationUser User { get; set; } = null!;
        public Event Event { get; set; } = null!;
    }
}
