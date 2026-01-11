using Karta.Service.DTO;
using Karta.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Swashbuckle.AspNetCore.Annotations;
namespace Karta.WebAPI.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [SwaggerTag("Upravljanje rolama i dozvolama korisnika")]
    public class RoleController : ControllerBase
    {
        private readonly IRoleService _roleService;
        private readonly ILogger<RoleController> _logger;
        public RoleController(IRoleService roleService, ILogger<RoleController> logger)
        {
            _roleService = roleService;
            _logger = logger;
        }
        [HttpPost]
        [Authorize(Roles = "Admin")]
        [SwaggerOperation(
            Summary = "Kreira novu rolu",
            Description = "Kreira novu rolu sa zadanim nazivom i opisom. Samo admin može kreirati role."
        )]
        [SwaggerResponse(200, "Rola uspješno kreirana", typeof(RoleResponse))]
        [SwaggerResponse(400, "Neispravni podaci")]
        [SwaggerResponse(401, "Nije autorizovan")]
        [SwaggerResponse(403, "Nema dozvolu")]
        [SwaggerResponse(409, "Rola već postoji")]
        public async Task<ActionResult<RoleResponse>> CreateRole([FromBody] CreateRoleRequest request)
        {
            try
            {
                _logger.LogInformation("Kreiranje nove role: {RoleName}", request.Name);
                var role = await _roleService.CreateRoleAsync(request);
                return Ok(role);
            }
            catch (InvalidOperationException ex)
            {
                _logger.LogWarning("Greška pri kreiranju role: {Message}", ex.Message);
                return Conflict(new { message = ex.Message });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Neočekivana greška pri kreiranju role");
                throw;
            }
        }
        [HttpGet]
        [SwaggerOperation(
            Summary = "Dohvata sve role",
            Description = "Dohvata listu svih rola sa brojem korisnika u svakoj roli."
        )]
        [SwaggerResponse(200, "Lista rola", typeof(List<RoleResponse>))]
        [SwaggerResponse(401, "Nije autorizovan")]
        [SwaggerResponse(403, "Nema dozvolu")]
        public async Task<ActionResult<List<RoleResponse>>> GetAllRoles()
        {
            _logger.LogInformation("Dohvatanje svih rola");
            var roles = await _roleService.GetAllRolesAsync();
            return Ok(roles);
        }
        [HttpGet("{id}")]
        [SwaggerOperation(
            Summary = "Dohvata rolu po ID-u",
            Description = "Dohvata detalje role na osnovu ID-a."
        )]
        [SwaggerResponse(200, "Rola pronađena", typeof(RoleResponse))]
        [SwaggerResponse(401, "Nije autorizovan")]
        [SwaggerResponse(403, "Nema dozvolu")]
        [SwaggerResponse(404, "Rola nije pronađena")]
        public async Task<ActionResult<RoleResponse>> GetRoleById(string id)
        {
            _logger.LogInformation("Dohvatanje role po ID-u: {RoleId}", id);
            var role = await _roleService.GetRoleByIdAsync(id);
            if (role == null)
            {
                return NotFound(new { message = "Rola nije pronađena" });
            }
            return Ok(role);
        }
        [HttpGet("name/{name}")]
        [SwaggerOperation(
            Summary = "Dohvata rolu po nazivu",
            Description = "Dohvata detalje role na osnovu naziva."
        )]
        [SwaggerResponse(200, "Rola pronađena", typeof(RoleResponse))]
        [SwaggerResponse(401, "Nije autorizovan")]
        [SwaggerResponse(403, "Nema dozvolu")]
        [SwaggerResponse(404, "Rola nije pronađena")]
        public async Task<ActionResult<RoleResponse>> GetRoleByName(string name)
        {
            _logger.LogInformation("Dohvatanje role po nazivu: {RoleName}", name);
            var role = await _roleService.GetRoleByNameAsync(name);
            if (role == null)
            {
                return NotFound(new { message = "Rola nije pronađena" });
            }
            return Ok(role);
        }
        [HttpPut]
        [Authorize(Roles = "Admin")]
        [SwaggerOperation(
            Summary = "Ažurira rolu",
            Description = "Ažurira postojeću rolu sa novim podacima."
        )]
        [SwaggerResponse(200, "Rola uspješno ažurirana", typeof(RoleResponse))]
        [SwaggerResponse(400, "Neispravni podaci")]
        [SwaggerResponse(401, "Nije autorizovan")]
        [SwaggerResponse(403, "Nema dozvolu")]
        [SwaggerResponse(404, "Rola nije pronađena")]
        [SwaggerResponse(409, "Rola sa novim nazivom već postoji")]
        public async Task<ActionResult<RoleResponse>> UpdateRole([FromBody] UpdateRoleRequest request)
        {
            try
            {
                _logger.LogInformation("Ažuriranje role: {RoleId}", request.Id);
                var role = await _roleService.UpdateRoleAsync(request);
                return Ok(role);
            }
            catch (KeyNotFoundException ex)
            {
                _logger.LogWarning("Rola nije pronađena: {Message}", ex.Message);
                return NotFound(new { message = ex.Message });
            }
            catch (InvalidOperationException ex)
            {
                _logger.LogWarning("Greška pri ažuriranju role: {Message}", ex.Message);
                return Conflict(new { message = ex.Message });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Neočekivana greška pri ažuriranju role");
                throw;
            }
        }
        [HttpDelete("{id}")]
        [Authorize(Roles = "Admin")]
        [SwaggerOperation(
            Summary = "Briše rolu",
            Description = "Briše rolu ako nema korisnika koji je koriste. Samo admin može brisati role."
        )]
        [SwaggerResponse(200, "Rola uspješno obrisana")]
        [SwaggerResponse(401, "Nije autorizovan")]
        [SwaggerResponse(403, "Nema dozvolu")]
        [SwaggerResponse(404, "Rola nije pronađena")]
        [SwaggerResponse(409, "Rola se ne može obrisati jer ima korisnika")]
        public async Task<ActionResult> DeleteRole(string id)
        {
            try
            {
                _logger.LogInformation("Brisanje role: {RoleId}", id);
                var result = await _roleService.DeleteRoleAsync(id);
                return Ok(new { message = "Rola uspješno obrisana" });
            }
            catch (KeyNotFoundException ex)
            {
                _logger.LogWarning("Rola nije pronađena: {Message}", ex.Message);
                return NotFound(new { message = ex.Message });
            }
            catch (InvalidOperationException ex)
            {
                _logger.LogWarning("Greška pri brisanju role: {Message}", ex.Message);
                return Conflict(new { message = ex.Message });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Neočekivana greška pri brisanju role");
                throw;
            }
        }
        [HttpPost("users")]
        [Authorize(Roles = "Admin")]
        [SwaggerOperation(
            Summary = "Dodaje rolu korisniku",
            Description = "Dodaje određenu rolu korisniku. Samo admin može dodavati role korisnicima."
        )]
        [SwaggerResponse(200, "Rola uspješno dodana korisniku")]
        [SwaggerResponse(400, "Neispravni podaci")]
        [SwaggerResponse(401, "Nije autorizovan")]
        [SwaggerResponse(403, "Nema dozvolu")]
        [SwaggerResponse(404, "Korisnik ili rola nije pronađena")]
        [SwaggerResponse(409, "Korisnik već ima tu rolu")]
        public async Task<ActionResult> AddUserToRole([FromBody] AddUserToRoleRequest request)
        {
            try
            {
                _logger.LogInformation("Dodavanje role {RoleName} korisniku {UserId}", request.RoleName, request.UserId);
                var result = await _roleService.AddUserToRoleAsync(request);
                return Ok(new { message = "Rola uspješno dodana korisniku" });
            }
            catch (KeyNotFoundException ex)
            {
                _logger.LogWarning("Korisnik ili rola nije pronađena: {Message}", ex.Message);
                return NotFound(new { message = ex.Message });
            }
            catch (InvalidOperationException ex)
            {
                _logger.LogWarning("Greška pri dodavanju role: {Message}", ex.Message);
                return Conflict(new { message = ex.Message });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Neočekivana greška pri dodavanju role korisniku");
                throw;
            }
        }
        [HttpDelete("users")]
        [Authorize(Roles = "Admin")]
        [SwaggerOperation(
            Summary = "Uklanja rolu od korisnika",
            Description = "Uklanja određenu rolu od korisnika. Samo admin može uklanjati role od korisnika."
        )]
        [SwaggerResponse(200, "Rola uspješno uklonjena od korisnika")]
        [SwaggerResponse(400, "Neispravni podaci")]
        [SwaggerResponse(401, "Nije autorizovan")]
        [SwaggerResponse(403, "Nema dozvolu")]
        [SwaggerResponse(404, "Korisnik ili rola nije pronađena")]
        [SwaggerResponse(409, "Korisnik nema tu rolu")]
        public async Task<ActionResult> RemoveUserFromRole([FromBody] RemoveUserFromRoleRequest request)
        {
            try
            {
                _logger.LogInformation("Uklanjanje role {RoleName} od korisnika {UserId}", request.RoleName, request.UserId);
                var result = await _roleService.RemoveUserFromRoleAsync(request);
                return Ok(new { message = "Rola uspješno uklonjena od korisnika" });
            }
            catch (KeyNotFoundException ex)
            {
                _logger.LogWarning("Korisnik ili rola nije pronađena: {Message}", ex.Message);
                return NotFound(new { message = ex.Message });
            }
            catch (InvalidOperationException ex)
            {
                _logger.LogWarning("Greška pri uklanjanju role: {Message}", ex.Message);
                return Conflict(new { message = ex.Message });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Neočekivana greška pri uklanjanju role od korisnika");
                throw;
            }
        }
        [HttpGet("users/{roleName}")]
        [Authorize(Roles = "Admin")]
        [SwaggerOperation(
            Summary = "Dohvata korisnike sa određenom rolom",
            Description = "Dohvata listu svih korisnika koji imaju određenu rolu. Samo admin može vidjeti korisnike po rolama."
        )]
        [SwaggerResponse(200, "Lista korisnika", typeof(UsersInRoleResponse))]
        [SwaggerResponse(401, "Nije autorizovan")]
        [SwaggerResponse(403, "Nema dozvolu")]
        [SwaggerResponse(404, "Rola nije pronađena")]
        public async Task<ActionResult<UsersInRoleResponse>> GetUsersInRole(string roleName)
        {
            try
            {
                _logger.LogInformation("Dohvatanje korisnika sa rolom: {RoleName}", roleName);
                var users = await _roleService.GetUsersInRoleAsync(roleName);
                return Ok(users);
            }
            catch (KeyNotFoundException ex)
            {
                _logger.LogWarning("Rola nije pronađena: {Message}", ex.Message);
                return NotFound(new { message = ex.Message });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Neočekivana greška pri dohvatanju korisnika sa rolom");
                throw;
            }
        }
        [HttpGet("user/{userId}")]
        [Authorize(Roles = "Admin")]
        [SwaggerOperation(
            Summary = "Dohvata role korisnika",
            Description = "Dohvata listu svih rola koje ima određeni korisnik. Samo admin može vidjeti role korisnika."
        )]
        [SwaggerResponse(200, "Lista rola korisnika", typeof(List<RoleResponse>))]
        [SwaggerResponse(401, "Nije autorizovan")]
        [SwaggerResponse(403, "Nema dozvolu")]
        [SwaggerResponse(404, "Korisnik nije pronađen")]
        public async Task<ActionResult<List<RoleResponse>>> GetUserRoles(string userId)
        {
            try
            {
                _logger.LogInformation("Dohvatanje rola korisnika: {UserId}", userId);
                var roles = await _roleService.GetUserRolesAsync(userId);
                return Ok(roles);
            }
            catch (KeyNotFoundException ex)
            {
                _logger.LogWarning("Korisnik nije pronađen: {Message}", ex.Message);
                return NotFound(new { message = ex.Message });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Neočekivana greška pri dohvatanju rola korisnika");
                throw;
            }
        }
        [HttpGet("check/{userId}/{roleName}")]
        [Authorize(Roles = "Admin")]
        [SwaggerOperation(
            Summary = "Provjerava da li korisnik ima određenu rolu",
            Description = "Provjerava da li određeni korisnik ima određenu rolu. Samo admin može provjeravati role korisnika."
        )]
        [SwaggerResponse(200, "Rezultat provjere", typeof(bool))]
        [SwaggerResponse(401, "Nije autorizovan")]
        [SwaggerResponse(403, "Nema dozvolu")]
        public async Task<ActionResult<bool>> IsUserInRole(string userId, string roleName)
        {
            _logger.LogInformation("Provjera da li korisnik {UserId} ima rolu {RoleName}", userId, roleName);
            var result = await _roleService.IsUserInRoleAsync(userId, roleName);
            return Ok(result);
        }
    }
}