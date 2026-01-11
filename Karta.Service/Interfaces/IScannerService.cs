using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using Karta.Service.DTO;
namespace Karta.Service.Interfaces
{
    public interface IScannerService
    {
        Task<ScannerUserDto> CreateScannerAsync(CreateScannerUserRequest request, string organizerId, CancellationToken ct = default);
        Task<IReadOnlyList<ScannerUserDto>> GetOrganizerScannersAsync(string organizerId, CancellationToken ct = default);
        Task<IReadOnlyList<EventScannerSummaryDto>> GetOrganizerEventScannersAsync(string organizerId, CancellationToken ct = default);
        Task<IReadOnlyList<EventScannerSummaryDto>> GetScannerEventsAsync(string scannerUserId, CancellationToken ct = default);
        Task AssignScannerToEventAsync(AssignScannerRequest request, string organizerId, CancellationToken ct = default);
        Task RemoveScannerFromEventAsync(AssignScannerRequest request, string organizerId, CancellationToken ct = default);
    }
}