using System.Security.Claims;
using Karta.Service.DTO;
using Karta.Service.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Swashbuckle.AspNetCore.Annotations;
namespace Karta.WebAPI.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    [SwaggerTag("Upravljanje notifikacijama")]
    public class NotificationController : ControllerBase
    {
        private readonly INotificationService _notificationService;

        public NotificationController(INotificationService notificationService)
        {
            _notificationService = notificationService;
        }

        private string GetUserId() =>
            User.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? throw new UnauthorizedAccessException("User ID not found in claims");

        [HttpGet]
        [SwaggerOperation(Summary = "Dohvata notifikacije korisnika")]
        [SwaggerResponse(200, "Lista notifikacija", typeof(PagedResult<NotificationDto>))]
        public async Task<ActionResult<PagedResult<NotificationDto>>> GetNotifications(
            [FromQuery] int page = 1, [FromQuery] int size = 20)
        {
            var userId = GetUserId();
            var result = await _notificationService.GetUserNotificationsAsync(userId, page, size);
            return Ok(result);
        }

        [HttpGet("unread-count")]
        [SwaggerOperation(Summary = "Dohvata broj nepročitanih notifikacija")]
        [SwaggerResponse(200, "Broj nepročitanih")]
        public async Task<ActionResult<int>> GetUnreadCount()
        {
            var userId = GetUserId();
            var count = await _notificationService.GetUnreadCountAsync(userId);
            return Ok(count);
        }

        [HttpPut("{id}/read")]
        [SwaggerOperation(Summary = "Označava notifikaciju kao pročitanu")]
        [SwaggerResponse(204, "Uspješno označena")]
        [SwaggerResponse(404, "Notifikacija nije pronađena")]
        public async Task<ActionResult> MarkAsRead(Guid id)
        {
            var userId = GetUserId();
            await _notificationService.MarkAsReadAsync(id, userId);
            return NoContent();
        }

        [HttpPut("read-all")]
        [SwaggerOperation(Summary = "Označava sve notifikacije kao pročitane")]
        [SwaggerResponse(204, "Uspješno označene")]
        public async Task<ActionResult> MarkAllAsRead()
        {
            var userId = GetUserId();
            await _notificationService.MarkAllAsReadAsync(userId);
            return NoContent();
        }

        [HttpDelete("{id}")]
        [SwaggerOperation(Summary = "Briše notifikaciju")]
        [SwaggerResponse(204, "Uspješno obrisana")]
        [SwaggerResponse(404, "Notifikacija nije pronađena")]
        public async Task<ActionResult> DeleteNotification(Guid id)
        {
            var userId = GetUserId();
            await _notificationService.DeleteNotificationAsync(id, userId);
            return NoContent();
        }

        [HttpPost]
        [Authorize(Roles = "Admin")]
        [SwaggerOperation(Summary = "Kreira sistemsku notifikaciju za sve korisnike (samo admin)")]
        [SwaggerResponse(201, "Notifikacija kreirana")]
        public async Task<ActionResult> CreateSystemAnnouncement([FromBody] CreateNotificationRequest request)
        {
            if (!ModelState.IsValid)
                return BadRequest(ModelState);

            await _notificationService.CreateSystemAnnouncementAsync(request.Title, request.Content);
            return StatusCode(201);
        }
    }
}
