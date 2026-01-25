using System;
using System.Threading;
using System.Threading.Tasks;
using Karta.Service.DTO;

namespace Karta.Service.Interfaces;

public interface IReviewService
{
    Task<ReviewDto> CreateReviewAsync(string userId, Guid eventId, CreateReviewRequest request, CancellationToken ct = default);
    Task<EventReviewsDto> GetEventReviewsAsync(Guid eventId, int page = 1, int pageSize = 10, CancellationToken ct = default);
    Task<ReviewDto?> UpdateReviewAsync(Guid reviewId, string userId, UpdateReviewRequest request, CancellationToken ct = default);
    Task<bool> DeleteReviewAsync(Guid reviewId, string userId, bool isAdmin = false, CancellationToken ct = default);
    Task<bool> CanUserReviewEventAsync(string userId, Guid eventId, CancellationToken ct = default);
    Task<ReviewDto?> GetUserReviewForEventAsync(string userId, Guid eventId, CancellationToken ct = default);
}
