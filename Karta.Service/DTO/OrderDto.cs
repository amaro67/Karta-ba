using System;
using System.Collections.Generic;
namespace Karta.Service.DTO;
public record TicketDto(Guid Id, string TicketCode, string Status, DateTime IssuedAt, DateTime? UsedAt);
public record OrderItemDto(Guid Id, Guid EventId, Guid PriceTierId, int Qty, decimal UnitPrice, IReadOnlyList<TicketDto> Tickets);
public record OrderDto(Guid Id, string UserId, decimal TotalAmount, string Currency, string Status, DateTime CreatedAt,
                       IReadOnlyList<OrderItemDto> Items, string? UserFirstName = null, string? UserLastName = null, string? UserEmail = null);