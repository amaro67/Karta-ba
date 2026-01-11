using System;
using System.ComponentModel.DataAnnotations;
namespace Karta.Service.DTO
{
    public record LoginRequest(
        [Required(ErrorMessage = "Email je obavezan")]
        [EmailAddress(ErrorMessage = "Neispravna email adresa")]
        string Email, 
        [Required(ErrorMessage = "Lozinka je obavezna")]
        [MinLength(6, ErrorMessage = "Lozinka mora imati najmanje 6 karaktera")]
        string Password, 
        bool RememberMe = false
    );
    public record RegisterRequest(
        [Required(ErrorMessage = "Email je obavezan")]
        [EmailAddress(ErrorMessage = "Neispravna email adresa")]
        string Email, 
        [Required(ErrorMessage = "Lozinka je obavezna")]
        [MinLength(6, ErrorMessage = "Lozinka mora imati najmanje 6 karaktera")]
        string Password, 
        [Required(ErrorMessage = "Ime je obavezno")]
        [MaxLength(50, ErrorMessage = "Ime ne može biti duže od 50 karaktera")]
        string FirstName, 
        [Required(ErrorMessage = "Prezime je obavezno")]
        [MaxLength(50, ErrorMessage = "Prezime ne može biti duže od 50 karaktera")]
        string LastName
    );
    public record RefreshTokenRequest(
        [Required(ErrorMessage = "Access token je obavezan")]
        string AccessToken, 
        [Required(ErrorMessage = "Refresh token je obavezan")]
        string RefreshToken
    );
    public record AuthResponse(
        string AccessToken,
        string RefreshToken,
        DateTime ExpiresAt,
        UserInfo User
    );
    public record UserInfo(
        string Id,
        string Email,
        string FirstName,
        string LastName,
        bool EmailConfirmed,
        bool IsOrganizerVerified,
        string[] Roles
    );
    public record TokenValidationResponse(
        bool IsValid,
        string? UserId,
        string? Email,
        string[] Roles
    );
    public record ResendConfirmationRequest(
        [Required(ErrorMessage = "Email je obavezan")]
        [EmailAddress(ErrorMessage = "Neispravna email adresa")]
        string Email
    );
}