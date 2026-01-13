using Karta.Model;
using Karta.Model.Entities;
using Karta.Service.DTO;
using Karta.Service.Interfaces;
using Karta.Service.Services;
using Karta.WebAPI.Authorization;
using Karta.WebAPI.Filters;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Hosting;
using Microsoft.EntityFrameworkCore;
using Swashbuckle.AspNetCore.Annotations;
using System.Security.Claims;
using System.Linq;
namespace Karta.WebAPI.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [SwaggerTag("Upravljanje eventima - kreiranje, ažuriranje, brisanje i pretraživanje eventa")]
    public class EventController : ControllerBase
    {
        private readonly IEventService _eventService;
        private readonly UserManager<ApplicationUser> _userManager;
        private readonly ApplicationDbContext _context;
        private readonly IRabbitMQService _rabbitMQService;
        private readonly Karta.Service.Services.IEmailService _emailService;
        private readonly IWebHostEnvironment _environment;
        private readonly ILogger<EventController> _logger;
        public EventController(
            IEventService eventService, 
            UserManager<ApplicationUser> userManager,
            ApplicationDbContext context,
            IRabbitMQService rabbitMQService,
            Karta.Service.Services.IEmailService emailService,
            IWebHostEnvironment environment,
            ILogger<EventController> logger)
        {
            _eventService = eventService;
            _userManager = userManager;
            _context = context;
            _rabbitMQService = rabbitMQService;
            _emailService = emailService;
            _environment = environment;
            _logger = logger;
        }
        [HttpGet]
        public async Task<ActionResult<PagedResult<EventDto>>> GetEvents(
            [FromQuery] string? query,
            [FromQuery] string? category,
            [FromQuery] string? city,
            [FromQuery] DateTimeOffset? from,
            [FromQuery] DateTimeOffset? to,
            [FromQuery] int page = 1,
            [FromQuery] int size = 20)
        {
            if (page < 1) page = 1;
            if (size < 1 || size > 100) size = 20;
            var result = await _eventService.GetEventsAsync(query, category, city, from, to, page, size);
            return Ok(result);
        }
        [HttpGet("all")]
        [Authorize]
        [SwaggerOperation(Summary = "Dohvata sve evente za admin panel (uključujući archived)", 
                         Description = "Vraća sve evente sa mogućnošću filtriranja po statusu. Dostupno samo za autentifikovane korisnike.")]
        [SwaggerResponse(200, "Uspešno vraćena lista eventa", typeof(PagedResult<EventDto>))]
        [SwaggerResponse(401, "Korisnik nije autentifikovan")]
        public async Task<ActionResult<PagedResult<EventDto>>> GetAllEvents(
            [FromQuery] string? query,
            [FromQuery] string? category,
            [FromQuery] string? city,
            [FromQuery] string? status,
            [FromQuery] DateTimeOffset? from,
            [FromQuery] DateTimeOffset? to,
            [FromQuery] int page = 1,
            [FromQuery] int size = 20)
        {
            if (page < 1) page = 1;
            if (size < 1 || size > 100) size = 20;
            var result = await _eventService.GetAllEventsAsync(query, category, city, status, from, to, page, size);
            return Ok(result);
        }
        [HttpGet("{id}")]
        public async Task<ActionResult<EventDto>> GetEvent(Guid id)
        {
            var eventDto = await _eventService.GetEventAsync(id);
            if (eventDto == null)
                return NotFound();
            return Ok(eventDto);
        }
        [HttpPost]
        [RequirePermission("CreateEvents")]
        [ServiceFilter(typeof(ValidationFilterAttribute))]
        public async Task<ActionResult<EventDto>> CreateEvent([FromBody] CreateEventRequest request)
        {
            _logger.LogInformation("CreateEvent called. Request: Title={Title}, Venue={Venue}, City={City}, StartsAt={StartsAt}, PriceTiersCount={PriceTiersCount}",
                request?.Title, request?.Venue, request?.City, request?.StartsAt, request?.PriceTiers?.Count ?? 0);
            
            if (!ModelState.IsValid)
            {
                _logger.LogWarning("ModelState is invalid. Errors: {Errors}", 
                    string.Join(", ", ModelState.SelectMany(x => x.Value.Errors).Select(e => e.ErrorMessage)));
                return BadRequest(ModelState);
            }
            
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrEmpty(userId))
            {
                _logger.LogWarning("CreateEvent: User ID not found in claims");
                return Unauthorized();
            }
            
            var user = await _userManager.FindByIdAsync(userId);
            if (user == null)
            {
                _logger.LogWarning("CreateEvent: User not found with ID {UserId}", userId);
                return Unauthorized();
            }
            
            try
            {
                _logger.LogInformation("Creating event for user {UserId} ({Email})", userId, user.Email);
                var eventDto = await _eventService.CreateEventAsync(request, userId);
                _logger.LogInformation("Event created successfully. EventId={EventId}", eventDto.Id);
                return CreatedAtAction(nameof(GetEvent), new { id = eventDto.Id }, eventDto);
            }
            catch (ArgumentException ex)
            {
                _logger.LogError(ex, "Error creating event: {Message}", ex.Message);
                return BadRequest(ex.Message);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Unexpected error creating event");
                throw;
            }
        }
        [HttpPut("{id}")]
        [RequirePermission("EditOwnEvents")]
        [ServiceFilter(typeof(ValidationFilterAttribute))]
        public async Task<ActionResult<EventDto>> UpdateEvent(Guid id, [FromBody] UpdateEventRequest request)
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
            var isOrganizer = roles.Contains("Organizer");
            var isAdmin = roles.Contains("Admin");
            if (!string.IsNullOrEmpty(request.Status) &&
                request.Status.Equals("Published", StringComparison.OrdinalIgnoreCase) &&
                isOrganizer &&
                !isAdmin &&
                !user.IsOrganizerVerified)
            {
                return StatusCode(StatusCodes.Status403Forbidden, new { message = "Organizator mora biti verifikovan od strane admina prije objave događaja." });
            }
            try
            {
                var eventDto = await _eventService.UpdateEventAsync(id, request, userId);
                return Ok(eventDto);
            }
            catch (ArgumentException ex)
            {
                return NotFound(ex.Message);
            }
        }
        [HttpDelete("{id}")]
        [RequirePermission("DeleteOwnEvents")]
        public async Task<ActionResult> DeleteEvent(Guid id)
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrEmpty(userId))
                return Unauthorized();
            var success = await _eventService.DeleteEventAsync(id, userId);
            if (!success)
                return NotFound();
            return NoContent();
        }
        [HttpPost("{id}/archive")]
        [Authorize]
        public async Task<ActionResult> ArchiveEvent(Guid id)
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrEmpty(userId))
                return Unauthorized();
            var success = await _eventService.ArchiveEventAsync(id, userId);
            if (!success)
                return NotFound();
            return NoContent();
        }
        [HttpGet("my-events")]
        [Authorize]
        [SwaggerOperation(Summary = "Dohvata sve evente koje je kreirao trenutni korisnik", 
                         Description = "Vraća listu eventa koje je kreirao organizator, sortirane po datumu kreiranja (najnoviji prvi)")]
        [SwaggerResponse(200, "Uspešno vraćena lista eventa", typeof(IReadOnlyList<EventDto>))]
        [SwaggerResponse(401, "Korisnik nije autentifikovan")]
        public async Task<ActionResult<IReadOnlyList<EventDto>>> GetMyEvents()
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrEmpty(userId))
                return Unauthorized();
            var events = await _eventService.GetMyEventsAsync(userId);
            return Ok(events);
        }
        [HttpPost("track-view")]
        [Authorize]
        [SwaggerOperation(Summary = "Prati kada korisnik pregleda event", 
                         Description = "Koristi se za content-based preporuke. Kada korisnik pogleda 2+ eventa iste kategorije u jednom danu, sistem šalje email sa preporukama")]
        [SwaggerResponse(200, "Tracking uspješan")]
        [SwaggerResponse(401, "Korisnik nije autentifikovan")]
        [SwaggerResponse(404, "Event nije pronađen")]
        public async Task<ActionResult> TrackEventView([FromBody] TrackEventViewRequest request)
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrEmpty(userId))
                return Unauthorized();
            var eventItem = await _context.Events
                .Where(e => e.Id == request.EventId)
                .Select(e => new { e.Category })
                .FirstOrDefaultAsync();
            if (eventItem == null)
            {
                _logger.LogWarning($"Event {request.EventId} not found for tracking");
                return NotFound(new { message = "Event not found" });
            }
            var today = DateTime.UtcNow.Date;
            var dailyView = await _context.UserDailyEventViews
                .FirstOrDefaultAsync(x =>
                    x.UserId == userId &&
                    x.Category == eventItem.Category &&
                    x.Date == today);
            if (dailyView == null)
            {
                dailyView = new UserDailyEventView
                {
                    UserId = userId,
                    Category = eventItem.Category,
                    Date = today,
                    ViewCount = 1,
                    EmailSentToday = false
                };
                _context.UserDailyEventViews.Add(dailyView);
                await _context.SaveChangesAsync();
                _logger.LogInformation($"User {userId} viewed {eventItem.Category} - Count: 1");
                return Ok(new
                {
                    viewCount = 1,
                    emailTriggered = false,
                    message = "First view tracked"
                });
            }
            else
            {
                dailyView.ViewCount++;
                await _context.SaveChangesAsync();
                _logger.LogInformation($"User {userId} viewed {eventItem.Category} - Count: {dailyView.ViewCount}");
                if (dailyView.ViewCount >= 2 && !dailyView.EmailSentToday)
                {
                    _logger.LogInformation($"🔔 TRIGGER! Sending recommendation email for {eventItem.Category} to user {userId}");
                    var user = await _userManager.FindByIdAsync(userId);
                    if (user != null && !string.IsNullOrEmpty(user.Email))
                    {
                        var categoryEvents = await _context.Events
                            .Include(e => e.PriceTiers)
                            .Where(e =>
                                e.Category == eventItem.Category &&
                                e.Status == "Published" &&
                                e.StartsAt > DateTimeOffset.UtcNow)
                            .OrderBy(e => e.StartsAt)
                            .Take(10)
                            .ToListAsync();
                        if (categoryEvents.Any())
                        {
                            dailyView.EmailSentToday = true;
                            dailyView.EmailSentAt = DateTime.UtcNow;
                            await _context.SaveChangesAsync();
                            var userEmail = user.Email;
                            var userName = user.FirstName ?? userEmail.Split('@')[0];
                            var category = eventItem.Category;
                            _ = Task.Run(async () =>
                            {
                                try
                                {
                                    var emailBody = GenerateCategoryRecommendationEmailBody(userName, category, categoryEvents);
                                    await _emailService.SendEmailDirectAsync(
                                        userEmail, 
                                        $"🎟️ {category} Events You'll Love!", 
                                        emailBody
                                    );
                                    _logger.LogInformation($"✅ Email sent directly to {userEmail} - Category: {category}, Events: {categoryEvents.Count}");
                                }
                                catch (Exception ex)
                                {
                                    _logger.LogError(ex, $"Error sending category recommendation email for user {userId}");
                                }
                            });
                        }
                    }
                    return Ok(new
                    {
                        viewCount = dailyView.ViewCount,
                        emailTriggered = true,
                        message = "Recommendation email will be sent"
                    });
                }
                return Ok(new
                {
                    viewCount = dailyView.ViewCount,
                    emailTriggered = false,
                    message = dailyView.EmailSentToday ? "Email already sent today" : "Not enough views yet"
                });
            }
        }
        private string GenerateCategoryRecommendationEmailBody(string userName, string category, List<Event> events)
        {
            var eventRows = string.Join("\n", events.Select(e =>
            {
                var minPrice = e.PriceTiers.Any() ? e.PriceTiers.Min(pt => pt.Price) : 0;
                var eventUrl = $"https://karta.ba/events/{e.Slug}";
                return $@"
                    <tr>
                        <td style='padding: 15px; border-bottom: 1px solid #eee;'>
                            <h3 style='margin: 0 0 8px 0; color: #333;'>{e.Title}</h3>
                            <p style='margin: 0; color: #666; font-size: 14px;'>
                                📅 {e.StartsAt:dd.MM.yyyy HH:mm} | 📍 {e.Venue}, {e.City}
                            </p>
                            <p style='margin: 8px 0 0 0;'>
                                <span style='color: #8B5CF6; font-weight: bold; font-size: 16px;'>From {minPrice:F2} KM</span>
                            </p>
                            <a href='{eventUrl}' 
                               style='display: inline-block; margin-top: 10px; padding: 10px 20px; 
                                      background: #8B5CF6; color: white; text-decoration: none; 
                                      border-radius: 5px; font-weight: bold;'>
                                View Event
                            </a>
                        </td>
                    </tr>";
            }));
            return $@"
<!DOCTYPE html>
<html>
<head>
    <meta charset='utf-8'>
    <meta name='viewport' content='width=device-width, initial-scale=1.0'>
</head>
<body style='font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; background: #f5f5f5;'>
    <div style='background: #8B5CF6; padding: 30px 20px; text-align: center;'>
        <h1 style='color: white; margin: 0; font-size: 24px;'>🎟️ We Found Events You'll Love!</h1>
    </div>
    <div style='padding: 20px; background: white;'>
        <p style='font-size: 16px; color: #333;'>Hej {userName},</p>
        <p style='font-size: 16px; color: #333;'>
            Primjetili smo da te zanima <strong style='color: #8B5CF6;'>{category}</strong>! 🎯
        </p>
        <p style='font-size: 16px; color: #333;'>
            Evo svih dostupnih <strong>{category}</strong> evenata:
        </p>
    </div>
    <table style='width: 100%; border-collapse: collapse; background: white;'>
        {eventRows}
    </table>
    <div style='padding: 20px; background: #f9f9f9; text-align: center; color: #666; font-size: 12px;'>
        <p style='margin: 5px 0;'>You're receiving this because you viewed multiple {category} events today.</p>
        <p style='margin: 5px 0;'>This is a one-time daily recommendation per category.</p>
        <p style='margin: 15px 0 5px 0;'>
            <a href='https://karta.ba' style='color: #8B5CF6; text-decoration: none;'>Visit karta.ba</a>
        </p>
    </div>
</body>
</html>";
        }
        [HttpPost("upload-image")]
        [Authorize]
        [RequirePermission("CreateEvents")]
        [Consumes("multipart/form-data")]
        [SwaggerOperation(Summary = "Upload slike za event", 
                         Description = "Uploaduje sliku i vraća relativni URL koji se može koristiti za coverImageUrl")]
        [SwaggerResponse(200, "Slika uspješno uploadovana")]
        [SwaggerResponse(400, "Neispravan fajl")]
        [SwaggerResponse(401, "Korisnik nije autentifikovan")]
        [SwaggerResponse(403, "Nedovoljna prava")]
        public async Task<ActionResult<ImageUploadResponse>> UploadImage(IFormFile file)
        {
            _logger.LogInformation("UploadImage endpoint called. File is null: {IsNull}, File length: {Length}", 
                file == null, file?.Length ?? 0);
            
            if (file == null || file.Length == 0)
            {
                _logger.LogWarning("UploadImage: No file provided or file is empty");
                return BadRequest(new { message = "Nijedan fajl nije uploadovan" });
            }
            
            _logger.LogInformation("UploadImage: File received - Name: {FileName}, Length: {Length}, ContentType: {ContentType}", 
                file.FileName, file.Length, file.ContentType);
            // Provjeri veličinu (max 5MB)
            if (file.Length > 5 * 1024 * 1024)
            {
                return BadRequest(new { message = "Slika je prevelika. Maksimalna veličina je 5MB" });
            }
            // Provjeri tip fajla
            var allowedExtensions = new[] { ".jpg", ".jpeg", ".png", ".gif", ".webp" };
            var fileExtension = Path.GetExtension(file.FileName).ToLowerInvariant();
            if (!allowedExtensions.Contains(fileExtension))
            {
                return BadRequest(new { message = "Nedozvoljeni tip fajla. Dozvoljeni su: JPG, JPEG, PNG, GIF, WEBP" });
            }
            try
            {
                // Odredi putanju do wwwroot/images
                string webRootPath;
                if (string.IsNullOrEmpty(_environment.WebRootPath))
                {
                    // Fallback na ContentRootPath/wwwroot
                    webRootPath = Path.Combine(_environment.ContentRootPath, "wwwroot");
                    _logger.LogWarning("WebRootPath is null, using ContentRootPath/wwwroot: {WebRootPath}", webRootPath);
                }
                else
                {
                    webRootPath = _environment.WebRootPath;
                }
                
                // Kreiraj unique ime fajla
                var fileName = $"event_{Guid.NewGuid()}{fileExtension}";
                var imagesPath = Path.Combine(webRootPath, "images");
                
                _logger.LogInformation("Attempting to save image to: {ImagesPath}", imagesPath);
                
                // Osiguraj da folder postoji
                if (!Directory.Exists(imagesPath))
                {
                    try
                    {
                        Directory.CreateDirectory(imagesPath);
                        _logger.LogInformation("Created images directory: {ImagesPath}", imagesPath);
                    }
                    catch (Exception dirEx)
                    {
                        _logger.LogError(dirEx, "Failed to create images directory: {ImagesPath}", imagesPath);
                        return StatusCode(500, new { message = $"Greška pri kreiranju images foldera: {dirEx.Message}" });
                    }
                }
                
                var filePath = Path.Combine(imagesPath, fileName);
                _logger.LogInformation("Saving file to: {FilePath}", filePath);
                
                // Spremi fajl
                using (var stream = new FileStream(filePath, FileMode.Create))
                {
                    await file.CopyToAsync(stream);
                }
                _logger.LogInformation("Image uploaded successfully: {FileName} to {FilePath}", fileName, filePath);
                
                // Vrati relativni URL
                var imageUrl = $"/images/{fileName}";
                return Ok(new ImageUploadResponse { ImageUrl = imageUrl });
            }
            catch (UnauthorizedAccessException ex)
            {
                _logger.LogError(ex, "Unauthorized access error uploading image");
                return StatusCode(500, new { message = "Nemate dozvolu za pisanje u images folder" });
            }
            catch (DirectoryNotFoundException ex)
            {
                _logger.LogError(ex, "Directory not found error uploading image");
                return StatusCode(500, new { message = $"Folder nije pronađen: {ex.Message}" });
            }
            catch (IOException ex)
            {
                _logger.LogError(ex, "IO error uploading image");
                return StatusCode(500, new { message = $"Greška pri pisanju fajla: {ex.Message}" });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error uploading image. Exception type: {ExceptionType}, Message: {Message}, StackTrace: {StackTrace}", 
                    ex.GetType().Name, ex.Message, ex.StackTrace);
                return StatusCode(500, new { message = $"Greška pri uploadovanju slike: {ex.Message}" });
            }
        }
    }
    public class TrackEventViewRequest
    {
        public Guid EventId { get; set; }
    }
    /// <summary>
    /// Response model za upload slike
    /// </summary>
    public class ImageUploadResponse
    {
        /// <summary>
        /// Relativni URL uploadovane slike (npr. /images/event_123.jpg)
        /// </summary>
        public string ImageUrl { get; set; } = string.Empty;
    }
}