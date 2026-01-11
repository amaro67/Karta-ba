using System;
using System.Collections.Generic;
namespace Karta.Service.DTO;
public class PagedResult<T>
{
    public IReadOnlyList<T> Items { get; init; } = Array.Empty<T>();
    public int Page { get; init; }
    public int Size { get; init; }
    public int Total { get; init; }
}