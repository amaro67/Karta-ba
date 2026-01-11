using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Karta.Model;
using Karta.Model.Entities;
using Karta.Service.DTO;
using Karta.Service.Interfaces;
using Microsoft.EntityFrameworkCore;
namespace Karta.Service.Services
{
    public class TicketService : ITicketService
    {
        private readonly ApplicationDbContext _context;
        public TicketService(ApplicationDbContext context)
        {
            _context = context;
        }
        public async Task<IReadOnlyList<TicketDto>> GetMyTicketsAsync(string userId, CancellationToken ct = default)
        {
            var tickets = await _context.Tickets
                .Include(t => t.OrderItem)
                    .ThenInclude(oi => oi.Order)
                .Where(t => t.OrderItem.Order.UserId == userId && t.OrderItem.Order.Status == "Paid")
                .OrderByDescending(t => t.IssuedAt)
                .ToListAsync(ct);
            return tickets.Select(t => new TicketDto(
                t.Id,
                t.TicketCode,
                t.Status,
                t.IssuedAt,
                t.UsedAt
            )).ToList();
        }
        public async Task<TicketDto?> GetTicketAsync(Guid id, string userId, CancellationToken ct = default)
        {
            var ticket = await _context.Tickets
                .Include(t => t.OrderItem)
                    .ThenInclude(oi => oi.Order)
                .FirstOrDefaultAsync(t => t.Id == id && t.OrderItem.Order.UserId == userId, ct);
            if (ticket == null)
                return null;
            return new TicketDto(
                ticket.Id,
                ticket.TicketCode,
                ticket.Status,
                ticket.IssuedAt,
                ticket.UsedAt
            );
        }
        public async Task<(string status, DateTime? usedAt)> ScanAsync(ScanTicketRequest req, CancellationToken ct = default)
        {
            var ticket = await _context.Tickets
                .Include(t => t.OrderItem)
                    .ThenInclude(oi => oi.Order)
                .FirstOrDefaultAsync(t => t.TicketCode == req.TicketCode, ct);
            if (ticket == null)
            {
                await LogScanAsync(Guid.Empty, req.GateId, "Invalid", ct);
                return ("Invalid", null);
            }
            if (ticket.Status == "Used")
            {
                await LogScanAsync(ticket.Id, req.GateId, "AlreadyUsed", ct);
                return ("AlreadyUsed", ticket.UsedAt);
            }
            if (ticket.OrderItem.Order.Status != "Paid")
            {
                await LogScanAsync(ticket.Id, req.GateId, "Unpaid", ct);
                return ("Unpaid", null);
            }
            ticket.Status = "Used";
            ticket.UsedAt = DateTime.UtcNow;
            await LogScanAsync(ticket.Id, req.GateId, "Valid", ct);
            await _context.SaveChangesAsync(ct);
            return ("Valid", ticket.UsedAt);
        }
        public async Task<TicketDto?> ValidateAsync(string ticketCode, CancellationToken ct = default)
        {
            var ticket = await _context.Tickets
                .Include(t => t.OrderItem)
                    .ThenInclude(oi => oi.Order)
                .FirstOrDefaultAsync(t => t.TicketCode == ticketCode, ct);
            if (ticket == null)
                return null;
            return new TicketDto(
                ticket.Id,
                ticket.TicketCode,
                ticket.Status,
                ticket.IssuedAt,
                ticket.UsedAt
            );
        }
        public async Task<PagedResult<TicketDto>> GetAllTicketsAsync(string? query, string? status, string? userId, Guid? eventId, DateTimeOffset? from, DateTimeOffset? to, int page, int size, CancellationToken ct = default)
        {
            var ticketsQuery = _context.Tickets
                .Include(t => t.OrderItem)
                    .ThenInclude(oi => oi.Order)
                .AsQueryable();
            if (!string.IsNullOrEmpty(query))
            {
                ticketsQuery = ticketsQuery.Where(t => t.TicketCode.Contains(query));
            }
            if (!string.IsNullOrEmpty(status))
            {
                ticketsQuery = ticketsQuery.Where(t => t.Status == status);
            }
            if (!string.IsNullOrEmpty(userId))
            {
                ticketsQuery = ticketsQuery.Where(t => t.OrderItem.Order.UserId == userId);
            }
            if (eventId.HasValue)
            {
                ticketsQuery = ticketsQuery.Where(t => t.OrderItem.EventId == eventId.Value);
            }
            if (from.HasValue)
            {
                var fromDateTime = from.Value.UtcDateTime;
                ticketsQuery = ticketsQuery.Where(t => t.IssuedAt >= fromDateTime);
            }
            if (to.HasValue)
            {
                var toDateTime = to.Value.UtcDateTime;
                ticketsQuery = ticketsQuery.Where(t => t.IssuedAt <= toDateTime);
            }
            var total = await ticketsQuery.CountAsync(ct);
            var tickets = await ticketsQuery
                .OrderByDescending(t => t.IssuedAt)
                .Skip((page - 1) * size)
                .Take(size)
                .ToListAsync(ct);
            var ticketsDto = tickets.Select(t => new TicketDto(
                t.Id,
                t.TicketCode,
                t.Status,
                t.IssuedAt,
                t.UsedAt
            )).ToList();
            return new PagedResult<TicketDto>
            {
                Items = ticketsDto,
                Page = page,
                Size = size,
                Total = total
            };
        }
        public async Task<TicketDto?> GetTicketByIdAsync(Guid id, CancellationToken ct = default)
        {
            var ticket = await _context.Tickets
                .Include(t => t.OrderItem)
                    .ThenInclude(oi => oi.Order)
                .FirstOrDefaultAsync(t => t.Id == id, ct);
            if (ticket == null)
                return null;
            return new TicketDto(
                ticket.Id,
                ticket.TicketCode,
                ticket.Status,
                ticket.IssuedAt,
                ticket.UsedAt
            );
        }
        private async Task LogScanAsync(Guid ticketId, string gateId, string result, CancellationToken ct)
        {
            var scanLog = new ScanLog
            {
                Id = Guid.NewGuid(),
                TicketId = ticketId,
                GateId = gateId,
                ScannedAt = DateTime.UtcNow,
                Result = result
            };
            _context.ScanLogs.Add(scanLog);
            await _context.SaveChangesAsync(ct);
        }
    }
}