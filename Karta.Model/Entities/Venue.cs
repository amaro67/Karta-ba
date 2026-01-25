using System;
using System.Collections.Generic;
namespace Karta.Model.Entities
{
    public class Venue
    {
        public Guid Id { get; set; }
        public string Name { get; set; } = "";
        public string Address { get; set; } = "";
        public string City { get; set; } = "";
        public string Country { get; set; } = "";
        public int? Capacity { get; set; }
        public double? Latitude { get; set; }
        public double? Longitude { get; set; }
        public string CreatedBy { get; set; } = "";
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public ICollection<Event> Events { get; set; } = new List<Event>();
    }
}
