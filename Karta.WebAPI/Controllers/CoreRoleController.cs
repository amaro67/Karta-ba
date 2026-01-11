using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Swashbuckle.AspNetCore.Annotations;
using Karta.Model;
using Karta.WebAPI.Authorization;
using Karta.WebAPI.Services;
using System.Security.Claims;
namespace Karta.WebAPI.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [SwaggerTag("Upravljanje 4 ključne role - User, Organizer, Scanner, Admin")]
    public class CoreRoleController : ControllerBase
    {
        private readonly UserManager<ApplicationUser> _userManager;
        private readonly RoleManager<ApplicationRole> _roleManager;
        public CoreRoleController(
            UserManager<ApplicationUser> userManager,
            RoleManager<ApplicationRole> roleManager)
        {
            _userManager = userManager;
            _roleManager = roleManager;
        }
        [HttpGet("roles")]
        [AllowAnonymous]
        [SwaggerOperation(Summary = "Vraća sve 4 ključne role", Description = "Vraća User, Organizer, Scanner i Admin role sa njihovim dozvolama")]
        [SwaggerResponse(200, "Lista svih rola")]
        public IActionResult GetCoreRoles()
        {
            var roles = new[]
            {
                new
                {
                    Name = "User",
                    Description = "Kupac - pregleda događaje, kupuje karte, vidi svoje narudžbe",
                    Permissions = RoleManagementService.GetRolePermissions("User")
                },
                new
                {
                    Name = "Organizer",
                    Description = "Organizator događaja - kreira i uređuje svoje događaje",
                    Permissions = RoleManagementService.GetRolePermissions("Organizer")
                },
                new
                {
                    Name = "Scanner",
                    Description = "Osoblje na ulazu - skenira i validira karte",
                    Permissions = RoleManagementService.GetRolePermissions("Scanner")
                },
                new
                {
                    Name = "Admin",
                    Description = "Administrator sistema - upravlja svim korisnicima i rolama",
                    Permissions = RoleManagementService.GetRolePermissions("Admin")
                }
            };
            return Ok(roles);
        }
        [HttpPost("assign")]
        [RequirePermission("ManageUsers")]
        [SwaggerOperation(Summary = "Dodjeljuje rolu korisniku", Description = "Dodjeljuje jednu od 4 ključne role korisniku")]
        [SwaggerResponse(200, "Rola je uspješno dodjeljena")]
        [SwaggerResponse(400, "Neispravni podaci")]
        [SwaggerResponse(401, "Neautorizovan pristup")]
        [SwaggerResponse(403, "Nedovoljna prava")]
        public async Task<IActionResult> AssignRole([FromBody] AssignRoleRequest request)
        {
            if (string.IsNullOrEmpty(request.UserId) || string.IsNullOrEmpty(request.RoleName))
            {
                return BadRequest("UserId i RoleName su obavezni");
            }
            var validRoles = new[] { "User", "Organizer", "Scanner", "Admin" };
            if (!validRoles.Contains(request.RoleName))
            {
                return BadRequest($"Rola mora biti jedna od: {string.Join(", ", validRoles)}");
            }
            var user = await _userManager.FindByIdAsync(request.UserId);
            if (user == null)
            {
                return NotFound("Korisnik nije pronađen");
            }
            var role = await _roleManager.FindByNameAsync(request.RoleName);
            if (role == null)
            {
                return NotFound($"Rola '{request.RoleName}' nije pronađena");
            }
            var existingRoles = await _userManager.GetRolesAsync(user);
            if (existingRoles.Any())
            {
                await _userManager.RemoveFromRolesAsync(user, existingRoles);
            }
            var result = await _userManager.AddToRoleAsync(user, request.RoleName);
            if (result.Succeeded)
            {
                if (request.RoleName == "Organizer" && !user.IsOrganizerVerified)
                {
                    user.IsOrganizerVerified = false;
                    await _userManager.UpdateAsync(user);
                }
                return Ok(new { message = $"Rola '{request.RoleName}' je uspješno dodjeljena korisniku '{user.Email}'" });
            }
            return BadRequest(result.Errors);
        }
        [HttpPost("remove")]
        [RequirePermission("ManageUsers")]
        [SwaggerOperation(Summary = "Uklanja rolu od korisnika", Description = "Uklanja rolu od korisnika")]
        [SwaggerResponse(200, "Rola je uspješno uklonjena")]
        [SwaggerResponse(400, "Neispravni podaci")]
        [SwaggerResponse(401, "Neautorizovan pristup")]
        [SwaggerResponse(403, "Nedovoljna prava")]
        public async Task<IActionResult> RemoveRole([FromBody] RemoveRoleRequest request)
        {
            if (string.IsNullOrEmpty(request.UserId))
            {
                return BadRequest("UserId je obavezan");
            }
            var user = await _userManager.FindByIdAsync(request.UserId);
            if (user == null)
            {
                return NotFound("Korisnik nije pronađen");
            }
            var result = await _userManager.RemoveFromRolesAsync(user, await _userManager.GetRolesAsync(user));
            if (result.Succeeded)
            {
                if (user.IsOrganizerVerified)
                {
                    user.IsOrganizerVerified = false;
                    await _userManager.UpdateAsync(user);
                }
                return Ok(new { message = $"Sve role su uklonjene od korisnika '{user.Email}'" });
            }
            return BadRequest(result.Errors);
        }
        [HttpGet("users")]
        [RequirePermission("ManageUsers")]
        [SwaggerOperation(Summary = "Vraća sve korisnike", Description = "Vraća sve korisnike sa njihovim rolama")]
        [SwaggerResponse(200, "Lista svih korisnika")]
        [SwaggerResponse(401, "Neautorizovan pristup")]
        [SwaggerResponse(403, "Nedovoljna prava")]
        public async Task<IActionResult> GetUsers()
        {
            var users = _userManager.Users.ToList();
            var usersWithRoles = new List<object>();
            foreach (var user in users)
            {
                var roles = await _userManager.GetRolesAsync(user);
                usersWithRoles.Add(new
                {
                    Id = user.Id,
                    Email = user.Email,
                    FirstName = user.FirstName,
                    LastName = user.LastName,
                    EmailConfirmed = user.EmailConfirmed,
                    IsOrganizerVerified = user.IsOrganizerVerified,
                    CreatedAt = user.CreatedAt,
                    Roles = roles
                });
            }
            return Ok(usersWithRoles);
        }
    }
    public record AssignRoleRequest(string UserId, string RoleName);
    public record RemoveRoleRequest(string UserId);
}