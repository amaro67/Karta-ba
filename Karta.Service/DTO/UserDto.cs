using System;
using System.ComponentModel.DataAnnotations;
namespace Karta.Service.DTO
{
    public record CreateUserRequest(
        [Required(ErrorMessage = "Email je obavezan")]
        [EmailAddress(ErrorMessage = "Neispravna email adresa")]
        string Email,
        [Required(ErrorMessage = "Lozinka je obavezna")]
        [MinLength(12, ErrorMessage = "Lozinka mora imati najmanje 12 karaktera")]
        string Password,
        [Required(ErrorMessage = "Ime je obavezno")]
        [MaxLength(50, ErrorMessage = "Ime ne može biti duže od 50 karaktera")]
        string FirstName,
        [Required(ErrorMessage = "Prezime je obavezno")]
        [MaxLength(50, ErrorMessage = "Prezime ne može biti duže od 50 karaktera")]
        string LastName,
        string? RoleName = null
    );
    public record UpdateUserRequest(
        [MaxLength(50, ErrorMessage = "Ime ne može biti duže od 50 karaktera")]
        string? FirstName,
        [MaxLength(50, ErrorMessage = "Prezime ne može biti duže od 50 karaktera")]
        string? LastName,
        [EmailAddress(ErrorMessage = "Neispravna email adresa")]
        string? Email,
        bool? EmailConfirmed
    );
    public record OrganizerVerificationRequest(bool IsVerified);
    public record UserDetailResponse(
        string Id,
        string Email,
        string FirstName,
        string LastName,
        bool EmailConfirmed,
        bool IsOrganizerVerified,
        DateTime CreatedAt,
        DateTime? LastLoginAt,
        string[] Roles
    );
}