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
    public class EventService : IEventService
    {
        private readonly ApplicationDbContext _context;
        public EventService(ApplicationDbContext context)
        {
            _context = context;
        }
        public async Task<PagedResult<EventDto>> GetEventsAsync(string? query, string? category, string? city,
            DateTimeOffset? from, DateTimeOffset? to, int page, int size, CancellationToken ct = default)
        {
            var eventsQuery = _context.Events
                .Include(e => e.PriceTiers)
                .AsQueryable();
            if (!string.IsNullOrEmpty(category))
            {
                eventsQuery = eventsQuery.Where(e => e.Category == category);
            }
            if (!string.IsNullOrEmpty(city))
            {
                eventsQuery = eventsQuery.Where(e => e.City == city);
            }
            if (from.HasValue)
            {
                eventsQuery = eventsQuery.Where(e => e.StartsAt >= from.Value);
            }
            if (to.HasValue)
            {
                eventsQuery = eventsQuery.Where(e => e.StartsAt <= to.Value);
            }
            eventsQuery = eventsQuery.Where(e => e.Status != "Archived");
            if (!string.IsNullOrEmpty(query))
            {
                eventsQuery = eventsQuery.Where(e => 
                    EF.Functions.Like(e.Title, $"%{query}%") || 
                    (e.Description != null && EF.Functions.Like(e.Description, $"%{query}%")) ||
                    EF.Functions.Like(e.Venue, $"%{query}%"));
            }
            var total = await eventsQuery.CountAsync(ct);
            var sortedEvents = await eventsQuery
                .OrderBy(e => e.StartsAt)
                .Skip((page - 1) * size)
                .Take(size)
                .Select(e => new EventDto(
                    e.Id,
                    e.Title,
                    e.Slug,
                    e.Description,
                    e.Venue,
                    e.City,
                    e.Country,
                    e.StartsAt,
                    e.EndsAt,
                    e.Category,
                    e.Tags,
                    e.Status,
                    e.CoverImageUrl,
                    e.CreatedAt,
                    e.PriceTiers.Select(pt => new PriceTierDto(
                        pt.Id,
                        pt.Name,
                        pt.Price,
                        pt.Currency,
                        pt.Capacity,
                        pt.Sold
                    )).ToList()
                ))
                .ToListAsync(ct);
            return new PagedResult<EventDto>
            {
                Items = sortedEvents,
                Page = page,
                Size = size,
                Total = total,
            };
        }
        public async Task<PagedResult<EventDto>> GetAllEventsAsync(string? query, string? category, string? city,
            string? status, DateTimeOffset? from, DateTimeOffset? to, int page, int size, CancellationToken ct = default)
        {
            var eventsQuery = _context.Events
                .Include(e => e.PriceTiers)
                .AsQueryable();
            if (!string.IsNullOrEmpty(query))
            {
                eventsQuery = eventsQuery.Where(e => 
                    EF.Functions.Like(e.Title, $"%{query}%") || 
                    (e.Description != null && EF.Functions.Like(e.Description, $"%{query}%")) ||
                    EF.Functions.Like(e.Venue, $"%{query}%"));
            }
            if (!string.IsNullOrEmpty(category))
            {
                eventsQuery = eventsQuery.Where(e => e.Category == category);
            }
            if (!string.IsNullOrEmpty(city))
            {
                eventsQuery = eventsQuery.Where(e => e.City == city);
            }
            if (!string.IsNullOrEmpty(status))
            {
                eventsQuery = eventsQuery.Where(e => e.Status == status);
            }
            if (from.HasValue)
            {
                eventsQuery = eventsQuery.Where(e => e.StartsAt >= from.Value);
            }
            if (to.HasValue)
            {
                eventsQuery = eventsQuery.Where(e => e.StartsAt <= to.Value);
            }
            var total = await eventsQuery.CountAsync(ct);
            var sortedEvents = await eventsQuery
                .OrderBy(e => e.StartsAt)
                .Skip((page - 1) * size)
                .Take(size)
                .Select(e => new EventDto(
                    e.Id,
                    e.Title,
                    e.Slug,
                    e.Description,
                    e.Venue,
                    e.City,
                    e.Country,
                    e.StartsAt,
                    e.EndsAt,
                    e.Category,
                    e.Tags,
                    e.Status,
                    e.CoverImageUrl,
                    e.CreatedAt,
                    e.PriceTiers.Select(pt => new PriceTierDto(
                        pt.Id,
                        pt.Name,
                        pt.Price,
                        pt.Currency,
                        pt.Capacity,
                        pt.Sold
                    )).ToList()
                ))
                .ToListAsync(ct);
            return new PagedResult<EventDto>
            {
                Items = sortedEvents,
                Page = page,
                Size = size,
                Total = total
            };
        }
        public async Task<EventDto?> GetEventAsync(Guid id, CancellationToken ct = default)
        {
            var eventEntity = await _context.Events
                .Include(e => e.PriceTiers)
                .FirstOrDefaultAsync(e => e.Id == id, ct);
            if (eventEntity == null)
                return null;
            return new EventDto(
                eventEntity.Id,
                eventEntity.Title,
                eventEntity.Slug,
                eventEntity.Description,
                eventEntity.Venue,
                eventEntity.City,
                eventEntity.Country,
                eventEntity.StartsAt,
                eventEntity.EndsAt,
                eventEntity.Category,
                eventEntity.Tags,
                eventEntity.Status,
                eventEntity.CoverImageUrl,
                eventEntity.CreatedAt,
                eventEntity.PriceTiers.Select(pt => new PriceTierDto(
                    pt.Id,
                    pt.Name,
                    pt.Price,
                    pt.Currency,
                    pt.Capacity,
                    pt.Sold
                )).ToList()
            );
        }
        public async Task<EventDto> CreateEventAsync(CreateEventRequest req, string userId, CancellationToken ct = default)
        {
            // Validate that EndsAt is not before StartsAt
            if (req.EndsAt.HasValue && req.EndsAt.Value < req.StartsAt)
            {
                throw new ArgumentException("End date and time cannot be before start date and time.");
            }
            
            var slug = GenerateSlug(req.Title);
            var eventEntity = new Event
            {
                Id = Guid.NewGuid(),
                Title = req.Title,
                Slug = slug,
                Description = req.Description,
                Venue = req.Venue,
                City = req.City,
                Country = req.Country,
                StartsAt = req.StartsAt,
                EndsAt = req.EndsAt,
                Category = req.Category,
                Tags = req.Tags,
                Status = "Draft",
                CoverImageUrl = req.CoverImageUrl,
                CreatedAt = DateTime.UtcNow,
                CreatedBy = userId
            };
            _context.Events.Add(eventEntity);
            if (req.PriceTiers != null)
            {
                foreach (var priceTier in req.PriceTiers)
                {
                    var priceTierEntity = new PriceTier
                    {
                        Id = Guid.NewGuid(),
                        EventId = eventEntity.Id,
                        Name = priceTier.Name,
                        Price = priceTier.Price,
                        Currency = priceTier.Currency,
                        Capacity = priceTier.Capacity,
                        Sold = 0
                    };
                    _context.PriceTiers.Add(priceTierEntity);
                }
            }
            try
            {
                await _context.SaveChangesAsync(ct);
            }
            catch (Microsoft.EntityFrameworkCore.DbUpdateException ex)
            {
                var innerException = ex.InnerException?.Message ?? ex.Message;
                var fullException = ex.InnerException?.ToString() ?? ex.ToString();
                // Log to console for debugging
                System.Console.WriteLine($"=== DbUpdateException ===");
                System.Console.WriteLine($"Message: {ex.Message}");
                System.Console.WriteLine($"Inner Exception: {innerException}");
                System.Console.WriteLine($"Full Exception: {fullException}");
                System.Console.WriteLine($"==========================");
                // Throw ArgumentException which will be caught by GlobalExceptionMiddleware
                throw new ArgumentException($"Database error: {innerException}");
            }
            catch (Exception ex)
            {
                System.Console.WriteLine($"=== General Exception in CreateEventAsync ===");
                System.Console.WriteLine($"Message: {ex.Message}");
                System.Console.WriteLine($"Stack Trace: {ex.StackTrace}");
                System.Console.WriteLine($"============================================");
                throw;
            }
            var createdEvent = await _context.Events
                .Include(e => e.PriceTiers)
                .FirstOrDefaultAsync(e => e.Id == eventEntity.Id, ct);
            return new EventDto(
                createdEvent!.Id,
                createdEvent.Title,
                createdEvent.Slug,
                createdEvent.Description,
                createdEvent.Venue,
                createdEvent.City,
                createdEvent.Country,
                createdEvent.StartsAt,
                createdEvent.EndsAt,
                createdEvent.Category,
                createdEvent.Tags,
                createdEvent.Status,
                createdEvent.CoverImageUrl,
                createdEvent.CreatedAt,
                createdEvent.PriceTiers.Select(pt => new PriceTierDto(
                    pt.Id,
                    pt.Name,
                    pt.Price,
                    pt.Currency,
                    pt.Capacity,
                    pt.Sold
                )).ToList()
            );
        }
        public async Task<EventDto> UpdateEventAsync(Guid id, UpdateEventRequest req, string userId, CancellationToken ct = default)
        {
            var eventEntity = await _context.Events
                .Include(e => e.PriceTiers)
                .FirstOrDefaultAsync(e => e.Id == id, ct);
            if (eventEntity == null)
                throw new ArgumentException("Event not found");
            if (!string.IsNullOrEmpty(req.Title))
            {
                eventEntity.Title = req.Title;
                eventEntity.Slug = GenerateSlug(req.Title);
            }
            if (req.Description != null)
                eventEntity.Description = req.Description;
            if (!string.IsNullOrEmpty(req.Venue))
                eventEntity.Venue = req.Venue;
            if (!string.IsNullOrEmpty(req.City))
                eventEntity.City = req.City;
            if (!string.IsNullOrEmpty(req.Country))
                eventEntity.Country = req.Country;
            if (req.StartsAt.HasValue)
                eventEntity.StartsAt = req.StartsAt.Value;
            if (req.EndsAt.HasValue)
                eventEntity.EndsAt = req.EndsAt;
            if (!string.IsNullOrEmpty(req.Category))
                eventEntity.Category = req.Category;
            if (req.Tags != null)
                eventEntity.Tags = req.Tags;
            if (!string.IsNullOrEmpty(req.Status))
                eventEntity.Status = req.Status;
            if (req.CoverImageUrl != null)
                eventEntity.CoverImageUrl = req.CoverImageUrl;
            await _context.SaveChangesAsync(ct);
            return new EventDto(
                eventEntity.Id,
                eventEntity.Title,
                eventEntity.Slug,
                eventEntity.Description,
                eventEntity.Venue,
                eventEntity.City,
                eventEntity.Country,
                eventEntity.StartsAt,
                eventEntity.EndsAt,
                eventEntity.Category,
                eventEntity.Tags,
                eventEntity.Status,
                eventEntity.CoverImageUrl,
                eventEntity.CreatedAt,
                eventEntity.PriceTiers.Select(pt => new PriceTierDto(
                    pt.Id,
                    pt.Name,
                    pt.Price,
                    pt.Currency,
                    pt.Capacity,
                    pt.Sold
                )).ToList()
            );
        }
        public async Task<bool> DeleteEventAsync(Guid id, string userId, CancellationToken ct = default)
        {
            var eventEntity = await _context.Events
                .Include(e => e.PriceTiers)
                .FirstOrDefaultAsync(e => e.Id == id, ct);
            if (eventEntity == null)
                return false;
            _context.PriceTiers.RemoveRange(eventEntity.PriceTiers);
            _context.Events.Remove(eventEntity);
            await _context.SaveChangesAsync(ct);
            return true;
        }
        public async Task<bool> ArchiveEventAsync(Guid id, string userId, CancellationToken ct = default)
        {
            var eventEntity = await _context.Events
                .FirstOrDefaultAsync(e => e.Id == id, ct);
            if (eventEntity == null)
                return false;
            eventEntity.Status = "Archived";
            await _context.SaveChangesAsync(ct);
            return true;
        }
        private static string GenerateSlug(string title)
        {
            if (string.IsNullOrEmpty(title))
                return string.Empty;
            return title
                .ToLowerInvariant()
                .Replace(" ", "-")
                .Replace("š", "s")
                .Replace("đ", "d")
                .Replace("č", "c")
                .Replace("ć", "c")
                .Replace("ž", "z")
                .Replace("Š", "s")
                .Replace("Đ", "d")
                .Replace("Č", "c")
                .Replace("Ć", "c")
                .Replace("Ž", "z")
                .Replace("&", "and")
                .Replace("@", "at")
                .Replace("#", "hash")
                .Replace("%", "percent")
                .Replace("+", "plus")
                .Replace("=", "equals")
                .Replace("?", "question")
                .Replace("!", "exclamation")
                .Replace("(", "")
                .Replace(")", "")
                .Replace("[", "")
                .Replace("]", "")
                .Replace("{", "")
                .Replace("}", "")
                .Replace("|", "")
                .Replace("\\", "")
                .Replace("/", "")
                .Replace(":", "")
                .Replace(";", "")
                .Replace("\"", "")
                .Replace("'", "")
                .Replace("<", "")
                .Replace(">", "")
                .Replace(",", "")
                .Replace(".", "")
                .Replace("_", "-")
                .Replace("--", "-")
                .Trim('-');
        }
        public async Task<IReadOnlyList<EventDto>> GetMyEventsAsync(string userId, CancellationToken ct = default)
        {
            var events = await _context.Events
                .Include(e => e.PriceTiers)
                .Where(e => e.CreatedBy == userId && e.Status != "Archived")
                .OrderByDescending(e => e.CreatedAt)
                .ToListAsync(ct);
            return events.Select(e => new EventDto(
                e.Id,
                e.Title,
                e.Slug,
                e.Description,
                e.Venue,
                e.City,
                e.Country,
                e.StartsAt,
                e.EndsAt,
                e.Category,
                e.Tags,
                e.Status,
                e.CoverImageUrl,
                e.CreatedAt,
                e.PriceTiers.Select(pt => new PriceTierDto(
                    pt.Id,
                    pt.Name,
                    pt.Price,
                    pt.Currency,
                    pt.Capacity,
                    pt.Sold
                )).ToList()
            )).ToList();
        }
    }
}