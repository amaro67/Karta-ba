using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using Karta.Service.DTO;
namespace Karta.Service.Interfaces;

public interface IFavoriteService
{
    Task<FavoriteDto> AddFavoriteAsync(string userId, Guid eventId, CancellationToken ct = default);
    Task<bool> RemoveFavoriteAsync(string userId, Guid eventId, CancellationToken ct = default);
    Task<bool> IsFavoriteAsync(string userId, Guid eventId, CancellationToken ct = default);
    Task<IReadOnlyList<FavoriteEventDto>> GetFavoritesAsync(string userId, CancellationToken ct = default);
    Task<IReadOnlyList<Guid>> GetFavoriteEventIdsAsync(string userId, CancellationToken ct = default);
}
