using System;
using System.Collections.Generic;
namespace Karta.Service.DTO
{
    public record DashboardStatsResponse(
        decimal TotalRevenue,
        int NumberOfEvents,
        int TotalUsersRegistered,
        decimal KartaBaProfit
    );
    public record UpcomingEventDto(
        Guid Id,
        string Title,
        DateTimeOffset StartsAt,
        string Location,
        string City,
        decimal PriceFrom,
        string Currency,
        string? CoverImageUrl
    );
}