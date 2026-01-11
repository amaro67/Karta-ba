using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using Karta.Service.DTO;
namespace Karta.Service.Interfaces;
public interface IOrderService
{
    Task<(Guid orderId, string clientSecret)> CreatePaymentIntentAsync(CreateOrderRequest req, CancellationToken ct = default);
    Task<OrderDto?> GetOrderAsync(Guid id, string userId, CancellationToken ct = default);
    Task<OrderDto?> GetOrderByIdAsync(Guid id, CancellationToken ct = default);
    Task<IReadOnlyList<OrderDto>> GetMyOrdersAsync(string userId, CancellationToken ct = default);
    Task<PagedResult<OrderDto>> GetAllOrdersAsync(string? query, string? userId, string? status, DateTimeOffset? from, DateTimeOffset? to, int page, int size, CancellationToken ct = default);
    Task<IReadOnlyList<OrganizerOrderDto>> GetOrganizerOrdersAsync(string organizerId, CancellationToken ct = default);
    Task HandleStripeWebhookAsync(string json, string? signature, CancellationToken ct = default);
    Task ClearAllOrdersAsync(CancellationToken ct = default);
}