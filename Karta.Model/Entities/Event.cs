using System;
using System.Collections.Generic;
namespace Karta.Model.Entities
{
    public class Event
    {
        public Guid Id { get; set; }
        public string Title { get; set; } = "";
        public string Slug { get; set; } = "";
        public string? Description { get; set; }
        public string Venue { get; set; } = "";
        public string City { get; set; } = "";
        public string Country { get; set; } = "";
        public DateTimeOffset StartsAt { get; set; }
        public DateTimeOffset? EndsAt { get; set; }
        public string Category { get; set; } = "";
        public string? Tags { get; set; }
        public string Status { get; set; } = "Draft";
        public string? CoverImageUrl { get; set; }
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public string CreatedBy { get; set; } = "";
        public ICollection<PriceTier> PriceTiers { get; set; } = new List<PriceTier>();
    }
}