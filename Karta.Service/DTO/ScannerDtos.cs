using System;
using System.Collections.Generic;
namespace Karta.Service.DTO
{
    public record ScannerUserDto(
        string Id,
        string Email,
        string FirstName,
        string LastName
    );
    public record EventScannerSummaryDto(
        Guid EventId,
        string Title,
        DateTimeOffset StartsAt,
        DateTimeOffset? EndsAt,
        string City,
        IReadOnlyList<ScannerUserDto> Scanners
    );
    public record CreateScannerUserRequest(
        string Email,
        string Password,
        string FirstName,
        string LastName
    );
    public record AssignScannerRequest(
        Guid EventId,
        string ScannerUserId
    );
}