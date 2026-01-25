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
    public class VenueService : IVenueService
    {
        private readonly ApplicationDbContext _context;

        public VenueService(ApplicationDbContext context)
        {
            _context = context;
        }

        public async Task<IReadOnlyList<VenueDto>> GetVenuesAsync(string? city = null, CancellationToken ct = default)
        {
            var query = _context.Venues.AsQueryable();

            if (!string.IsNullOrEmpty(city))
            {
                query = query.Where(v => v.City == city);
            }

            var venues = await query
                .OrderBy(v => v.City)
                .ThenBy(v => v.Name)
                .Select(v => new VenueDto(
                    v.Id,
                    v.Name,
                    v.Address,
                    v.City,
                    v.Country,
                    v.Capacity,
                    v.Latitude,
                    v.Longitude,
                    v.CreatedBy,
                    v.CreatedAt,
                    v.Events.Count(e => e.Status == "Published")
                ))
                .ToListAsync(ct);

            return venues;
        }

        public async Task<VenueDto?> GetVenueAsync(Guid id, CancellationToken ct = default)
        {
            var venue = await _context.Venues
                .Where(v => v.Id == id)
                .Select(v => new VenueDto(
                    v.Id,
                    v.Name,
                    v.Address,
                    v.City,
                    v.Country,
                    v.Capacity,
                    v.Latitude,
                    v.Longitude,
                    v.CreatedBy,
                    v.CreatedAt,
                    v.Events.Count(e => e.Status == "Published")
                ))
                .FirstOrDefaultAsync(ct);

            return venue;
        }

        public async Task<VenueDto> CreateVenueAsync(CreateVenueRequest request, string userId, CancellationToken ct = default)
        {
            var venue = new Venue
            {
                Id = Guid.NewGuid(),
                Name = request.Name,
                Address = request.Address,
                City = request.City,
                Country = request.Country,
                Capacity = request.Capacity,
                Latitude = request.Latitude,
                Longitude = request.Longitude,
                CreatedBy = userId,
                CreatedAt = DateTime.UtcNow
            };

            _context.Venues.Add(venue);
            await _context.SaveChangesAsync(ct);

            return new VenueDto(
                venue.Id,
                venue.Name,
                venue.Address,
                venue.City,
                venue.Country,
                venue.Capacity,
                venue.Latitude,
                venue.Longitude,
                venue.CreatedBy,
                venue.CreatedAt,
                0
            );
        }

        public async Task<VenueDto> UpdateVenueAsync(Guid id, UpdateVenueRequest request, string userId, bool isAdmin, CancellationToken ct = default)
        {
            var venue = await _context.Venues
                .FirstOrDefaultAsync(v => v.Id == id, ct);

            if (venue == null)
                throw new ArgumentException("Venue not found");

            // Ownership check - only owner or admin can modify
            if (venue.CreatedBy != userId && !isAdmin)
                throw new UnauthorizedAccessException("Nemate pravo editovati ovaj venue.");

            if (!string.IsNullOrEmpty(request.Name))
                venue.Name = request.Name;

            if (!string.IsNullOrEmpty(request.Address))
                venue.Address = request.Address;

            if (!string.IsNullOrEmpty(request.City))
                venue.City = request.City;

            if (!string.IsNullOrEmpty(request.Country))
                venue.Country = request.Country;

            if (request.Capacity.HasValue)
                venue.Capacity = request.Capacity;

            if (request.Latitude.HasValue)
                venue.Latitude = request.Latitude;

            if (request.Longitude.HasValue)
                venue.Longitude = request.Longitude;

            await _context.SaveChangesAsync(ct);

            var eventCount = await _context.Events
                .CountAsync(e => e.VenueId == id && e.Status == "Published", ct);

            return new VenueDto(
                venue.Id,
                venue.Name,
                venue.Address,
                venue.City,
                venue.Country,
                venue.Capacity,
                venue.Latitude,
                venue.Longitude,
                venue.CreatedBy,
                venue.CreatedAt,
                eventCount
            );
        }

        public async Task<bool> DeleteVenueAsync(Guid id, string userId, bool isAdmin, CancellationToken ct = default)
        {
            var venue = await _context.Venues
                .Include(v => v.Events)
                .FirstOrDefaultAsync(v => v.Id == id, ct);

            if (venue == null)
                return false;

            // Ownership check - only owner or admin can delete
            if (venue.CreatedBy != userId && !isAdmin)
                throw new UnauthorizedAccessException("Nemate pravo brisati ovaj venue.");

            // Check if venue has events
            if (venue.Events.Any())
                throw new InvalidOperationException("Cannot delete venue that has events associated with it");

            _context.Venues.Remove(venue);
            await _context.SaveChangesAsync(ct);

            return true;
        }

        public async Task<IReadOnlyList<VenueDto>> GetMyVenuesAsync(string userId, CancellationToken ct = default)
        {
            var venues = await _context.Venues
                .Where(v => v.CreatedBy == userId)
                .OrderByDescending(v => v.CreatedAt)
                .Select(v => new VenueDto(
                    v.Id,
                    v.Name,
                    v.Address,
                    v.City,
                    v.Country,
                    v.Capacity,
                    v.Latitude,
                    v.Longitude,
                    v.CreatedBy,
                    v.CreatedAt,
                    v.Events.Count(e => e.Status == "Published")
                ))
                .ToListAsync(ct);

            return venues;
        }
    }
}
