using System.ComponentModel.DataAnnotations;
using System;
using System.Collections.Generic;
namespace Karta.Service.DTO
{
    public record CreateRoleRequest
    {
        [Required(ErrorMessage = "Naziv role je obavezan")]
        [StringLength(50, MinimumLength = 2, ErrorMessage = "Naziv role mora biti između 2 i 50 karaktera")]
        public string Name { get; init; } = string.Empty;
        [StringLength(200, ErrorMessage = "Opis role ne može biti duži od 200 karaktera")]
        public string? Description { get; init; }
    }
    public record UpdateRoleRequest
    {
        [Required(ErrorMessage = "ID role je obavezan")]
        public string Id { get; init; } = string.Empty;
        [Required(ErrorMessage = "Naziv role je obavezan")]
        [StringLength(50, MinimumLength = 2, ErrorMessage = "Naziv role mora biti između 2 i 50 karaktera")]
        public string Name { get; init; } = string.Empty;
        [StringLength(200, ErrorMessage = "Opis role ne može biti duži od 200 karaktera")]
        public string? Description { get; init; }
    }
    public record RoleResponse
    {
        public string Id { get; init; } = string.Empty;
        public string Name { get; init; } = string.Empty;
        public string NormalizedName { get; init; } = string.Empty;
        public string? Description { get; init; }
        public DateTime CreatedAt { get; init; }
        public int UserCount { get; init; }
    }
    public record AddUserToRoleRequest
    {
        [Required(ErrorMessage = "ID korisnika je obavezan")]
        public string UserId { get; init; } = string.Empty;
        [Required(ErrorMessage = "Naziv role je obavezan")]
        public string RoleName { get; init; } = string.Empty;
    }
    public record RemoveUserFromRoleRequest
    {
        [Required(ErrorMessage = "ID korisnika je obavezan")]
        public string UserId { get; init; } = string.Empty;
        [Required(ErrorMessage = "Naziv role je obavezan")]
        public string RoleName { get; init; } = string.Empty;
    }
    public record UsersInRoleResponse
    {
        public string RoleName { get; init; } = string.Empty;
        public List<UserInfo> Users { get; init; } = new();
        public int TotalCount { get; init; }
    }
}