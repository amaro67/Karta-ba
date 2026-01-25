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
    public class FavoriteService : IFavoriteService
    {
        private readonly ApplicationDbContext _context;

        public FavoriteService(ApplicationDbContext context)
        {
            _context = context;
        }

        public async Task<FavoriteDto> AddFavoriteAsync(string userId, Guid eventId, CancellationToken ct = default)
        {
            // Check if event exists
            var eventExists = await _context.Events.AnyAsync(e => e.Id == eventId, ct);
            if (!eventExists)
                throw new ArgumentException("Event not found");

            // Check if already favorited
            var existingFavorite = await _context.UserFavorites
                .FirstOrDefaultAsync(f => f.UserId == userId && f.EventId == eventId, ct);

            if (existingFavorite != null)
                return new FavoriteDto(existingFavorite.EventId, existingFavorite.CreatedAt);

            var favorite = new UserFavorite
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                EventId = eventId,
                CreatedAt = DateTime.UtcNow
            };

            _context.UserFavorites.Add(favorite);
            await _context.SaveChangesAsync(ct);

            return new FavoriteDto(favorite.EventId, favorite.CreatedAt);
        }

        public async Task<bool> RemoveFavoriteAsync(string userId, Guid eventId, CancellationToken ct = default)
        {
            var favorite = await _context.UserFavorites
                .FirstOrDefaultAsync(f => f.UserId == userId && f.EventId == eventId, ct);

            if (favorite == null)
                return false;

            _context.UserFavorites.Remove(favorite);
            await _context.SaveChangesAsync(ct);

            return true;
        }

        public async Task<bool> IsFavoriteAsync(string userId, Guid eventId, CancellationToken ct = default)
        {
            return await _context.UserFavorites
                .AnyAsync(f => f.UserId == userId && f.EventId == eventId, ct);
        }

        public async Task<IReadOnlyList<FavoriteEventDto>> GetFavoritesAsync(string userId, CancellationToken ct = default)
        {
            var favorites = await _context.UserFavorites
                .Where(f => f.UserId == userId)
                .Include(f => f.Event)
                    .ThenInclude(e => e.PriceTiers)
                .Include(f => f.Event)
                    .ThenInclude(e => e.CategoryRef)
                .Include(f => f.Event)
                    .ThenInclude(e => e.VenueRef)
                .OrderByDescending(f => f.CreatedAt)
                .ToListAsync(ct);

            return favorites.Select(f => new FavoriteEventDto(
                new EventDto(
                    f.Event.Id,
                    f.Event.Title,
                    f.Event.Slug,
                    f.Event.Description,
                    f.Event.VenueId,
                    f.Event.VenueRef?.Name ?? f.Event.Venue,
                    f.Event.City,
                    f.Event.Country,
                    f.Event.StartsAt,
                    f.Event.EndsAt,
                    f.Event.CategoryId,
                    f.Event.CategoryRef?.Name ?? f.Event.Category,
                    f.Event.Tags,
                    f.Event.Status,
                    f.Event.CoverImageUrl,
                    f.Event.CreatedAt,
                    f.Event.PriceTiers.Select(pt => new PriceTierDto(
                        pt.Id,
                        pt.Name,
                        pt.Price,
                        pt.Currency,
                        pt.Capacity,
                        pt.Sold
                    )).ToList()
                ),
                f.CreatedAt
            )).ToList();
        }

        public async Task<IReadOnlyList<Guid>> GetFavoriteEventIdsAsync(string userId, CancellationToken ct = default)
        {
            return await _context.UserFavorites
                .Where(f => f.UserId == userId)
                .Select(f => f.EventId)
                .ToListAsync(ct);
        }
    }
}
