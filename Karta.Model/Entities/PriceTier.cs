using System;
namespace Karta.Model.Entities
{
    public class PriceTier
    {
        public Guid Id { get; set; }
        public Guid EventId { get; set; }
        public string Name { get; set; } = "";
        public decimal Price { get; set; }
        public string Currency { get; set; } = "BAM";
        public int Capacity { get; set; }
        public int Sold { get; set; }
        public Event Event { get; set; } = null!;
    }
}