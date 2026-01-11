using Karta.Service.DTO;
using Karta.Service.Interfaces;
using Karta.WebAPI.Authorization;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;
namespace Karta.WebAPI.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class TicketController : ControllerBase
    {
        private readonly ITicketService _ticketService;
        public TicketController(ITicketService ticketService)
        {
            _ticketService = ticketService;
        }
        [HttpGet("all", Order = 0)]
        [RequirePermission("ViewAllTickets")]
        [ProducesResponseType(typeof(PagedResult<TicketDto>), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status401Unauthorized)]
        [ProducesResponseType(StatusCodes.Status403Forbidden)]
        public async Task<ActionResult<PagedResult<TicketDto>>> GetAllTickets(
            [FromQuery] string? query,
            [FromQuery] string? status,
            [FromQuery] string? userId,
            [FromQuery] Guid? eventId,
            [FromQuery] DateTimeOffset? from,
            [FromQuery] DateTimeOffset? to,
            [FromQuery] int page = 1,
            [FromQuery] int size = 20,
            CancellationToken ct = default)
        {
            if (page < 1) page = 1;
            if (size < 1 || size > 100) size = 20;
            var result = await _ticketService.GetAllTicketsAsync(query, status, userId, eventId, from, to, page, size, ct);
            return Ok(result);
        }
        [HttpGet("my-tickets")]
        [Authorize]
        public async Task<ActionResult<IReadOnlyList<TicketDto>>> GetMyTickets()
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrEmpty(userId))
                return Unauthorized();
            var tickets = await _ticketService.GetMyTicketsAsync(userId);
            return Ok(tickets);
        }
        [HttpGet("admin/{id}")]
        [RequirePermission("ViewAllTickets")]
        [ProducesResponseType(typeof(TicketDto), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status401Unauthorized)]
        [ProducesResponseType(StatusCodes.Status403Forbidden)]
        [ProducesResponseType(StatusCodes.Status404NotFound)]
        public async Task<ActionResult<TicketDto>> GetTicketAdmin(Guid id, CancellationToken ct = default)
        {
            var ticket = await _ticketService.GetTicketByIdAsync(id, ct);
            if (ticket == null)
                return NotFound();
            return Ok(ticket);
        }
        [HttpGet("{id:guid}", Order = 100)]
        [Authorize]
        public async Task<ActionResult<TicketDto>> GetTicket(Guid id)
        {
            var userId = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrEmpty(userId))
                return Unauthorized();
            var ticket = await _ticketService.GetTicketAsync(id, userId);
            if (ticket == null)
                return NotFound();
            return Ok(ticket);
        }
        [HttpPost("scan")]
        [AllowAnonymous]
        public async Task<ActionResult<object>> ScanTicket([FromBody] ScanTicketRequest request)
        {
            if (!ModelState.IsValid)
                return BadRequest(ModelState);
            try
            {
                var (status, usedAt) = await _ticketService.ScanAsync(request);
                return Ok(new { status, usedAt });
            }
            catch (Exception ex)
            {
                return BadRequest(ex.Message);
            }
        }
        [HttpPost("validate")]
        [AllowAnonymous]
        public async Task<ActionResult<TicketDto>> ValidateTicket([FromBody] ValidateTicketRequest request)
        {
            if (!ModelState.IsValid)
                return BadRequest(ModelState);
            try
            {
                var ticket = await _ticketService.ValidateAsync(request.TicketCode);
                if (ticket == null)
                    return NotFound("Ticket not found");
                return Ok(ticket);
            }
            catch (Exception ex)
            {
                return BadRequest(ex.Message);
            }
        }
    }
}