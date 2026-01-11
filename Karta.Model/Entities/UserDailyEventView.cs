using System;
namespace Karta.Model.Entities
{
    public class UserDailyEventView
    {
        public int Id { get; set; }
        public string UserId { get; set; } = "";
        public ApplicationUser? User { get; set; }
        public string Category { get; set; } = "";
        public int ViewCount { get; set; } = 0;
        public DateTime Date { get; set; }
        public bool EmailSentToday { get; set; } = false;
        public DateTime? EmailSentAt { get; set; }
    }
}