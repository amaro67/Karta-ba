using System;
using System.Collections.Generic;
namespace Karta.Model.Entities
{
    public class Order
    {
        public Guid Id { get; set; }
        public string UserId { get; set; } = "";
        public decimal TotalAmount { get; set; }
        public string Currency { get; set; } = "BAM";
        public string Status { get; set; } = "Pending";
        public string? StripePaymentIntentId { get; set; }
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public ICollection<OrderItem> Items { get; set; } = new List<OrderItem>();
    }
}