using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using Karta.Service.DTO;
namespace Karta.Service.Interfaces;
public interface ITicketService
{
    Task<IReadOnlyList<TicketDto>> GetMyTicketsAsync(string userId, CancellationToken ct = default);
    Task<TicketDto?> GetTicketAsync(Guid id, string userId, CancellationToken ct = default);
    Task<(string status, DateTime? usedAt)> ScanAsync(ScanTicketRequest req, CancellationToken ct = default);
    Task<TicketDto?> ValidateAsync(string ticketCode, CancellationToken ct = default);
    Task<PagedResult<TicketDto>> GetAllTicketsAsync(string? query, string? status, string? userId, Guid? eventId, DateTimeOffset? from, DateTimeOffset? to, int page, int size, CancellationToken ct = default);
    Task<TicketDto?> GetTicketByIdAsync(Guid id, CancellationToken ct = default);
}