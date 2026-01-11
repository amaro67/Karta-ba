using Karta.Model;
using Microsoft.AspNetCore.Identity;
namespace Karta.WebAPI.Services
{
    public class RoleInitializationService
    {
        public static async Task InitializeRoles(IServiceProvider serviceProvider)
        {
            var roleManager = serviceProvider.GetRequiredService<RoleManager<ApplicationRole>>();
            var roles = new[]
            {
                new ApplicationRole
                {
                    Name = "Admin",
                    Description = "Administrator - puna kontrola nad sistemom"
                },
                new ApplicationRole
                {
                    Name = "Manager",
                    Description = "Menadžer - upravljanje timom i projektima"
                },
                new ApplicationRole
                {
                    Name = "User",
                    Description = "Običan korisnik - osnovne funkcionalnosti"
                },
                new ApplicationRole
                {
                    Name = "Guest",
                    Description = "Gost - ograničen pristup"
                },
                new ApplicationRole
                {
                    Name = "Moderator",
                    Description = "Moderator - upravljanje sadržajem"
                },
                new ApplicationRole
                {
                    Name = "Developer",
                    Description = "Developer - pristup development alatima"
                }
            };
            foreach (var role in roles)
            {
                if (!await roleManager.RoleExistsAsync(role.Name))
                {
                    await roleManager.CreateAsync(role);
                }
            }
        }
    }
}