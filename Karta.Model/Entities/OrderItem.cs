using System;
using System.Collections.Generic;
namespace Karta.Model.Entities
{
    public class OrderItem
    {
        public Guid Id { get; set; }
        public Guid OrderId { get; set; }
        public Guid EventId { get; set; }
        public Guid PriceTierId { get; set; }
        public int Qty { get; set; }
        public decimal UnitPrice { get; set; }
        public Order Order { get; set; } = null!;
        public Event Event { get; set; } = null!;
        public PriceTier PriceTier { get; set; } = null!;
        public ICollection<Ticket> Tickets { get; set; } = new List<Ticket>();
    }
}