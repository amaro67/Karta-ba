using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using Karta.Service.DTO;
namespace Karta.Service.Interfaces;

public interface IVenueService
{
    Task<IReadOnlyList<VenueDto>> GetVenuesAsync(string? city = null, CancellationToken ct = default);
    Task<VenueDto?> GetVenueAsync(Guid id, CancellationToken ct = default);
    Task<VenueDto> CreateVenueAsync(CreateVenueRequest request, string userId, CancellationToken ct = default);
    Task<VenueDto> UpdateVenueAsync(Guid id, UpdateVenueRequest request, string userId, bool isAdmin, CancellationToken ct = default);
    Task<bool> DeleteVenueAsync(Guid id, string userId, bool isAdmin, CancellationToken ct = default);
    Task<IReadOnlyList<VenueDto>> GetMyVenuesAsync(string userId, CancellationToken ct = default);
}
