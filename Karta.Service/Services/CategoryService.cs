using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Karta.Model;
using Karta.Model.Entities;
using Karta.Service.DTO;
using Karta.Service.Interfaces;
using Microsoft.EntityFrameworkCore;
namespace Karta.Service.Services
{
    public class CategoryService : ICategoryService
    {
        private readonly ApplicationDbContext _context;

        public CategoryService(ApplicationDbContext context)
        {
            _context = context;
        }

        public async Task<IReadOnlyList<CategoryDto>> GetCategoriesAsync(bool includeInactive = false, CancellationToken ct = default)
        {
            var query = _context.Categories.AsQueryable();

            if (!includeInactive)
            {
                query = query.Where(c => c.IsActive);
            }

            var categories = await query
                .OrderBy(c => c.DisplayOrder)
                .ThenBy(c => c.Name)
                .Select(c => new CategoryDto(
                    c.Id,
                    c.Name,
                    c.Slug,
                    c.Description,
                    c.IconUrl,
                    c.DisplayOrder,
                    c.IsActive,
                    c.CreatedAt,
                    c.Events.Count(e => e.Status == "Published")
                ))
                .ToListAsync(ct);

            return categories;
        }

        public async Task<CategoryDto?> GetCategoryAsync(Guid id, CancellationToken ct = default)
        {
            var category = await _context.Categories
                .Where(c => c.Id == id)
                .Select(c => new CategoryDto(
                    c.Id,
                    c.Name,
                    c.Slug,
                    c.Description,
                    c.IconUrl,
                    c.DisplayOrder,
                    c.IsActive,
                    c.CreatedAt,
                    c.Events.Count(e => e.Status == "Published")
                ))
                .FirstOrDefaultAsync(ct);

            return category;
        }

        public async Task<CategoryDto?> GetCategoryBySlugAsync(string slug, CancellationToken ct = default)
        {
            var category = await _context.Categories
                .Where(c => c.Slug == slug)
                .Select(c => new CategoryDto(
                    c.Id,
                    c.Name,
                    c.Slug,
                    c.Description,
                    c.IconUrl,
                    c.DisplayOrder,
                    c.IsActive,
                    c.CreatedAt,
                    c.Events.Count(e => e.Status == "Published")
                ))
                .FirstOrDefaultAsync(ct);

            return category;
        }

        public async Task<CategoryDto> CreateCategoryAsync(CreateCategoryRequest request, CancellationToken ct = default)
        {
            var slug = GenerateSlug(request.Name);

            // Check for duplicate slug
            var existingSlug = await _context.Categories
                .AnyAsync(c => c.Slug == slug, ct);

            if (existingSlug)
            {
                slug = $"{slug}-{Guid.NewGuid().ToString().Substring(0, 8)}";
            }

            var category = new Category
            {
                Id = Guid.NewGuid(),
                Name = request.Name,
                Slug = slug,
                Description = request.Description,
                IconUrl = request.IconUrl,
                DisplayOrder = request.DisplayOrder,
                IsActive = true,
                CreatedAt = DateTime.UtcNow
            };

            _context.Categories.Add(category);
            await _context.SaveChangesAsync(ct);

            return new CategoryDto(
                category.Id,
                category.Name,
                category.Slug,
                category.Description,
                category.IconUrl,
                category.DisplayOrder,
                category.IsActive,
                category.CreatedAt,
                0
            );
        }

        public async Task<CategoryDto> UpdateCategoryAsync(Guid id, UpdateCategoryRequest request, CancellationToken ct = default)
        {
            var category = await _context.Categories
                .FirstOrDefaultAsync(c => c.Id == id, ct);

            if (category == null)
                throw new ArgumentException("Category not found");

            if (!string.IsNullOrEmpty(request.Name))
            {
                category.Name = request.Name;
                category.Slug = GenerateSlug(request.Name);
            }

            if (request.Description != null)
                category.Description = request.Description;

            if (request.IconUrl != null)
                category.IconUrl = request.IconUrl;

            if (request.DisplayOrder.HasValue)
                category.DisplayOrder = request.DisplayOrder.Value;

            if (request.IsActive.HasValue)
                category.IsActive = request.IsActive.Value;

            await _context.SaveChangesAsync(ct);

            var eventCount = await _context.Events
                .CountAsync(e => e.CategoryId == id && e.Status == "Published", ct);

            return new CategoryDto(
                category.Id,
                category.Name,
                category.Slug,
                category.Description,
                category.IconUrl,
                category.DisplayOrder,
                category.IsActive,
                category.CreatedAt,
                eventCount
            );
        }

        public async Task<bool> DeleteCategoryAsync(Guid id, CancellationToken ct = default)
        {
            var category = await _context.Categories
                .FirstOrDefaultAsync(c => c.Id == id, ct);

            if (category == null)
                return false;

            _context.Categories.Remove(category);
            await _context.SaveChangesAsync(ct);

            return true;
        }

        private static string GenerateSlug(string name)
        {
            if (string.IsNullOrEmpty(name))
                return string.Empty;

            return name
                .ToLowerInvariant()
                .Replace(" ", "-")
                .Replace("š", "s")
                .Replace("đ", "d")
                .Replace("č", "c")
                .Replace("ć", "c")
                .Replace("ž", "z")
                .Replace("&", "and")
                .Replace("@", "at")
                .Trim('-');
        }
    }
}
