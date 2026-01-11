using Karta.Model;
using Karta.Service.DTO;
using Karta.Service.Services;
using Karta.Service.Interfaces;
using Karta.Service.Exceptions;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Swashbuckle.AspNetCore.Annotations;
using System.Security.Claims;
using System.Linq;
using Karta.WebAPI.Authorization;
namespace Karta.WebAPI.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [SwaggerTag("Upravljanje autentifikacijom korisnika - registracija, prijava, JWT tokeni")]
    public class AuthController : ControllerBase
    {
        private readonly UserManager<ApplicationUser> _userManager;
        private readonly SignInManager<ApplicationUser> _signInManager;
        private readonly IEmailService _emailService;
        private readonly IJwtService _jwtService;
        private readonly IPasswordResetService _passwordResetService;
        private readonly ILogger<AuthController> _logger;
        public AuthController(
            UserManager<ApplicationUser> userManager, 
            SignInManager<ApplicationUser> signInManager, 
            IEmailService emailService,
            IJwtService jwtService,
            IPasswordResetService passwordResetService,
            ILogger<AuthController> logger)
        {
            _userManager = userManager;
            _signInManager = signInManager;
            _emailService = emailService;
            _jwtService = jwtService;
            _passwordResetService = passwordResetService;
            _logger = logger;
        }
        [HttpPost("register")]
        [SwaggerOperation(
            Summary = "Registracija novog korisnika",
            Description = "Kreira novi korisnički račun i automatski dodjeljuje rolu na osnovu tipa klijenta. Šalje email za potvrdu."
        )]
        [SwaggerResponse(200, "Korisnik je uspješno registriran", typeof(object))]
        [SwaggerResponse(400, "Neispravni podaci ili korisnik već postoji", typeof(ApiErrorResponse))]
        public async Task<IActionResult> Register(
            [FromBody] RegisterRequest request,
            [FromHeader(Name = "X-Client-Type")] string? clientType = null)
        {
            if (string.IsNullOrEmpty(clientType))
            {
                clientType = Request.Headers["X-Client-Type"].FirstOrDefault();
            }
            _logger.LogInformation("User registration attempt for email: {Email}", request.Email);
            _logger.LogInformation("X-Client-Type header value (FromHeader): {ClientType}", 
                Request.Headers["X-Client-Type"].FirstOrDefault() ?? "NULL");
            _logger.LogInformation("X-Client-Type header value (parameter): {ClientType}", clientType ?? "NULL");
            if (!ModelState.IsValid)
            {
                _logger.LogWarning("Invalid model state for user registration: {Email}", request.Email);
                return BadRequest(ModelState);
            }
            var allowedClientTypes = new[] { "karta_desktop", "karta_mobile" };
            if (!string.IsNullOrEmpty(clientType) && !allowedClientTypes.Contains(clientType))
            {
                _logger.LogWarning("Invalid client type provided: {ClientType} for email: {Email}", 
                    clientType, request.Email);
                return BadRequest(new { message = "Invalid client type. Must be 'karta_desktop' or 'karta_mobile'." });
            }
            var existingUser = await _userManager.FindByEmailAsync(request.Email);
            if (existingUser != null)
            {
                _logger.LogWarning("Attempt to register user with existing email: {Email}", request.Email);
                return BadRequest(new { message = "Korisnik sa ovom email adresom već postoji" });
            }
            var user = new ApplicationUser
            {
                UserName = request.Email,
                Email = request.Email,
                FirstName = request.FirstName,
                LastName = request.LastName
            };
            var result = await _userManager.CreateAsync(user, request.Password);
            if (result.Succeeded)
            {
                _logger.LogInformation("User successfully registered: {UserId}, {Email}", user.Id, user.Email);
                string roleToAssign = DetermineDefaultRole(clientType);
                _logger.LogInformation("Attempting to assign role {Role} to user {Email} (ClientType: {ClientType})", 
                    roleToAssign, user.Email, clientType ?? "not specified");
                var roleManager = HttpContext.RequestServices.GetRequiredService<RoleManager<ApplicationRole>>();
                var role = await roleManager.FindByNameAsync(roleToAssign);
                if (role == null)
                {
                    _logger.LogWarning("Role '{RoleName}' not found in database. User {Email} registered without role.", 
                        roleToAssign, user.Email);
                }
                else
                {
                    var existingRoles = await _userManager.GetRolesAsync(user);
                    if (existingRoles.Any())
                    {
                        _logger.LogInformation("User {Email} already has roles: {Roles}. Removing before assigning new role.", 
                            user.Email, string.Join(", ", existingRoles));
                        await _userManager.RemoveFromRolesAsync(user, existingRoles);
                    }
                    var roleResult = await _userManager.AddToRoleAsync(user, roleToAssign);
                    if (roleResult.Succeeded)
                    {
                        _logger.LogInformation("✅ Role '{Role}' successfully assigned to user: {Email} (ClientType: {ClientType})", 
                            roleToAssign, user.Email, clientType ?? "not specified");
                    }
                    else
                    {
                        _logger.LogError("❌ Failed to assign role '{Role}' to user {Email}: {Errors}", 
                            roleToAssign, user.Email, string.Join(", ", roleResult.Errors.Select(e => e.Description)));
                    }
                }
                var token = await _userManager.GenerateEmailConfirmationTokenAsync(user);
                var confirmationLink = Url.Action("ConfirmEmail", "Auth", new { userId = user.Id, token }, Request.Scheme);
                await _emailService.SendEmailConfirmationAsync(user.Email!, confirmationLink!);
                _logger.LogInformation("Email confirmation sent to: {Email}", user.Email);
                return Ok(new { message = "User created successfully. Please check your email to confirm your account." });
            }
            _logger.LogWarning("User registration failed for email: {Email}, Errors: {@Errors}", 
                request.Email, result.Errors.Select(e => e.Description));
            foreach (var error in result.Errors)
            {
                ModelState.AddModelError(string.Empty, error.Description);
            }
            return BadRequest(ModelState);
        }
        [HttpPost("login")]
        [SwaggerOperation(
            Summary = "Prijava korisnika",
            Description = "Autentifikuje korisnika i vraća JWT access token i refresh token"
        )]
        [SwaggerResponse(200, "Uspješna prijava", typeof(AuthResponse))]
        [SwaggerResponse(400, "Neispravni podaci za prijavu", typeof(ApiErrorResponse))]
        public async Task<IActionResult> Login([FromBody] LoginRequest request)
        {
            var clientIp = HttpContext.Connection.RemoteIpAddress?.ToString() ?? "Unknown";
            _logger.LogInformation("Login attempt for email: {Email} from IP: {IP}", request.Email, clientIp);
            if (!ModelState.IsValid)
            {
                _logger.LogWarning("Invalid model state for login: {Email}", request.Email);
                return BadRequest(ModelState);
            }
            var normalizedEmail = _userManager.NormalizeEmail(request.Email);
            _logger.LogInformation("Searching for email: {Email}, Normalized: {NormalizedEmail}", request.Email, normalizedEmail);
            var user = await _userManager.FindByEmailAsync(request.Email);
            if (user == null)
            {
                _logger.LogWarning("Login attempt with non-existent email: {Email} (normalized: {NormalizedEmail}) from IP: {IP}", request.Email, normalizedEmail, clientIp);
                // Try to find all users with similar email pattern for debugging
                var allUsers = _userManager.Users.Select(u => new { u.Email, u.NormalizedEmail }).ToList();
                _logger.LogWarning("Available users in database: {Users}", string.Join(", ", allUsers.Select(u => $"{u.Email} (normalized: {u.NormalizedEmail})")));
                throw new UnauthorizedException("Invalid email or password");
            }
            var result = await _signInManager.CheckPasswordSignInAsync(user, request.Password, lockoutOnFailure: false);
            if (result.Succeeded)
            {
                _logger.LogInformation("Successful login for user: {UserId}, {Email} from IP: {IP}", user.Id, user.Email, clientIp);
                user.LastLoginAt = DateTime.UtcNow;
                await _userManager.UpdateAsync(user);
                var accessToken = await _jwtService.GenerateAccessTokenAsync(user);
                var refreshToken = await _jwtService.GenerateRefreshTokenAsync();
                await _jwtService.StoreRefreshTokenAsync(user.Id, refreshToken);
                var roles = await _userManager.GetRolesAsync(user);
                _logger.LogInformation("JWT tokens generated for user: {UserId}", user.Id);
                var response = new AuthResponse(
                    accessToken,
                    refreshToken,
                    DateTime.UtcNow.AddMinutes(60),
                    new UserInfo(
                        user.Id,
                        user.Email!,
                        user.FirstName ?? "",
                        user.LastName ?? "",
                        user.EmailConfirmed,
                        user.IsOrganizerVerified,
                        roles.ToArray()
                    )
                );
                return Ok(response);
            }
            _logger.LogWarning("Failed login attempt for email: {Email} from IP: {IP}, Result: {Result}", 
                request.Email, clientIp, result.ToString());
            throw new UnauthorizedException("Invalid email or password");
        }
        [HttpPost("logout")]
        [Authorize]
        [SwaggerOperation(
            Summary = "Odjava korisnika",
            Description = "Odjavljuje korisnika i poništava refresh token"
        )]
        [SwaggerResponse(200, "Uspješna odjava")]
        [SwaggerResponse(401, "Neautorizovani pristup", typeof(ApiErrorResponse))]
        public async Task<IActionResult> Logout()
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (!string.IsNullOrEmpty(userId))
            {
                await _jwtService.RevokeRefreshTokenAsync(userId);
            }
            await _signInManager.SignOutAsync();
            return Ok(new { message = "Logout successful" });
        }
        [HttpPost("refresh-token")]
        [SwaggerOperation(
            Summary = "Obnavljanje JWT tokena",
            Description = "Koristi refresh token za dobijanje novog access tokena"
        )]
        [SwaggerResponse(200, "Tokeni su uspješno obnovljeni", typeof(AuthResponse))]
        [SwaggerResponse(400, "Neispravni tokeni", typeof(ApiErrorResponse))]
        public async Task<IActionResult> RefreshToken([FromBody] RefreshTokenRequest request)
        {
            if (string.IsNullOrEmpty(request.AccessToken) || string.IsNullOrEmpty(request.RefreshToken))
                return BadRequest(new { message = "Invalid token" });
            try
            {
                var principal = await _jwtService.GetPrincipalFromExpiredTokenAsync(request.AccessToken);
                var userId = principal?.FindFirstValue(ClaimTypes.NameIdentifier);
                if (string.IsNullOrEmpty(userId))
                    return BadRequest(new { message = "Invalid token" });
                var isValidRefreshToken = await _jwtService.ValidateRefreshTokenAsync(userId, request.RefreshToken);
                if (!isValidRefreshToken)
                    return BadRequest(new { message = "Invalid refresh token" });
                var user = await _userManager.FindByIdAsync(userId);
                if (user == null)
                    return BadRequest(new { message = "User not found" });
                var newAccessToken = await _jwtService.GenerateAccessTokenAsync(user);
                var newRefreshToken = await _jwtService.GenerateRefreshTokenAsync();
                await _jwtService.StoreRefreshTokenAsync(user.Id, newRefreshToken);
                var roles = await _userManager.GetRolesAsync(user);
                var response = new AuthResponse(
                    newAccessToken,
                    newRefreshToken,
                    DateTime.UtcNow.AddMinutes(60),
                    new UserInfo(
                        user.Id,
                        user.Email!,
                        user.FirstName ?? "",
                        user.LastName ?? "",
                        user.EmailConfirmed,
                        user.IsOrganizerVerified,
                        roles.ToArray()
                    )
                );
                return Ok(response);
            }
            catch (Exception)
            {
                return BadRequest(new { message = "Invalid token" });
            }
        }
        [HttpGet("confirm-email")]
        public async Task<IActionResult> ConfirmEmail(string userId, string token)
        {
            if (string.IsNullOrEmpty(userId) || string.IsNullOrEmpty(token))
                return BadRequest(new { message = "Invalid confirmation link" });
            var user = await _userManager.FindByIdAsync(userId);
            if (user == null)
                return BadRequest(new { message = "User not found" });
            var result = await _userManager.ConfirmEmailAsync(user, token);
            if (result.Succeeded)
                return Ok(new { message = "Email confirmed successfully" });
            return BadRequest(new { message = "Email confirmation failed" });
        }
        [HttpPost("resend-confirmation")]
        public async Task<IActionResult> ResendConfirmation([FromBody] ResendConfirmationRequest request)
        {
            if (!ModelState.IsValid)
                return BadRequest(ModelState);
            var user = await _userManager.FindByEmailAsync(request.Email);
            if (user == null)
                return BadRequest(new { message = "User not found" });
            if (await _userManager.IsEmailConfirmedAsync(user))
                return BadRequest(new { message = "Email is already confirmed" });
            var token = await _userManager.GenerateEmailConfirmationTokenAsync(user);
            var confirmationLink = Url.Action("ConfirmEmail", "Auth", new { userId = user.Id, token }, Request.Scheme);
            return Ok(new { message = "Confirmation email sent" });
        }
        [HttpGet("validate-token")]
        [Authorize]
        [SwaggerOperation(
            Summary = "Validacija JWT tokena",
            Description = "Provjerava valjanost JWT tokena i vraća informacije o korisniku"
        )]
        [SwaggerResponse(200, "Token je valjan", typeof(TokenValidationResponse))]
        [SwaggerResponse(401, "Neautorizovani pristup", typeof(ApiErrorResponse))]
        public async Task<IActionResult> ValidateToken()
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            var email = User.FindFirstValue(ClaimTypes.Email);
            var roles = User.FindAll(ClaimTypes.Role).Select(c => c.Value).ToArray();
            var response = new TokenValidationResponse(
                true,
                userId,
                email,
                roles
            );
            return Ok(response);
        }
        [HttpPost("test-email")]
        [AllowAnonymous]
        [SwaggerOperation(
            Summary = "Test email slanja",
            Description = "Testira email konfiguraciju slanjem test poruke."
        )]
        [SwaggerResponse(200, "Test email je uspješno poslan")]
        [SwaggerResponse(400, "Neispravni podaci")]
        public async Task<ActionResult> TestEmail([FromBody] string email)
        {
            if (string.IsNullOrEmpty(email))
                return BadRequest(new { message = "Email adresa je obavezna" });
            try
            {
                var testLink = "https://karta.ba/confirm-email?token=test-token-123";
                await _emailService.SendEmailConfirmationAsync(email, testLink, CancellationToken.None);
                _logger.LogInformation("Test email uspješno poslan na {Email}", email);
                return Ok(new { message = $"Test email je uspješno poslan na {email}" });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Greška pri slanju test emaila na {Email}", email);
                return StatusCode(500, new { message = $"Greška pri slanju emaila: {ex.Message}" });
            }
        }
        [HttpPost("forgot-password")]
        [AllowAnonymous]
        [SwaggerOperation(Summary = "Zatraži reset password-a", Description = "Šalje email sa linkom za reset password-a")]
        [SwaggerResponse(200, "Email sa reset linkom je poslan")]
        [SwaggerResponse(400, "Neispravni podaci")]
        public async Task<IActionResult> ForgotPassword([FromBody] ForgotPasswordRequest request)
        {
            try
            {
                var result = await _passwordResetService.RequestPasswordResetAsync(request.Email);
                return Ok(new { message = "If the email exists, a password reset link has been sent." });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error processing forgot password request for {Email}", request.Email);
                return StatusCode(500, new { message = "An error occurred while processing your request." });
            }
        }
        [HttpGet("profile")]
        [Authorize]
        [SwaggerOperation(
            Summary = "Vraća vlastiti profil",
            Description = "Vraća informacije o trenutno ulogovanom korisniku"
        )]
        [SwaggerResponse(200, "Profil uspješno vraćen", typeof(UserDetailResponse))]
        [SwaggerResponse(401, "Neautorizovan pristup")]
        [SwaggerResponse(404, "Korisnik nije pronađen")]
        public async Task<IActionResult> GetProfile()
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrEmpty(userId))
            {
                return Unauthorized(new { message = "Neautorizovan pristup" });
            }
            var user = await _userManager.FindByIdAsync(userId);
            if (user == null)
            {
                _logger.LogWarning("User not found for profile retrieval: {UserId}", userId);
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
            _logger.LogInformation("Profile retrieved successfully for user {UserId}", userId);
            return Ok(response);
        }
        [HttpPut("profile")]
        [Authorize]
        [SwaggerOperation(
            Summary = "Ažurira vlastiti profil",
            Description = "Omogućava korisniku da ažurira svoje osnovne informacije (ime, prezime). Email se ne može mijenjati."
        )]
        [SwaggerResponse(200, "Profil uspješno ažuriran", typeof(AuthResponse))]
        [SwaggerResponse(400, "Neispravni podaci")]
        [SwaggerResponse(401, "Neautorizovan pristup")]
        public async Task<IActionResult> UpdateProfile([FromBody] UpdateUserRequest request)
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrEmpty(userId))
            {
                return Unauthorized(new { message = "Neautorizovan pristup" });
            }
            var user = await _userManager.FindByIdAsync(userId);
            if (user == null)
            {
                _logger.LogWarning("User not found for profile update: {UserId}", userId);
                return NotFound(new { message = "Korisnik nije pronađen" });
            }
            if (!string.IsNullOrEmpty(request.Email) && request.Email != user.Email)
            {
                _logger.LogWarning("Attempt to change email for user {UserId} was ignored. Email cannot be changed.", userId);
            }
            if (!string.IsNullOrEmpty(request.FirstName))
            {
                user.FirstName = request.FirstName;
            }
            if (!string.IsNullOrEmpty(request.LastName))
            {
                user.LastName = request.LastName;
            }
            var result = await _userManager.UpdateAsync(user);
            if (!result.Succeeded)
            {
                _logger.LogError("Failed to update profile for user {UserId}: {Errors}", 
                    userId, string.Join(", ", result.Errors.Select(e => e.Description)));
                return BadRequest(new { message = "Greška pri ažuriranju profila", errors = result.Errors });
            }
            _logger.LogInformation("Profile updated successfully for user {UserId}", userId);
            var accessToken = await _jwtService.GenerateAccessTokenAsync(user);
            var refreshToken = await _jwtService.GenerateRefreshTokenAsync();
            await _jwtService.StoreRefreshTokenAsync(user.Id, refreshToken);
            var roles = await _userManager.GetRolesAsync(user);
            var response = new AuthResponse(
                accessToken,
                refreshToken,
                DateTime.UtcNow.AddMinutes(60),
                new UserInfo(
                    user.Id,
                    user.Email!,
                    user.FirstName ?? "",
                    user.LastName ?? "",
                    user.EmailConfirmed,
                    user.IsOrganizerVerified,
                    roles.ToArray()
                )
            );
            return Ok(response);
        }
        [HttpPost("reset-password")]
        [AllowAnonymous]
        [SwaggerOperation(Summary = "Reset password", Description = "Resetuje password koristeći token iz email-a")]
        [SwaggerResponse(200, "Password je uspješno resetovan")]
        [SwaggerResponse(400, "Neispravni token ili password")]
        public async Task<IActionResult> ResetPassword([FromBody] ResetPasswordRequest request)
        {
            try
            {
                if (request.NewPassword != request.ConfirmPassword)
                {
                    return BadRequest(new { message = "Passwords do not match." });
                }
                if (string.IsNullOrEmpty(request.NewPassword) || request.NewPassword.Length < 6)
                {
                    return BadRequest(new { message = "Password must be at least 6 characters long." });
                }
                var result = await _passwordResetService.ResetPasswordAsync(request.Token, request.NewPassword);
                if (!result)
                {
                    return BadRequest(new { message = "Invalid or expired reset token." });
                }
                return Ok(new { message = "Password has been successfully reset." });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error processing password reset for token {Token}", request.Token);
                return StatusCode(500, new { message = "An error occurred while resetting your password." });
            }
        }
        [HttpDelete("users/bulk-delete")]
        [RequirePermission("ManageUsers")]
        [SwaggerOperation(Summary = "Briše sve korisnike osim određenog", Description = "Briše sve korisnike iz sistema osim korisnika sa određenim ID-om")]
        [SwaggerResponse(200, "Korisnici uspješno obrisani")]
        [SwaggerResponse(400, "Neispravni podaci")]
        [SwaggerResponse(401, "Neautorizovan pristup")]
        [SwaggerResponse(403, "Nedovoljna prava")]
        [SwaggerResponse(404, "Korisnik za zadržavanje nije pronađen")]
        public async Task<IActionResult> BulkDeleteUsers([FromBody] BulkDeleteUsersRequest request)
        {
            _logger.LogInformation("Bulk delete users request - keeping user: {KeepUserId}", request.KeepUserId);
            if (string.IsNullOrEmpty(request.KeepUserId))
            {
                return BadRequest("KeepUserId je obavezan");
            }
            var userToKeep = await _userManager.FindByIdAsync(request.KeepUserId);
            if (userToKeep == null)
            {
                _logger.LogWarning("User to keep not found: {KeepUserId}", request.KeepUserId);
                return NotFound($"Korisnik sa ID-om '{request.KeepUserId}' nije pronađen");
            }
            var allUsers = _userManager.Users.Where(u => u.Id != request.KeepUserId).ToList();
            if (!allUsers.Any())
            {
                _logger.LogInformation("No users to delete - only keeping user exists");
                return Ok(new { message = "Nema korisnika za brisanje", deletedCount = 0 });
            }
            var deletedCount = 0;
            var errors = new List<string>();
            _logger.LogInformation("Starting bulk delete of {UserCount} users", allUsers.Count);
            foreach (var user in allUsers)
            {
                try
                {
                    _logger.LogInformation("Deleting user: {UserId}, {Email}", user.Id, user.Email);
                    var roles = await _userManager.GetRolesAsync(user);
                    if (roles.Any())
                    {
                        await _userManager.RemoveFromRolesAsync(user, roles);
                        _logger.LogInformation("Removed roles from user {Email}: {Roles}", user.Email, string.Join(", ", roles));
                    }
                    var result = await _userManager.DeleteAsync(user);
                    if (result.Succeeded)
                    {
                        deletedCount++;
                        _logger.LogInformation("Successfully deleted user: {Email}", user.Email);
                    }
                    else
                    {
                        var errorMessages = result.Errors.Select(e => e.Description);
                        errors.AddRange(errorMessages.Select(e => $"Korisnik {user.Email}: {e}"));
                        _logger.LogWarning("Failed to delete user {Email}: {Errors}", user.Email, string.Join(", ", errorMessages));
                    }
                }
                catch (Exception ex)
                {
                    var errorMsg = $"Greška pri brisanju korisnika {user.Email}: {ex.Message}";
                    errors.Add(errorMsg);
                    _logger.LogError(ex, "Exception while deleting user {Email}", user.Email);
                }
            }
            var response = new
            {
                message = $"Uspješno obrisano {deletedCount} korisnika",
                deletedCount = deletedCount,
                keptUserId = request.KeepUserId,
                keptUserEmail = userToKeep.Email,
                errors = errors
            };
            _logger.LogInformation("Bulk delete completed - deleted {DeletedCount} users, kept {KeptUserId}", deletedCount, request.KeepUserId);
            if (errors.Any())
            {
                return Ok(response);
            }
            return Ok(response);
        }
        private string DetermineDefaultRole(string? clientType)
        {
            return clientType switch
            {
                "karta_desktop" => "Organizer",
                "karta_mobile" => "User",
                _ => "User"
            };
        }
    }
    public record BulkDeleteUsersRequest(string KeepUserId);
}