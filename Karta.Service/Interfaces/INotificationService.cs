using System;
using System.Threading;
using System.Threading.Tasks;
using Karta.Service.DTO;
namespace Karta.Service.Interfaces;

public interface INotificationService
{
    Task<PagedResult<NotificationDto>> GetUserNotificationsAsync(string userId, int page, int size, CancellationToken ct = default);
    Task<int> GetUnreadCountAsync(string userId, CancellationToken ct = default);
    Task MarkAsReadAsync(Guid id, string userId, CancellationToken ct = default);
    Task MarkAllAsReadAsync(string userId, CancellationToken ct = default);
    Task DeleteNotificationAsync(Guid id, string userId, CancellationToken ct = default);
    Task<NotificationDto> CreateNotificationAsync(string userId, string title, string content, string type, Guid? relatedEntityId = null, string? relatedEntityType = null, CancellationToken ct = default);
    Task CreateSystemAnnouncementAsync(string title, string content, CancellationToken ct = default);
}
