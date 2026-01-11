using System;
namespace Karta.Model.Entities
{
    public class ScanLog
    {
        public Guid Id { get; set; }
        public Guid TicketId { get; set; }
        public string GateId { get; set; } = "A1";
        public DateTime ScannedAt { get; set; } = DateTime.UtcNow;
        public string Result { get; set; } = "Valid";
        public Ticket Ticket { get; set; } = null!;
    }
}