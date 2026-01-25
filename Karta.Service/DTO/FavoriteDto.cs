using System;
namespace Karta.Service.DTO;

public record FavoriteDto(Guid EventId, DateTime CreatedAt);

public record FavoriteEventDto(EventDto Event, DateTime FavoritedAt);
