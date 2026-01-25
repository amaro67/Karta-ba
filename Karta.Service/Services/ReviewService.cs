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
    public class ReviewService : IReviewService
    {
        private readonly ApplicationDbContext _context;

        public ReviewService(ApplicationDbContext context)
        {
            _context = context;
        }

        public async Task<bool> CanUserReviewEventAsync(string userId, Guid eventId, CancellationToken ct = default)
        {
            // Check if user has a paid ticket for this event
            var hasPaidTicket = await _context.Tickets
                .Include(t => t.OrderItem)
                    .ThenInclude(oi => oi.Order)
                .AnyAsync(t =>
                    t.OrderItem.Order.UserId == userId &&
                    t.OrderItem.EventId == eventId &&
                    t.OrderItem.Order.Status == "Paid",
                    ct);

            if (!hasPaidTicket) return false;

            // Check if user already has a review for this event
            var hasExistingReview = await _context.Reviews
                .AnyAsync(r => r.UserId == userId && r.EventId == eventId, ct);

            return !hasExistingReview;
        }

        public async Task<ReviewDto> CreateReviewAsync(string userId, Guid eventId, CreateReviewRequest request, CancellationToken ct = default)
        {
            // Verify the event exists
            var eventExists = await _context.Events.AnyAsync(e => e.Id == eventId, ct);
            if (!eventExists)
                throw new ArgumentException("Event not found");

            // Verify user can review this event
            var canReview = await CanUserReviewEventAsync(userId, eventId, ct);
            if (!canReview)
                throw new UnauthorizedAccessException("You cannot review this event. You must have purchased a ticket and not already reviewed it.");

            // Get user info for the response
            var user = await _context.Users.FindAsync(new object[] { userId }, ct);
            if (user == null)
                throw new ArgumentException("User not found");

            var review = new Review
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                EventId = eventId,
                Rating = request.Rating,
                Title = request.Title,
                Content = request.Content,
                CreatedAt = DateTime.UtcNow
            };

            _context.Reviews.Add(review);
            await _context.SaveChangesAsync(ct);

            return new ReviewDto(
                review.Id,
                review.EventId,
                review.UserId,
                $"{user.FirstName} {user.LastName}".Trim(),
                review.Rating,
                review.Title,
                review.Content,
                review.CreatedAt,
                review.UpdatedAt
            );
        }

        public async Task<EventReviewsDto> GetEventReviewsAsync(Guid eventId, int page = 1, int pageSize = 10, CancellationToken ct = default)
        {
            var query = _context.Reviews
                .Where(r => r.EventId == eventId)
                .Include(r => r.User);

            var totalCount = await query.CountAsync(ct);

            var averageRating = totalCount > 0
                ? await query.AverageAsync(r => r.Rating, ct)
                : 0;

            var reviews = await query
                .OrderByDescending(r => r.CreatedAt)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .Select(r => new ReviewDto(
                    r.Id,
                    r.EventId,
                    r.UserId,
                    (r.User.FirstName + " " + r.User.LastName).Trim(),
                    r.Rating,
                    r.Title,
                    r.Content,
                    r.CreatedAt,
                    r.UpdatedAt
                ))
                .ToListAsync(ct);

            return new EventReviewsDto(
                Math.Round(averageRating, 1),
                totalCount,
                reviews
            );
        }

        public async Task<ReviewDto?> GetUserReviewForEventAsync(string userId, Guid eventId, CancellationToken ct = default)
        {
            var review = await _context.Reviews
                .Include(r => r.User)
                .FirstOrDefaultAsync(r => r.UserId == userId && r.EventId == eventId, ct);

            if (review == null)
                return null;

            return new ReviewDto(
                review.Id,
                review.EventId,
                review.UserId,
                $"{review.User.FirstName} {review.User.LastName}".Trim(),
                review.Rating,
                review.Title,
                review.Content,
                review.CreatedAt,
                review.UpdatedAt
            );
        }

        public async Task<ReviewDto?> UpdateReviewAsync(Guid reviewId, string userId, UpdateReviewRequest request, CancellationToken ct = default)
        {
            var review = await _context.Reviews
                .Include(r => r.User)
                .FirstOrDefaultAsync(r => r.Id == reviewId, ct);

            if (review == null)
                return null;

            // Only the review owner can update their review
            if (review.UserId != userId)
                throw new UnauthorizedAccessException("You can only update your own reviews");

            if (request.Rating.HasValue)
                review.Rating = request.Rating.Value;

            if (!string.IsNullOrEmpty(request.Title))
                review.Title = request.Title;

            if (!string.IsNullOrEmpty(request.Content))
                review.Content = request.Content;

            review.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync(ct);

            return new ReviewDto(
                review.Id,
                review.EventId,
                review.UserId,
                $"{review.User.FirstName} {review.User.LastName}".Trim(),
                review.Rating,
                review.Title,
                review.Content,
                review.CreatedAt,
                review.UpdatedAt
            );
        }

        public async Task<bool> DeleteReviewAsync(Guid reviewId, string userId, bool isAdmin = false, CancellationToken ct = default)
        {
            var review = await _context.Reviews.FindAsync(new object[] { reviewId }, ct);

            if (review == null)
                return false;

            // Only the review owner or an admin can delete the review
            if (review.UserId != userId && !isAdmin)
                throw new UnauthorizedAccessException("You can only delete your own reviews");

            _context.Reviews.Remove(review);
            await _context.SaveChangesAsync(ct);

            return true;
        }
    }
}
