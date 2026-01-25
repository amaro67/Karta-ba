using Karta.Service.DTO;
using Karta.Service.Interfaces;
using Karta.WebAPI.Filters;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Swashbuckle.AspNetCore.Annotations;
using System.Security.Claims;

namespace Karta.WebAPI.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [SwaggerTag("Upravljanje recenzijama za evente")]
    public class ReviewController : ControllerBase
    {
        private readonly IReviewService _reviewService;
        private readonly ILogger<ReviewController> _logger;

        public ReviewController(IReviewService reviewService, ILogger<ReviewController> logger)
        {
            _reviewService = reviewService;
            _logger = logger;
        }

        [HttpGet("event/{eventId}")]
        [SwaggerOperation(Summary = "Dohvata recenzije za event",
                         Description = "Vraća paginirane recenzije za određeni event sa prosječnom ocjenom")]
        [SwaggerResponse(200, "Uspešno vraćene recenzije", typeof(EventReviewsDto))]
        public async Task<ActionResult<EventReviewsDto>> GetEventReviews(
            Guid eventId,
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 10)
        {
            var reviews = await _reviewService.GetEventReviewsAsync(eventId, page, pageSize);
            return Ok(reviews);
        }

        [HttpGet("event/{eventId}/can-review")]
        [Authorize]
        [SwaggerOperation(Summary = "Provjerava može li korisnik pisati recenziju",
                         Description = "Vraća true ako korisnik ima kupljenu kartu i nije već pisao recenziju")]
        [SwaggerResponse(200, "Vraćen status mogućnosti pisanja recenzije", typeof(bool))]
        [SwaggerResponse(401, "Korisnik nije autentifikovan")]
        public async Task<ActionResult<bool>> CanUserReview(Guid eventId)
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrEmpty(userId))
                return Unauthorized();

            var canReview = await _reviewService.CanUserReviewEventAsync(userId, eventId);
            return Ok(new { canReview });
        }

        [HttpGet("event/{eventId}/my-review")]
        [Authorize]
        [SwaggerOperation(Summary = "Dohvata recenziju trenutnog korisnika za event",
                         Description = "Vraća recenziju korisnika za određeni event ako postoji")]
        [SwaggerResponse(200, "Vraćena recenzija korisnika", typeof(ReviewDto))]
        [SwaggerResponse(404, "Korisnik nema recenziju za ovaj event")]
        [SwaggerResponse(401, "Korisnik nije autentifikovan")]
        public async Task<ActionResult<ReviewDto>> GetMyReviewForEvent(Guid eventId)
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrEmpty(userId))
                return Unauthorized();

            var review = await _reviewService.GetUserReviewForEventAsync(userId, eventId);
            if (review == null)
                return NotFound(new { message = "You have not reviewed this event" });

            return Ok(review);
        }

        [HttpPost("event/{eventId}")]
        [Authorize]
        [ServiceFilter(typeof(ValidationFilterAttribute))]
        [SwaggerOperation(Summary = "Kreira recenziju za event",
                         Description = "Kreira novu recenziju. Korisnik mora imati kupljenu kartu.")]
        [SwaggerResponse(201, "Recenzija uspešno kreirana", typeof(ReviewDto))]
        [SwaggerResponse(400, "Neispravni podaci")]
        [SwaggerResponse(401, "Korisnik nije autentifikovan")]
        [SwaggerResponse(403, "Korisnik nema pravo pisati recenziju (nema kupljenu kartu ili već ima recenziju)")]
        public async Task<ActionResult<ReviewDto>> CreateReview(Guid eventId, [FromBody] CreateReviewRequest request)
        {
            if (!ModelState.IsValid)
                return BadRequest(ModelState);

            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrEmpty(userId))
                return Unauthorized();

            try
            {
                var review = await _reviewService.CreateReviewAsync(userId, eventId, request);
                return CreatedAtAction(nameof(GetMyReviewForEvent), new { eventId }, review);
            }
            catch (ArgumentException ex)
            {
                return BadRequest(new { message = ex.Message });
            }
            catch (UnauthorizedAccessException ex)
            {
                return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
            }
        }

        [HttpPut("{reviewId}")]
        [Authorize]
        [ServiceFilter(typeof(ValidationFilterAttribute))]
        [SwaggerOperation(Summary = "Ažurira recenziju",
                         Description = "Ažurira postojeću recenziju. Samo vlasnik može ažurirati.")]
        [SwaggerResponse(200, "Recenzija uspešno ažurirana", typeof(ReviewDto))]
        [SwaggerResponse(400, "Neispravni podaci")]
        [SwaggerResponse(401, "Korisnik nije autentifikovan")]
        [SwaggerResponse(403, "Korisnik nije vlasnik recenzije")]
        [SwaggerResponse(404, "Recenzija nije pronađena")]
        public async Task<ActionResult<ReviewDto>> UpdateReview(Guid reviewId, [FromBody] UpdateReviewRequest request)
        {
            if (!ModelState.IsValid)
                return BadRequest(ModelState);

            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrEmpty(userId))
                return Unauthorized();

            try
            {
                var review = await _reviewService.UpdateReviewAsync(reviewId, userId, request);
                if (review == null)
                    return NotFound(new { message = "Review not found" });

                return Ok(review);
            }
            catch (UnauthorizedAccessException ex)
            {
                return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
            }
        }

        [HttpDelete("{reviewId}")]
        [Authorize]
        [SwaggerOperation(Summary = "Briše recenziju",
                         Description = "Briše recenziju. Vlasnik ili admin može brisati.")]
        [SwaggerResponse(204, "Recenzija uspešno obrisana")]
        [SwaggerResponse(401, "Korisnik nije autentifikovan")]
        [SwaggerResponse(403, "Korisnik nije vlasnik recenzije")]
        [SwaggerResponse(404, "Recenzija nije pronađena")]
        public async Task<ActionResult> DeleteReview(Guid reviewId)
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrEmpty(userId))
                return Unauthorized();

            // Check if user is admin
            var isAdmin = User.IsInRole("Admin");

            try
            {
                var success = await _reviewService.DeleteReviewAsync(reviewId, userId, isAdmin);
                if (!success)
                    return NotFound(new { message = "Review not found" });

                return NoContent();
            }
            catch (UnauthorizedAccessException ex)
            {
                return StatusCode(StatusCodes.Status403Forbidden, new { message = ex.Message });
            }
        }
    }
}
