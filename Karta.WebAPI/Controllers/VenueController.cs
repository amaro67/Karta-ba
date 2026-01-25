using Karta.Model;
using Karta.Service.DTO;
using Karta.Service.Interfaces;
using Karta.WebAPI.Authorization;
using Karta.WebAPI.Filters;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Swashbuckle.AspNetCore.Annotations;
using System.Security.Claims;
namespace Karta.WebAPI.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [SwaggerTag("Upravljanje mjestima (venue) za evente")]
    public class VenueController : ControllerBase
    {
        private readonly IVenueService _venueService;
        private readonly UserManager<ApplicationUser> _userManager;
        private readonly ILogger<VenueController> _logger;

        public VenueController(IVenueService venueService, UserManager<ApplicationUser> userManager, ILogger<VenueController> logger)
        {
            _venueService = venueService;
            _userManager = userManager;
            _logger = logger;
        }

        [HttpGet]
        [SwaggerOperation(Summary = "Dohvata sva mjesta",
                         Description = "Vraća listu svih mjesta, opcionalno filtrirano po gradu")]
        [SwaggerResponse(200, "Uspešno vraćena lista mjesta", typeof(IReadOnlyList<VenueDto>))]
        public async Task<ActionResult<IReadOnlyList<VenueDto>>> GetVenues([FromQuery] string? city = null)
        {
            var venues = await _venueService.GetVenuesAsync(city);
            return Ok(venues);
        }

        [HttpGet("{id}")]
        [SwaggerOperation(Summary = "Dohvata mjesto po ID-u")]
        [SwaggerResponse(200, "Uspešno vraćeno mjesto", typeof(VenueDto))]
        [SwaggerResponse(404, "Mjesto nije pronađeno")]
        public async Task<ActionResult<VenueDto>> GetVenue(Guid id)
        {
            var venue = await _venueService.GetVenueAsync(id);
            if (venue == null)
                return NotFound();

            return Ok(venue);
        }

        [HttpGet("my-venues")]
        [Authorize]
        [RequirePermission("CreateEvents")]
        [SwaggerOperation(Summary = "Dohvata mjesta kreirana od strane trenutnog korisnika",
                         Description = "Vraća listu mjesta koje je kreirao organizator")]
        [SwaggerResponse(200, "Uspešno vraćena lista mjesta", typeof(IReadOnlyList<VenueDto>))]
        [SwaggerResponse(401, "Korisnik nije autentifikovan")]
        public async Task<ActionResult<IReadOnlyList<VenueDto>>> GetMyVenues()
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrEmpty(userId))
                return Unauthorized();

            var venues = await _venueService.GetMyVenuesAsync(userId);
            return Ok(venues);
        }

        [HttpPost]
        [Authorize]
        [RequirePermission("CreateEvents")]
        [ServiceFilter(typeof(ValidationFilterAttribute))]
        [SwaggerOperation(Summary = "Kreira novo mjesto (organizator)",
                         Description = "Kreira novo mjesto za evente. Dostupno organizatorima.")]
        [SwaggerResponse(201, "Mjesto uspešno kreirano", typeof(VenueDto))]
        [SwaggerResponse(400, "Neispravni podaci")]
        [SwaggerResponse(401, "Korisnik nije autentifikovan")]
        [SwaggerResponse(403, "Nedovoljna prava")]
        public async Task<ActionResult<VenueDto>> CreateVenue([FromBody] CreateVenueRequest request)
        {
            if (!ModelState.IsValid)
                return BadRequest(ModelState);

            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrEmpty(userId))
                return Unauthorized();

            try
            {
                var venue = await _venueService.CreateVenueAsync(request, userId);
                return CreatedAtAction(nameof(GetVenue), new { id = venue.Id }, venue);
            }
            catch (ArgumentException ex)
            {
                return BadRequest(ex.Message);
            }
        }

        [HttpPut("{id}")]
        [Authorize]
        [RequirePermission("CreateEvents")]
        [ServiceFilter(typeof(ValidationFilterAttribute))]
        [SwaggerOperation(Summary = "Ažurira mjesto (vlasnik ili admin)")]
        [SwaggerResponse(200, "Mjesto uspešno ažurirano", typeof(VenueDto))]
        [SwaggerResponse(400, "Neispravni podaci")]
        [SwaggerResponse(401, "Korisnik nije autentifikovan")]
        [SwaggerResponse(403, "Nedovoljna prava")]
        [SwaggerResponse(404, "Mjesto nije pronađeno")]
        public async Task<ActionResult<VenueDto>> UpdateVenue(Guid id, [FromBody] UpdateVenueRequest request)
        {
            if (!ModelState.IsValid)
                return BadRequest(ModelState);

            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrEmpty(userId))
                return Unauthorized();

            var user = await _userManager.FindByIdAsync(userId);
            if (user == null)
                return Unauthorized();

            var roles = await _userManager.GetRolesAsync(user);
            var isAdmin = roles.Contains("Admin");

            try
            {
                var venue = await _venueService.UpdateVenueAsync(id, request, userId, isAdmin);
                return Ok(venue);
            }
            catch (ArgumentException ex)
            {
                return NotFound(ex.Message);
            }
            catch (UnauthorizedAccessException ex)
            {
                return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
            }
        }

        [HttpDelete("{id}")]
        [Authorize]
        [RequirePermission("CreateEvents")]
        [SwaggerOperation(Summary = "Briše mjesto (vlasnik ili admin)")]
        [SwaggerResponse(204, "Mjesto uspešno obrisano")]
        [SwaggerResponse(400, "Mjesto ima povezane evente")]
        [SwaggerResponse(401, "Korisnik nije autentifikovan")]
        [SwaggerResponse(403, "Nedovoljna prava")]
        [SwaggerResponse(404, "Mjesto nije pronađeno")]
        public async Task<ActionResult> DeleteVenue(Guid id)
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrEmpty(userId))
                return Unauthorized();

            var user = await _userManager.FindByIdAsync(userId);
            if (user == null)
                return Unauthorized();

            var roles = await _userManager.GetRolesAsync(user);
            var isAdmin = roles.Contains("Admin");

            try
            {
                var success = await _venueService.DeleteVenueAsync(id, userId, isAdmin);
                if (!success)
                    return NotFound();

                return NoContent();
            }
            catch (UnauthorizedAccessException ex)
            {
                return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
        }
    }
}
