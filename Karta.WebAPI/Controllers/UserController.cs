using Karta.Model;
using Karta.Service.DTO;
using Karta.Service.Interfaces;
using Karta.WebAPI.Authorization;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Swashbuckle.AspNetCore.Annotations;
using System.Security.Claims;
using System.Linq;
namespace Karta.WebAPI.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [SwaggerTag("Upravljanje korisnicima - Admin funkcionalnosti")]
    public class UserController : ControllerBase
    {
        private readonly UserManager<ApplicationUser> _userManager;
        private readonly IOrderService _orderService;
        private readonly ILogger<UserController> _logger;
        private readonly Karta.Service.Services.IEmailService _emailService;
        public UserController(
            UserManager<ApplicationUser> userManager,
            IOrderService orderService,
            ILogger<UserController> logger,
            Karta.Service.Services.IEmailService emailService)
        {
            _userManager = userManager;
            _orderService = orderService;
            _logger = logger;
            _emailService = emailService;
        }
        [HttpGet("{id}")]
        [RequirePermission("ManageUsers")]
        [SwaggerOperation(
            Summary = "Vraća detalje korisnika",
            Description = "Vraća detaljne informacije o korisniku sa njegovim rolama"
        )]
        [SwaggerResponse(200, "Korisnik pronađen", typeof(UserDetailResponse))]
        [SwaggerResponse(401, "Neautorizovan pristup")]
        [SwaggerResponse(403, "Nedovoljna prava")]
        [SwaggerResponse(404, "Korisnik nije pronađen")]
        public async Task<ActionResult<UserDetailResponse>> GetUser(string id)
        {
            var user = await _userManager.FindByIdAsync(id);
            if (user == null)
            {
                _logger.LogWarning("User not found: {UserId}", id);
                return NotFound(new { message = "Korisnik nije pronađen" });
            }
            var roles = await _userManager.GetRolesAsync(user);
            var response = new UserDetailResponse(
                Id: user.Id,
                Email: user.Email ?? string.Empty,
                FirstName: user.FirstName ?? string.Empty,
                LastName: user.LastName ?? string.Empty,
                EmailConfirmed: user.EmailConfirmed,
                IsOrganizerVerified: user.IsOrganizerVerified,
                CreatedAt: user.CreatedAt,
                LastLoginAt: user.LastLoginAt,
                Roles: roles.ToArray()
            );
            return Ok(response);
        }
        [HttpPut("{id}")]
        [RequirePermission("ManageUsers")]
        [SwaggerOperation(
            Summary = "Ažurira korisnika",
            Description = "Ažurira osnovne informacije o korisniku (ime, prezime, email confirmed status). Email se ne može mijenjati."
        )]
        [SwaggerResponse(200, "Korisnik uspješno ažuriran", typeof(UserDetailResponse))]
        [SwaggerResponse(400, "Neispravni podaci")]
        [SwaggerResponse(401, "Neautorizovan pristup")]
        [SwaggerResponse(403, "Nedovoljna prava")]
        [SwaggerResponse(404, "Korisnik nije pronađen")]
        public async Task<ActionResult<UserDetailResponse>> UpdateUser(string id, [FromBody] UpdateUserRequest request)
        {
            var user = await _userManager.FindByIdAsync(id);
            if (user == null)
            {
                _logger.LogWarning("User not found for update: {UserId}", id);
                return NotFound(new { message = "Korisnik nije pronađen" });
            }
            if (!string.IsNullOrEmpty(request.Email) && request.Email != user.Email)
            {
                _logger.LogWarning("Attempt to change email for user {UserId} was ignored. Email cannot be changed.", id);
            }
            if (!string.IsNullOrEmpty(request.FirstName))
            {
                user.FirstName = request.FirstName;
            }
            if (!string.IsNullOrEmpty(request.LastName))
            {
                user.LastName = request.LastName;
            }
            if (request.EmailConfirmed.HasValue)
            {
                user.EmailConfirmed = request.EmailConfirmed.Value;
            }
            var result = await _userManager.UpdateAsync(user);
            if (!result.Succeeded)
            {
                _logger.LogError("Failed to update user {UserId}: {Errors}", 
                    id, string.Join(", ", result.Errors.Select(e => e.Description)));
                return BadRequest(new { message = "Greška pri ažuriranju korisnika", errors = result.Errors });
            }
            _logger.LogInformation("User {UserId} updated successfully", id);
            var roles = await _userManager.GetRolesAsync(user);
            var response = new UserDetailResponse(
                Id: user.Id,
                Email: user.Email ?? string.Empty,
                FirstName: user.FirstName ?? string.Empty,
                LastName: user.LastName ?? string.Empty,
                EmailConfirmed: user.EmailConfirmed,
                IsOrganizerVerified: user.IsOrganizerVerified,
                CreatedAt: user.CreatedAt,
                LastLoginAt: user.LastLoginAt,
                Roles: roles.ToArray()
            );
            return Ok(response);
        }
        [HttpPost("{id}/organizer-verification")]
        [RequirePermission("ApproveOrganizers")]
        [SwaggerOperation(
            Summary = "Verifikuje organizatora",
            Description = "Admin potvrđuje ili uklanja verifikaciju korisnika koji ima Organizer ulogu"
        )]
        [SwaggerResponse(200, "Verifikacija uspješno ažurirana", typeof(UserDetailResponse))]
        [SwaggerResponse(400, "Korisnik nije organizator")]
        [SwaggerResponse(401, "Neautorizovan pristup")]
        [SwaggerResponse(403, "Nedovoljna prava")]
        [SwaggerResponse(404, "Korisnik nije pronađen")]
        public async Task<ActionResult<UserDetailResponse>> SetOrganizerVerification(
            string id,
            [FromBody] OrganizerVerificationRequest request)
        {
            var user = await _userManager.FindByIdAsync(id);
            if (user == null)
            {
                _logger.LogWarning("User not found for verification: {UserId}", id);
                return NotFound(new { message = "Korisnik nije pronađen" });
            }
            var roles = await _userManager.GetRolesAsync(user);
            if (!roles.Contains("Organizer"))
            {
                return BadRequest(new { message = "Korisnik nema Organizer rolu" });
            }
            user.IsOrganizerVerified = request.IsVerified;
            var result = await _userManager.UpdateAsync(user);
            if (!result.Succeeded)
            {
                _logger.LogError("Failed to update organizer verification for {UserId}: {Errors}",
                    id, string.Join(", ", result.Errors.Select(e => e.Description)));
                return BadRequest(new { message = "Greška pri ažuriranju verifikacije", errors = result.Errors });
            }
            var response = new UserDetailResponse(
                Id: user.Id,
                Email: user.Email ?? string.Empty,
                FirstName: user.FirstName ?? string.Empty,
                LastName: user.LastName ?? string.Empty,
                EmailConfirmed: user.EmailConfirmed,
                IsOrganizerVerified: user.IsOrganizerVerified,
                CreatedAt: user.CreatedAt,
                LastLoginAt: user.LastLoginAt,
                Roles: roles.ToArray()
            );
            return Ok(response);
        }
        [HttpDelete("{id}")]
        [RequirePermission("ManageUsers")]
        [SwaggerOperation(
            Summary = "Briše korisnika",
            Description = "Trajno briše korisnika iz sistema. Ova akcija je nepovratna."
        )]
        [SwaggerResponse(200, "Korisnik uspješno obrisan")]
        [SwaggerResponse(401, "Neautorizovan pristup")]
        [SwaggerResponse(403, "Nedovoljna prava")]
        [SwaggerResponse(404, "Korisnik nije pronađen")]
        public async Task<IActionResult> DeleteUser(string id)
        {
            var user = await _userManager.FindByIdAsync(id);
            if (user == null)
            {
                _logger.LogWarning("User not found for deletion: {UserId}", id);
                return NotFound(new { message = "Korisnik nije pronađen" });
            }
            var currentUserId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (currentUserId == id)
            {
                return BadRequest(new { message = "Ne možete obrisati vlastiti nalog" });
            }
            var result = await _userManager.DeleteAsync(user);
            if (!result.Succeeded)
            {
                _logger.LogError("Failed to delete user {UserId}: {Errors}", 
                    id, string.Join(", ", result.Errors.Select(e => e.Description)));
                return BadRequest(new { message = "Greška pri brisanju korisnika", errors = result.Errors });
            }
            _logger.LogInformation("User {UserId} ({Email}) deleted successfully", id, user.Email);
            return Ok(new { message = $"Korisnik '{user.Email}' je uspješno obrisan" });
        }
        [HttpGet("{id}/orders")]
        [RequirePermission("ManageUsers")]
        [SwaggerOperation(
            Summary = "Vraća narudžbe korisnika",
            Description = "Vraća listu svih narudžbi određenog korisnika"
        )]
        [SwaggerResponse(200, "Lista narudžbi", typeof(IReadOnlyList<OrderDto>))]
        [SwaggerResponse(401, "Neautorizovan pristup")]
        [SwaggerResponse(403, "Nedovoljna prava")]
        [SwaggerResponse(404, "Korisnik nije pronađen")]
        public async Task<ActionResult<IReadOnlyList<OrderDto>>> GetUserOrders(string id, CancellationToken ct = default)
        {
            var user = await _userManager.FindByIdAsync(id);
            if (user == null)
            {
                _logger.LogWarning("User not found: {UserId}", id);
                return NotFound(new { message = "Korisnik nije pronađen" });
            }
            var orders = await _orderService.GetMyOrdersAsync(id, ct);
            _logger.LogInformation("Retrieved {Count} orders for user {UserId}", orders.Count, id);
            return Ok(orders);
        }
        [HttpGet("unverified-organizers")]
        [RequirePermission("ApproveOrganizers")]
        [SwaggerOperation(
            Summary = "Vraća neverifikovane organizatore",
            Description = "Vraća listu organizatora koji imaju Organizer rolu ali nisu verifikovani"
        )]
        [SwaggerResponse(200, "Lista neverifikovanih organizatora")]
        [SwaggerResponse(401, "Neautorizovan pristup")]
        [SwaggerResponse(403, "Nedovoljna prava")]
        public async Task<ActionResult<IEnumerable<object>>> GetUnverifiedOrganizers()
        {
            var allUsers = _userManager.Users.ToList();
            var unverifiedOrganizers = new List<object>();
            foreach (var user in allUsers)
            {
                var roles = await _userManager.GetRolesAsync(user);
                if (roles.Contains("Organizer") && !user.IsOrganizerVerified)
                {
                    unverifiedOrganizers.Add(new
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
            }
            _logger.LogInformation("Retrieved {Count} unverified organizers", unverifiedOrganizers.Count);
            return Ok(unverifiedOrganizers);
        }
        [HttpPost]
        [RequirePermission("ManageUsers")]
        [SwaggerOperation(
            Summary = "Kreira novog korisnika",
            Description = "Kreira novog korisnika sa zadanim podacima. Admin može eksplicitno dodijeliti rolu."
        )]
        [SwaggerResponse(201, "Korisnik uspješno kreiran", typeof(UserDetailResponse))]
        [SwaggerResponse(400, "Neispravni podaci")]
        [SwaggerResponse(401, "Neautorizovan pristup")]
        [SwaggerResponse(403, "Nedovoljna prava")]
        public async Task<ActionResult<UserDetailResponse>> CreateUser([FromBody] CreateUserRequest request)
        {
            if (!ModelState.IsValid)
            {
                return BadRequest(ModelState);
            }
            var normalizedEmail = _userManager.NormalizeEmail(request.Email);
            var existingUser = await _userManager.FindByEmailAsync(request.Email);
            if (existingUser != null)
            {
                _logger.LogWarning("Attempt to create user with existing email: {Email} (normalized: {NormalizedEmail})", 
                    request.Email, normalizedEmail);
                return BadRequest(new { message = "Korisnik sa ovom email adresom već postoji" });
            }
            var user = new ApplicationUser
            {
                UserName = request.Email,
                Email = request.Email,
                FirstName = request.FirstName,
                LastName = request.LastName,
                EmailConfirmed = false,
                CreatedAt = DateTime.UtcNow
            };
            var result = await _userManager.CreateAsync(user, request.Password);
            if (!result.Succeeded)
            {
                _logger.LogError("Failed to create user {Email}: {Errors}", 
                    request.Email, string.Join(", ", result.Errors.Select(e => e.Description)));
                return BadRequest(new { message = "Greška pri kreiranju korisnika", errors = result.Errors });
            }
            _logger.LogInformation("User {UserId} ({Email}) created successfully", user.Id, user.Email);
            if (!string.IsNullOrEmpty(request.RoleName))
            {
                var validRoles = new[] { "User", "Organizer", "Scanner", "Admin" };
                if (validRoles.Contains(request.RoleName))
                {
                    var roleResult = await _userManager.AddToRoleAsync(user, request.RoleName);
                    if (!roleResult.Succeeded)
                    {
                        _logger.LogWarning("Failed to assign role {Role} to user {UserId}: {Errors}", 
                            request.RoleName, user.Id, string.Join(", ", roleResult.Errors.Select(e => e.Description)));
                    }
                    else
                    {
                        _logger.LogInformation("Role {Role} assigned to user {UserId}", request.RoleName, user.Id);
                    }
                }
                else
                {
                    _logger.LogWarning("Invalid role specified: {Role}", request.RoleName);
                }
            }
            try
            {
                var token = await _userManager.GenerateEmailConfirmationTokenAsync(user);
                var confirmationLink = Url.Action("ConfirmEmail", "Auth", new { userId = user.Id, token }, Request.Scheme, Request.Host.Value);
                await _emailService.SendEmailConfirmationAsync(user.Email!, confirmationLink!);
                _logger.LogInformation("Email confirmation sent to: {Email}", user.Email);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to send email confirmation to {Email}", user.Email);
            }
            var roles = await _userManager.GetRolesAsync(user);
            var response = new UserDetailResponse(
                Id: user.Id,
                Email: user.Email ?? string.Empty,
                FirstName: user.FirstName ?? string.Empty,
                LastName: user.LastName ?? string.Empty,
                EmailConfirmed: user.EmailConfirmed,
                IsOrganizerVerified: user.IsOrganizerVerified,
                CreatedAt: user.CreatedAt,
                LastLoginAt: user.LastLoginAt,
                Roles: roles.ToArray()
            );
            return CreatedAtAction(nameof(GetUser), new { id = user.Id }, response);
        }
    }
}