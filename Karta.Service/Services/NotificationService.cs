using System;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Karta.Model;
using Karta.Model.Entities;
using Karta.Service.DTO;
using Karta.Service.Exceptions;
using Karta.Service.Interfaces;
using Microsoft.EntityFrameworkCore;
namespace Karta.Service.Services
{
    public class NotificationService : INotificationService
    {
        private readonly ApplicationDbContext _context;

        public NotificationService(ApplicationDbContext context)
        {
            _context = context;
        }

        public async Task<PagedResult<NotificationDto>> GetUserNotificationsAsync(string userId, int page, int size, CancellationToken ct = default)
        {
            var query = _context.Notifications
                .Where(n => n.UserId == userId)
                .OrderByDescending(n => n.CreatedAt);

            var total = await query.CountAsync(ct);
            var items = await query
                .Skip((page - 1) * size)
                .Take(size)
                .Select(n => new NotificationDto(
                    n.Id, n.UserId, n.Title, n.Content,
                    n.Type.ToString(), n.IsRead,
                    n.RelatedEntityId, n.RelatedEntityType,
                    n.CreatedAt
                ))
                .ToListAsync(ct);

            return new PagedResult<NotificationDto>
            {
                Items = items,
                Page = page,
                Size = size,
                Total = total
            };
        }

        public async Task<int> GetUnreadCountAsync(string userId, CancellationToken ct = default)
        {
            return await _context.Notifications
                .CountAsync(n => n.UserId == userId && !n.IsRead, ct);
        }

        public async Task MarkAsReadAsync(Guid id, string userId, CancellationToken ct = default)
        {
            var notification = await _context.Notifications
                .FirstOrDefaultAsync(n => n.Id == id && n.UserId == userId, ct);

            if (notification == null)
                throw new NotFoundException("Notification", id);

            notification.IsRead = true;
            await _context.SaveChangesAsync(ct);
        }

        public async Task MarkAllAsReadAsync(string userId, CancellationToken ct = default)
        {
            await _context.Notifications
                .Where(n => n.UserId == userId && !n.IsRead)
                .ExecuteUpdateAsync(s => s.SetProperty(n => n.IsRead, true), ct);
        }

        public async Task DeleteNotificationAsync(Guid id, string userId, CancellationToken ct = default)
        {
            var notification = await _context.Notifications
                .FirstOrDefaultAsync(n => n.Id == id && n.UserId == userId, ct);

            if (notification == null)
                throw new NotFoundException("Notification", id);

            _context.Notifications.Remove(notification);
            await _context.SaveChangesAsync(ct);
        }

        public async Task<NotificationDto> CreateNotificationAsync(string userId, string title, string content, string type, Guid? relatedEntityId = null, string? relatedEntityType = null, CancellationToken ct = default)
        {
            if (!Enum.TryParse<NotificationType>(type, out var notificationType))
                notificationType = NotificationType.SystemAnnouncement;

            var notification = new Notification
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                Title = title,
                Content = content,
                Type = notificationType,
                IsRead = false,
                RelatedEntityId = relatedEntityId,
                RelatedEntityType = relatedEntityType,
                CreatedAt = DateTime.UtcNow
            };

            _context.Notifications.Add(notification);
            await _context.SaveChangesAsync(ct);

            return new NotificationDto(
                notification.Id, notification.UserId, notification.Title, notification.Content,
                notification.Type.ToString(), notification.IsRead,
                notification.RelatedEntityId, notification.RelatedEntityType,
                notification.CreatedAt
            );
        }

        public async Task CreateSystemAnnouncementAsync(string title, string content, CancellationToken ct = default)
        {
            var users = await _context.Users.Select(u => u.Id).ToListAsync(ct);
            var notifications = users.Select(userId => new Notification
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                Title = title,
                Content = content,
                Type = NotificationType.SystemAnnouncement,
                IsRead = false,
                CreatedAt = DateTime.UtcNow
            }).ToList();

            _context.Notifications.AddRange(notifications);
            await _context.SaveChangesAsync(ct);
        }
    }
}
