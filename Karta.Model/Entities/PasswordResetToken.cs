using System;
namespace Karta.Model.Entities
{
    public class PasswordResetToken
    {
        public Guid Id { get; set; }
        public string UserId { get; set; } = string.Empty;
        public string Token { get; set; } = string.Empty;
        public DateTime ExpiresAt { get; set; }
        public bool IsUsed { get; set; }
        public DateTime CreatedAt { get; set; }
        public ApplicationUser User { get; set; } = null!;
    }
}