using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Karta.Model;
using Karta.Model.Entities;
using Karta.Service.DTO;
using Karta.Service.Interfaces;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
namespace Karta.Service.Services
{
    public class ScannerService : IScannerService
    {
        private readonly ApplicationDbContext _dbContext;
        private readonly UserManager<ApplicationUser> _userManager;
        public ScannerService(ApplicationDbContext dbContext, UserManager<ApplicationUser> userManager)
        {
            _dbContext = dbContext;
            _userManager = userManager;
        }
        public async Task<ScannerUserDto> CreateScannerAsync(CreateScannerUserRequest request, string organizerId, CancellationToken ct = default)
        {
            var existingUser = await _userManager.FindByEmailAsync(request.Email);
            if (existingUser != null)
            {
                throw new InvalidOperationException("Korisnik sa unesenim emailom već postoji.");
            }
            var user = new ApplicationUser
            {
                Id = Guid.NewGuid().ToString(),
                UserName = request.Email,
                NormalizedUserName = request.Email.ToUpperInvariant(),
                Email = request.Email,
                NormalizedEmail = request.Email.ToUpperInvariant(),
                EmailConfirmed = true,
                FirstName = request.FirstName,
                LastName = request.LastName,
                CreatedAt = DateTime.UtcNow,
                CreatedByOrganizerId = organizerId
            };
            var result = await _userManager.CreateAsync(user, request.Password);
            if (!result.Succeeded)
            {
                var errors = string.Join(", ", result.Errors.Select(e => e.Description));
                throw new InvalidOperationException(errors);
            }
            var roleResult = await _userManager.AddToRoleAsync(user, "Scanner");
            if (!roleResult.Succeeded)
            {
                var errors = string.Join(", ", roleResult.Errors.Select(e => e.Description));
                throw new InvalidOperationException(errors);
            }
            return new ScannerUserDto(user.Id, user.Email ?? string.Empty, user.FirstName ?? string.Empty, user.LastName ?? string.Empty);
        }
        public async Task<IReadOnlyList<ScannerUserDto>> GetOrganizerScannersAsync(string organizerId, CancellationToken ct = default)
        {
            var users = await _userManager.Users
                .Where(u => u.CreatedByOrganizerId == organizerId)
                .OrderBy(u => u.FirstName)
                .ThenBy(u => u.LastName)
                .Select(u => new ScannerUserDto(
                    u.Id,
                    u.Email ?? string.Empty,
                    u.FirstName ?? string.Empty,
                    u.LastName ?? string.Empty))
                .ToListAsync(ct);
            return users;
        }
        public async Task<IReadOnlyList<EventScannerSummaryDto>> GetOrganizerEventScannersAsync(string organizerId, CancellationToken ct = default)
        {
            var events = await _dbContext.Events
                .Where(e => e.CreatedBy == organizerId)
                .Select(e => new
                {
                    e.Id,
                    e.Title,
                    e.StartsAt,
                    e.EndsAt,
                    e.City
                })
                .ToListAsync(ct);
            var assignments = await _dbContext.EventScannerAssignments
                .Where(a => events.Select(ev => ev.Id).Contains(a.EventId))
                .Include(a => a.Scanner)
                .ToListAsync(ct);
            var grouped = events.Select(ev =>
            {
                var scanners = assignments
                    .Where(a => a.EventId == ev.Id)
                    .Select(a => new ScannerUserDto(
                        a.ScannerUserId,
                        a.Scanner.Email ?? string.Empty,
                        a.Scanner.FirstName ?? string.Empty,
                        a.Scanner.LastName ?? string.Empty))
                    .ToList();
                return new EventScannerSummaryDto(
                    ev.Id,
                    ev.Title,
                    ev.StartsAt,
                    ev.EndsAt,
                    ev.City,
                    scanners);
            }).ToList();
            return grouped;
        }
        public async Task<IReadOnlyList<EventScannerSummaryDto>> GetScannerEventsAsync(string scannerUserId, CancellationToken ct = default)
        {
            var assignments = await _dbContext.EventScannerAssignments
                .Where(a => a.ScannerUserId == scannerUserId)
                .Include(a => a.Event)
                .Include(a => a.Scanner)
                .ToListAsync(ct);
            var events = assignments.Select(a => a.Event).Distinct().ToList();
            var result = events.Select(ev =>
            {
                var scanners = assignments
                    .Where(a => a.EventId == ev.Id)
                    .Select(a => new ScannerUserDto(
                        a.ScannerUserId,
                        a.Scanner.Email ?? string.Empty,
                        a.Scanner.FirstName ?? string.Empty,
                        a.Scanner.LastName ?? string.Empty))
                    .ToList();
                return new EventScannerSummaryDto(
                    ev.Id,
                    ev.Title,
                    ev.StartsAt,
                    ev.EndsAt,
                    ev.City,
                    scanners);
            }).ToList();
            return result;
        }
        public async Task AssignScannerToEventAsync(AssignScannerRequest request, string organizerId, CancellationToken ct = default)
        {
            var eventEntity = await _dbContext.Events.FirstOrDefaultAsync(e => e.Id == request.EventId, ct);
            if (eventEntity == null || eventEntity.CreatedBy != organizerId)
            {
                throw new InvalidOperationException("Ne možete dodijeliti scannera događaju koji ne pripada vama.");
            }
            var scanner = await _userManager.Users.FirstOrDefaultAsync(u => u.Id == request.ScannerUserId, ct);
            if (scanner == null || scanner.CreatedByOrganizerId != organizerId)
            {
                throw new InvalidOperationException("Scanner nije pronađen ili ne pripada vašem timu.");
            }
            var exists = await _dbContext.EventScannerAssignments
                .AnyAsync(a => a.EventId == request.EventId && a.ScannerUserId == request.ScannerUserId, ct);
            if (exists)
            {
                return;
            }
            var assignment = new EventScannerAssignment
            {
                Id = Guid.NewGuid(),
                EventId = request.EventId,
                ScannerUserId = request.ScannerUserId,
                AssignedAt = DateTime.UtcNow
            };
            _dbContext.EventScannerAssignments.Add(assignment);
            await _dbContext.SaveChangesAsync(ct);
        }
        public async Task RemoveScannerFromEventAsync(AssignScannerRequest request, string organizerId, CancellationToken ct = default)
        {
            var assignment = await _dbContext.EventScannerAssignments
                .Include(a => a.Event)
                .FirstOrDefaultAsync(a => a.EventId == request.EventId && a.ScannerUserId == request.ScannerUserId, ct);
            if (assignment == null)
            {
                return;
            }
            if (assignment.Event.CreatedBy != organizerId)
            {
                throw new InvalidOperationException("Ne možete ukloniti scannera sa događaja koji ne pripada vama.");
            }
            _dbContext.EventScannerAssignments.Remove(assignment);
            await _dbContext.SaveChangesAsync(ct);
        }
    }
}