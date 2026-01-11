using System;
using System.Security.Claims;
using System.Threading.Tasks;
using Karta.Model;
using Karta.Service.DTO;
using Karta.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
namespace Karta.WebAPI.Controllers
{
    [ApiController]
    [Authorize]
    [Route("api/[controller]")]
    public class ScannerController : ControllerBase
    {
        private readonly IScannerService _scannerService;
        private readonly UserManager<ApplicationUser> _userManager;
        private readonly ILogger<ScannerController> _logger;
        public ScannerController(
            IScannerService scannerService,
            UserManager<ApplicationUser> userManager,
            ILogger<ScannerController> logger)
        {
            _scannerService = scannerService;
            _userManager = userManager;
            _logger = logger;
        }
        private async Task<string?> EnsureOrganizerAsync()
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrEmpty(userId))
            {
                return null;
            }
            var user = await _userManager.FindByIdAsync(userId);
            if (user == null)
            {
                return null;
            }
            var roles = await _userManager.GetRolesAsync(user);
            if (!roles.Contains("Organizer") && !roles.Contains("Admin"))
            {
                return null;
            }
            return userId;
        }
        [HttpGet("events")]
        public async Task<IActionResult> GetEventScanners()
        {
            var organizerId = await EnsureOrganizerAsync();
            if (organizerId == null)
            {
                return Forbid();
            }
            var result = await _scannerService.GetOrganizerEventScannersAsync(organizerId);
            return Ok(result);
        }
        [HttpGet("my-events")]
        public async Task<IActionResult> GetMyEvents()
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrEmpty(userId))
            {
                return Unauthorized();
            }
            var user = await _userManager.FindByIdAsync(userId);
            if (user == null)
            {
                return Unauthorized();
            }
            var roles = await _userManager.GetRolesAsync(user);
            if (!roles.Contains("Scanner"))
            {
                return Forbid();
            }
            var result = await _scannerService.GetScannerEventsAsync(userId);
            return Ok(result);
        }
        [HttpGet("users")]
        public async Task<IActionResult> GetScannerUsers()
        {
            var organizerId = await EnsureOrganizerAsync();
            if (organizerId == null)
            {
                return Forbid();
            }
            var result = await _scannerService.GetOrganizerScannersAsync(organizerId);
            return Ok(result);
        }
        [HttpPost]
        public async Task<IActionResult> CreateScanner([FromBody] CreateScannerUserRequest request)
        {
            var organizerId = await EnsureOrganizerAsync();
            if (organizerId == null)
            {
                return Forbid();
            }
            try
            {
                var scanner = await _scannerService.CreateScannerAsync(request, organizerId);
                return Ok(scanner);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to create scanner for organizer {OrganizerId}", organizerId);
                return BadRequest(new { message = ex.Message });
            }
        }
        [HttpPost("assign")]
        public async Task<IActionResult> AssignScanner([FromBody] AssignScannerRequest request)
        {
            var organizerId = await EnsureOrganizerAsync();
            if (organizerId == null)
            {
                return Forbid();
            }
            try
            {
                await _scannerService.AssignScannerToEventAsync(request, organizerId);
                return Ok(new { success = true });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to assign scanner {ScannerId} to event {EventId}", request.ScannerUserId, request.EventId);
                return BadRequest(new { message = ex.Message });
            }
        }
        [HttpDelete("assign/{eventId:guid}/{scannerUserId}")]
        public async Task<IActionResult> RemoveScanner(Guid eventId, string scannerUserId)
        {
            var organizerId = await EnsureOrganizerAsync();
            if (organizerId == null)
            {
                return Forbid();
            }
            try
            {
                await _scannerService.RemoveScannerFromEventAsync(new AssignScannerRequest(eventId, scannerUserId), organizerId);
                return NoContent();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to remove scanner {ScannerId} from event {EventId}", scannerUserId, eventId);
                return BadRequest(new { message = ex.Message });
            }
        }
    }
}