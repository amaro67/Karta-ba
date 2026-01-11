using System;
using System.Collections.Generic;
namespace Karta.Model.Entities
{
    public class Ticket
    {
        public Guid Id { get; set; }
        public Guid OrderItemId { get; set; }
        public string TicketCode { get; set; } = Guid.NewGuid().ToString("N");
        public string QRNonce { get; set; } = Guid.NewGuid().ToString("N");
        public string Status { get; set; } = "Issued";
        public DateTime IssuedAt { get; set; } = DateTime.UtcNow;
        public DateTime? UsedAt { get; set; }
        public OrderItem OrderItem { get; set; } = null!;
        public ICollection<ScanLog> ScanLogs { get; set; } = new List<ScanLog>();
    }
}