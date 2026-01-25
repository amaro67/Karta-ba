using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using Karta.Service.DTO;
namespace Karta.Service.Interfaces;

public interface ICategoryService
{
    Task<IReadOnlyList<CategoryDto>> GetCategoriesAsync(bool includeInactive = false, CancellationToken ct = default);
    Task<CategoryDto?> GetCategoryAsync(Guid id, CancellationToken ct = default);
    Task<CategoryDto?> GetCategoryBySlugAsync(string slug, CancellationToken ct = default);
    Task<CategoryDto> CreateCategoryAsync(CreateCategoryRequest request, CancellationToken ct = default);
    Task<CategoryDto> UpdateCategoryAsync(Guid id, UpdateCategoryRequest request, CancellationToken ct = default);
    Task<bool> DeleteCategoryAsync(Guid id, CancellationToken ct = default);
}
