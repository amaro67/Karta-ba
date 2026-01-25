using Karta.Service.DTO;
using Karta.Service.Interfaces;
using Karta.WebAPI.Authorization;
using Karta.WebAPI.Filters;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Swashbuckle.AspNetCore.Annotations;
namespace Karta.WebAPI.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [SwaggerTag("Upravljanje kategorijama evenata")]
    public class CategoryController : ControllerBase
    {
        private readonly ICategoryService _categoryService;
        private readonly ILogger<CategoryController> _logger;

        public CategoryController(ICategoryService categoryService, ILogger<CategoryController> logger)
        {
            _categoryService = categoryService;
            _logger = logger;
        }

        [HttpGet]
        [SwaggerOperation(Summary = "Dohvata sve aktivne kategorije",
                         Description = "Vraća listu svih aktivnih kategorija sortirane po DisplayOrder")]
        [SwaggerResponse(200, "Uspešno vraćena lista kategorija", typeof(IReadOnlyList<CategoryDto>))]
        public async Task<ActionResult<IReadOnlyList<CategoryDto>>> GetCategories([FromQuery] bool includeInactive = false)
        {
            // Only admins can see inactive categories
            if (includeInactive && !User.IsInRole("Admin"))
            {
                includeInactive = false;
            }

            var categories = await _categoryService.GetCategoriesAsync(includeInactive);
            return Ok(categories);
        }

        [HttpGet("{id}")]
        [SwaggerOperation(Summary = "Dohvata kategoriju po ID-u")]
        [SwaggerResponse(200, "Uspešno vraćena kategorija", typeof(CategoryDto))]
        [SwaggerResponse(404, "Kategorija nije pronađena")]
        public async Task<ActionResult<CategoryDto>> GetCategory(Guid id)
        {
            var category = await _categoryService.GetCategoryAsync(id);
            if (category == null)
                return NotFound();

            return Ok(category);
        }

        [HttpGet("slug/{slug}")]
        [SwaggerOperation(Summary = "Dohvata kategoriju po slug-u")]
        [SwaggerResponse(200, "Uspešno vraćena kategorija", typeof(CategoryDto))]
        [SwaggerResponse(404, "Kategorija nije pronađena")]
        public async Task<ActionResult<CategoryDto>> GetCategoryBySlug(string slug)
        {
            var category = await _categoryService.GetCategoryBySlugAsync(slug);
            if (category == null)
                return NotFound();

            return Ok(category);
        }

        [HttpPost]
        [Authorize(Roles = "Admin")]
        [ServiceFilter(typeof(ValidationFilterAttribute))]
        [SwaggerOperation(Summary = "Kreira novu kategoriju (samo admin)",
                         Description = "Kreira novu kategoriju za evente. Dostupno samo administratorima.")]
        [SwaggerResponse(201, "Kategorija uspešno kreirana", typeof(CategoryDto))]
        [SwaggerResponse(400, "Neispravni podaci")]
        [SwaggerResponse(401, "Korisnik nije autentifikovan")]
        [SwaggerResponse(403, "Nedovoljna prava")]
        public async Task<ActionResult<CategoryDto>> CreateCategory([FromBody] CreateCategoryRequest request)
        {
            if (!ModelState.IsValid)
                return BadRequest(ModelState);

            try
            {
                var category = await _categoryService.CreateCategoryAsync(request);
                return CreatedAtAction(nameof(GetCategory), new { id = category.Id }, category);
            }
            catch (ArgumentException ex)
            {
                return BadRequest(ex.Message);
            }
        }

        [HttpPut("{id}")]
        [Authorize(Roles = "Admin")]
        [ServiceFilter(typeof(ValidationFilterAttribute))]
        [SwaggerOperation(Summary = "Ažurira kategoriju (samo admin)")]
        [SwaggerResponse(200, "Kategorija uspešno ažurirana", typeof(CategoryDto))]
        [SwaggerResponse(400, "Neispravni podaci")]
        [SwaggerResponse(401, "Korisnik nije autentifikovan")]
        [SwaggerResponse(403, "Nedovoljna prava")]
        [SwaggerResponse(404, "Kategorija nije pronađena")]
        public async Task<ActionResult<CategoryDto>> UpdateCategory(Guid id, [FromBody] UpdateCategoryRequest request)
        {
            if (!ModelState.IsValid)
                return BadRequest(ModelState);

            try
            {
                var category = await _categoryService.UpdateCategoryAsync(id, request);
                return Ok(category);
            }
            catch (ArgumentException ex)
            {
                return NotFound(ex.Message);
            }
        }

        [HttpDelete("{id}")]
        [Authorize(Roles = "Admin")]
        [SwaggerOperation(Summary = "Briše kategoriju (samo admin)")]
        [SwaggerResponse(204, "Kategorija uspešno obrisana")]
        [SwaggerResponse(401, "Korisnik nije autentifikovan")]
        [SwaggerResponse(403, "Nedovoljna prava")]
        [SwaggerResponse(404, "Kategorija nije pronađena")]
        public async Task<ActionResult> DeleteCategory(Guid id)
        {
            var success = await _categoryService.DeleteCategoryAsync(id);
            if (!success)
                return NotFound();

            return NoContent();
        }
    }
}
