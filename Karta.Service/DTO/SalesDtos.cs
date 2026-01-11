using System;
namespace Karta.Service.DTO
{
    public record OrganizerOrderDto(
        Guid OrderId,
        string BuyerEmail,
        DateTime CreatedAt,
        decimal TotalAmount,
        string Currency,
        string Status,
        string EventTitle,
        Guid EventId,
        int TicketsCount
    );
}