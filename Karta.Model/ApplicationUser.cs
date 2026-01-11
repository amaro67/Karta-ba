using Microsoft.AspNetCore.Identity;
using System;
namespace Karta.Model
{
    public class ApplicationUser : IdentityUser
    {
        public string? FirstName { get; set; }
        public string? LastName { get; set; }
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime? LastLoginAt { get; set; }
        public bool IsOrganizerVerified { get; set; } = false;
        public string? CreatedByOrganizerId { get; set; }
    }
}