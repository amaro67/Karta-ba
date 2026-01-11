using Karta.Model;
using Karta.Service.DTO;
using Karta.Service.Interfaces;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
namespace Karta.Service.Services
{
    public class RoleService : IRoleService
    {
        private readonly RoleManager<ApplicationRole> _roleManager;
        private readonly UserManager<ApplicationUser> _userManager;
        private readonly ApplicationDbContext _context;
        private readonly ILogger<RoleService> _logger;
        public RoleService(
            RoleManager<ApplicationRole> roleManager,
            UserManager<ApplicationUser> userManager,
            ApplicationDbContext context,
            ILogger<RoleService> logger)
        {
            _roleManager = roleManager;
            _userManager = userManager;
            _context = context;
            _logger = logger;
        }
        public async Task<RoleResponse> CreateRoleAsync(CreateRoleRequest request)
        {
            _logger.LogInformation("Kreiranje nove role: {RoleName}", request.Name);
            var existingRole = await _roleManager.FindByNameAsync(request.Name);
            if (existingRole != null)
            {
                throw new InvalidOperationException($"Rola '{request.Name}' već postoji");
            }
            var role = new ApplicationRole
            {
                Name = request.Name,
                Description = request.Description,
                CreatedAt = DateTime.UtcNow
            };
            var result = await _roleManager.CreateAsync(role);
            if (!result.Succeeded)
            {
                var errors = string.Join(", ", result.Errors.Select(e => e.Description));
                throw new InvalidOperationException($"Greška pri kreiranju role: {errors}");
            }
            _logger.LogInformation("Rola uspješno kreirana: {RoleName}", request.Name);
            return new RoleResponse
            {
                Id = role.Id,
                Name = role.Name,
                NormalizedName = role.NormalizedName,
                Description = role.Description,
                CreatedAt = role.CreatedAt,
                UserCount = 0
            };
        }
        public async Task<RoleResponse> UpdateRoleAsync(UpdateRoleRequest request)
        {
            _logger.LogInformation("Ažuriranje role: {RoleId}", request.Id);
            var role = await _roleManager.FindByIdAsync(request.Id);
            if (role == null)
            {
                throw new KeyNotFoundException($"Rola sa ID-om '{request.Id}' nije pronađena");
            }
            if (role.Name != request.Name)
            {
                var existingRole = await _roleManager.FindByNameAsync(request.Name);
                if (existingRole != null)
                {
                    throw new InvalidOperationException($"Rola '{request.Name}' već postoji");
                }
            }
            role.Name = request.Name;
            role.Description = request.Description;
            var result = await _roleManager.UpdateAsync(role);
            if (!result.Succeeded)
            {
                var errors = string.Join(", ", result.Errors.Select(e => e.Description));
                throw new InvalidOperationException($"Greška pri ažuriranju role: {errors}");
            }
            var userCount = await _userManager.GetUsersInRoleAsync(role.Name);
            _logger.LogInformation("Rola uspješno ažurirana: {RoleName}", request.Name);
            return new RoleResponse
            {
                Id = role.Id,
                Name = role.Name,
                NormalizedName = role.NormalizedName,
                Description = role.Description,
                CreatedAt = role.CreatedAt,
                UserCount = userCount.Count
            };
        }
        public async Task<bool> DeleteRoleAsync(string roleId)
        {
            _logger.LogInformation("Brisanje role: {RoleId}", roleId);
            var role = await _roleManager.FindByIdAsync(roleId);
            if (role == null)
            {
                throw new KeyNotFoundException($"Rola sa ID-om '{roleId}' nije pronađena");
            }
            var usersInRole = await _userManager.GetUsersInRoleAsync(role.Name);
            if (usersInRole.Any())
            {
                throw new InvalidOperationException($"Ne može se obrisati rola '{role.Name}' jer ima {usersInRole.Count} korisnika");
            }
            var result = await _roleManager.DeleteAsync(role);
            if (!result.Succeeded)
            {
                var errors = string.Join(", ", result.Errors.Select(e => e.Description));
                throw new InvalidOperationException($"Greška pri brisanju role: {errors}");
            }
            _logger.LogInformation("Rola uspješno obrisana: {RoleName}", role.Name);
            return true;
        }
        public async Task<RoleResponse?> GetRoleByIdAsync(string roleId)
        {
            var role = await _roleManager.FindByIdAsync(roleId);
            if (role == null)
                return null;
            var userCount = await _userManager.GetUsersInRoleAsync(role.Name);
            return new RoleResponse
            {
                Id = role.Id,
                Name = role.Name,
                NormalizedName = role.NormalizedName,
                Description = role.Description,
                CreatedAt = role.CreatedAt,
                UserCount = userCount.Count
            };
        }
        public async Task<RoleResponse?> GetRoleByNameAsync(string roleName)
        {
            var role = await _roleManager.FindByNameAsync(roleName);
            if (role == null)
                return null;
            var userCount = await _userManager.GetUsersInRoleAsync(role.Name);
            return new RoleResponse
            {
                Id = role.Id,
                Name = role.Name,
                NormalizedName = role.NormalizedName,
                Description = role.Description,
                CreatedAt = role.CreatedAt,
                UserCount = userCount.Count
            };
        }
        public async Task<List<RoleResponse>> GetAllRolesAsync()
        {
            var roles = await _roleManager.Roles.ToListAsync();
            var roleResponses = new List<RoleResponse>();
            foreach (var role in roles)
            {
                var userCount = await _userManager.GetUsersInRoleAsync(role.Name);
                roleResponses.Add(new RoleResponse
                {
                    Id = role.Id,
                    Name = role.Name,
                    NormalizedName = role.NormalizedName,
                    Description = role.Description,
                    CreatedAt = role.CreatedAt,
                    UserCount = userCount.Count
                });
            }
            return roleResponses;
        }
        public async Task<bool> AddUserToRoleAsync(AddUserToRoleRequest request)
        {
            _logger.LogInformation("Dodavanje role {RoleName} korisniku {UserId}", request.RoleName, request.UserId);
            var user = await _userManager.FindByIdAsync(request.UserId);
            if (user == null)
            {
                throw new KeyNotFoundException($"Korisnik sa ID-om '{request.UserId}' nije pronađen");
            }
            var role = await _roleManager.FindByNameAsync(request.RoleName);
            if (role == null)
            {
                throw new KeyNotFoundException($"Rola '{request.RoleName}' nije pronađena");
            }
            if (await _userManager.IsInRoleAsync(user, request.RoleName))
            {
                throw new InvalidOperationException($"Korisnik već ima rolu '{request.RoleName}'");
            }
            var result = await _userManager.AddToRoleAsync(user, request.RoleName);
            if (!result.Succeeded)
            {
                var errors = string.Join(", ", result.Errors.Select(e => e.Description));
                throw new InvalidOperationException($"Greška pri dodavanju role: {errors}");
            }
            _logger.LogInformation("Rola {RoleName} uspješno dodana korisniku {UserId}", request.RoleName, request.UserId);
            return true;
        }
        public async Task<bool> RemoveUserFromRoleAsync(RemoveUserFromRoleRequest request)
        {
            _logger.LogInformation("Uklanjanje role {RoleName} od korisnika {UserId}", request.RoleName, request.UserId);
            var user = await _userManager.FindByIdAsync(request.UserId);
            if (user == null)
            {
                throw new KeyNotFoundException($"Korisnik sa ID-om '{request.UserId}' nije pronađen");
            }
            var role = await _roleManager.FindByNameAsync(request.RoleName);
            if (role == null)
            {
                throw new KeyNotFoundException($"Rola '{request.RoleName}' nije pronađena");
            }
            if (!await _userManager.IsInRoleAsync(user, request.RoleName))
            {
                throw new InvalidOperationException($"Korisnik nema rolu '{request.RoleName}'");
            }
            var result = await _userManager.RemoveFromRoleAsync(user, request.RoleName);
            if (!result.Succeeded)
            {
                var errors = string.Join(", ", result.Errors.Select(e => e.Description));
                throw new InvalidOperationException($"Greška pri uklanjanju role: {errors}");
            }
            _logger.LogInformation("Rola {RoleName} uspješno uklonjena od korisnika {UserId}", request.RoleName, request.UserId);
            return true;
        }
        public async Task<UsersInRoleResponse> GetUsersInRoleAsync(string roleName)
        {
            var role = await _roleManager.FindByNameAsync(roleName);
            if (role == null)
            {
                throw new KeyNotFoundException($"Rola '{roleName}' nije pronađena");
            }
            var users = await _userManager.GetUsersInRoleAsync(roleName);
            var userInfos = users.Select(u => new UserInfo(
                u.Id,
                u.Email,
                u.FirstName,
                u.LastName,
                u.EmailConfirmed,
                u.IsOrganizerVerified,
                new string[0]
            )).ToList();
            return new UsersInRoleResponse
            {
                RoleName = roleName,
                Users = userInfos,
                TotalCount = userInfos.Count()
            };
        }
        public async Task<List<RoleResponse>> GetUserRolesAsync(string userId)
        {
            var user = await _userManager.FindByIdAsync(userId);
            if (user == null)
            {
                throw new KeyNotFoundException($"Korisnik sa ID-om '{userId}' nije pronađen");
            }
            var roleNames = await _userManager.GetRolesAsync(user);
            var roles = new List<RoleResponse>();
            foreach (var roleName in roleNames)
            {
                var role = await _roleManager.FindByNameAsync(roleName);
                if (role != null)
                {
                    var userCount = await _userManager.GetUsersInRoleAsync(roleName);
                    roles.Add(new RoleResponse
                    {
                        Id = role.Id,
                        Name = role.Name,
                        NormalizedName = role.NormalizedName,
                        Description = role.Description,
                        CreatedAt = role.CreatedAt,
                        UserCount = userCount.Count
                    });
                }
            }
            return roles;
        }
        public async Task<bool> IsUserInRoleAsync(string userId, string roleName)
        {
            var user = await _userManager.FindByIdAsync(userId);
            if (user == null)
                return false;
            return await _userManager.IsInRoleAsync(user, roleName);
        }
    }
}