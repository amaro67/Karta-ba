using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using Karta.Service.DTO;
namespace Karta.Service.Interfaces;
public interface IEventService
{
    Task<PagedResult<EventDto>> GetEventsAsync(string? query, string? category, string? city,
        DateTimeOffset? from, DateTimeOffset? to, int page, int size, CancellationToken ct = default);
    Task<PagedResult<EventDto>> GetAllEventsAsync(string? query, string? category, string? city,
        string? status, DateTimeOffset? from, DateTimeOffset? to, int page, int size, CancellationToken ct = default);
    Task<EventDto?> GetEventAsync(Guid id, CancellationToken ct = default);
    Task<EventDto> CreateEventAsync(CreateEventRequest req, string userId, CancellationToken ct = default);
    Task<EventDto> UpdateEventAsync(Guid id, UpdateEventRequest req, string userId, CancellationToken ct = default);
    Task<bool> DeleteEventAsync(Guid id, string userId, CancellationToken ct = default);
    Task<bool> ArchiveEventAsync(Guid id, string userId, CancellationToken ct = default);
    Task<IReadOnlyList<EventDto>> GetMyEventsAsync(string userId, CancellationToken ct = default);
}