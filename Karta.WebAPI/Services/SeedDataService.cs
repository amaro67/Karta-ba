using Karta.Model;
using Karta.Model.Entities;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
namespace Karta.WebAPI.Services
{
    public class SeedDataService
    {
        public static async Task SeedAdminUser(IServiceProvider serviceProvider)
        {
            var userManager = serviceProvider.GetRequiredService<UserManager<ApplicationUser>>();
            var roleManager = serviceProvider.GetRequiredService<RoleManager<ApplicationRole>>();
            var logger = serviceProvider.GetRequiredService<ILogger<SeedDataService>>();
            const string adminEmail = "amar.omerovic0607@gmail.com";
            const string adminPassword = "Password123!";
            try
            {
                if (!await roleManager.RoleExistsAsync("Admin"))
                {
                    logger.LogWarning("Admin rola ne postoji");
                    return;
                }
                var adminUser = await userManager.FindByEmailAsync(adminEmail);
                if (adminUser == null)
                {
                    adminUser = new ApplicationUser
                    {
                        UserName = adminEmail,
                        Email = adminEmail,
                        EmailConfirmed = true,
                        FirstName = "Admin",
                        LastName = "User",
                        CreatedAt = DateTime.UtcNow
                    };
                    var createResult = await userManager.CreateAsync(adminUser, adminPassword);
                    if (!createResult.Succeeded)
                    {
                        logger.LogError("Greška pri kreiranju admin korisnika: {Errors}",
                            string.Join(", ", createResult.Errors.Select(e => e.Description)));
                        return;
                    }
                    logger.LogInformation("Admin korisnik {Email} je kreiran", adminEmail);
                }
                var passwordToken = await userManager.GeneratePasswordResetTokenAsync(adminUser);
                var passwordResult = await userManager.ResetPasswordAsync(adminUser, passwordToken, adminPassword);
                if (passwordResult.Succeeded)
                {
                    logger.LogInformation("Password za admin korisnika {Email} je ažuriran", adminEmail);
                }
                else
                {
                    logger.LogWarning("Nije moguće ažurirati password za {Email}: {Errors}",
                        adminEmail, string.Join(", ", passwordResult.Errors.Select(e => e.Description)));
                }
                if (await userManager.IsInRoleAsync(adminUser, "Admin"))
                {
                    logger.LogInformation("Korisnik {Email} već ima Admin rolu", adminUser.Email);
                    return;
                }
                var result = await userManager.AddToRoleAsync(adminUser, "Admin");
                if (result.Succeeded)
                {
                    logger.LogInformation("Admin rola uspješno dodijeljena korisniku {Email}", adminUser.Email);
                }
                else
                {
                    logger.LogError("Greška pri dodjeljivanju Admin role korisniku {Email}: {Errors}",
                        adminUser.Email, string.Join(", ", result.Errors.Select(e => e.Description)));
                }
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Greška pri seed-ovanju admin korisnika");
            }
        }

        public static async Task SeedAllData(IServiceProvider serviceProvider)
        {
            var context = serviceProvider.GetRequiredService<ApplicationDbContext>();
            var userManager = serviceProvider.GetRequiredService<UserManager<ApplicationUser>>();
            var roleManager = serviceProvider.GetRequiredService<RoleManager<ApplicationRole>>();
            var logger = serviceProvider.GetRequiredService<ILogger<SeedDataService>>();
            try
            {
                logger.LogInformation("Počinje seed-ovanje podataka...");

                // 1. Uvijek kreiraj testne korisnike
                logger.LogInformation("Kreiranje testnih korisnika...");
                var testUsers = await CreateTestUsersAsync(userManager, roleManager, logger);
                logger.LogInformation($"Kreirano {testUsers.Count} testnih korisnika.");

                // 2. Kreiranje kategorija (uvijek, jer su foundational data)
                if (!await context.Categories.AnyAsync())
                {
                    logger.LogInformation("Kreiranje kategorija...");
                    var categories = await CreateCategoriesAsync(context, logger);
                    logger.LogInformation($"Kreirano {categories.Count} kategorija.");
                }
                else
                {
                    logger.LogInformation("Kategorije već postoje, preskačem kreiranje.");
                }

                // 3. Kreiranje venue-a (uvijek, jer su foundational data)
                if (!await context.Venues.AnyAsync())
                {
                    logger.LogInformation("Kreiranje venue-a...");
                    var testOrganizers = testUsers.Where(u => userManager.IsInRoleAsync(u, "Organizer").Result).ToList();
                    var venues = await CreateVenuesAsync(context, testOrganizers, logger);
                    logger.LogInformation($"Kreirano {venues.Count} venue-a.");
                }
                else
                {
                    logger.LogInformation("Venue-i već postoje, preskačem kreiranje.");
                }

                // 4. Provjera da li postoje eventi - ako da, preskoči ostalo
                if (await context.Events.AnyAsync())
                {
                    logger.LogWarning("Baza već sadrži evente. Preskačem seed-ovanje ostalih podataka.");
                    return;
                }

                // 5. Kreiranje production korisnika
                logger.LogInformation("Kreiranje korisnika...");
                var users = await CreateUsersAsync(userManager, roleManager, logger);
                logger.LogInformation($"Kreirano {users.Count} korisnika.");

                // 6. Dohvati kategorije i venue-e iz baze (za events kreiranje)
                var allCategories = await context.Categories.ToListAsync();
                var allVenues = await context.Venues.ToListAsync();
                var organizers = users.Where(u => userManager.IsInRoleAsync(u, "Organizer").Result).ToList();

                // 7. Kreiranje događaja (20 events linked to categories and venues)
                logger.LogInformation("Kreiranje događaja...");
                var events = await CreateEventsAsync(context, organizers, allCategories, allVenues, logger);
                logger.LogInformation($"Kreirano {events.Count} događaja.");

                // 8. Kreiranje PriceTier-ova
                logger.LogInformation("Kreiranje PriceTier-ova...");
                var priceTiers = await CreatePriceTiersAsync(context, events, logger);
                logger.LogInformation($"Kreirano {priceTiers.Count} PriceTier-ova.");

                // 9. Kreiranje narudžbi
                logger.LogInformation("Kreiranje narudžbi...");
                var regularUsers = users.Where(u => userManager.IsInRoleAsync(u, "User").Result).ToList();
                var orders = await CreateOrdersAsync(context, regularUsers, events, priceTiers, logger);
                logger.LogInformation($"Kreirano {orders.Count} narudžbi.");

                // 10. Kreiranje admin user narudžbi
                logger.LogInformation("Kreiranje admin user narudžbi...");
                var adminUser = await userManager.FindByEmailAsync("amar.omerovic0607@gmail.com");
                var adminOrders = await CreateAdminUserOrdersAsync(context, adminUser, events, priceTiers, logger);
                logger.LogInformation($"Kreirano {adminOrders.Count} admin narudžbi.");

                // Combine all orders for order items creation
                var allOrders = orders.Concat(adminOrders).ToList();

                // 11. Kreiranje OrderItem-ova
                logger.LogInformation("Kreiranje OrderItem-ova...");
                var orderItems = await CreateOrderItemsAsync(context, orders, events, priceTiers, logger);
                logger.LogInformation($"Kreirano {orderItems.Count} OrderItem-ova.");

                // 12. Kreiranje Ticket-ova
                logger.LogInformation("Kreiranje Ticket-ova...");
                var tickets = await CreateTicketsAsync(context, orderItems, logger);
                logger.LogInformation($"Kreirano {tickets.Count} Ticket-ova.");

                // 13. Kreiranje Reviews
                logger.LogInformation("Kreiranje recenzija...");
                var allUsers = users.Concat(testUsers).ToList();
                if (adminUser != null) allUsers.Add(adminUser);
                var reviews = await CreateReviewsAsync(context, allUsers, events, adminUser, logger);
                logger.LogInformation($"Kreirano {reviews.Count} recenzija.");

                // 14. Kreiranje UserFavorites
                logger.LogInformation("Kreiranje favorita...");
                var favorites = await CreateUserFavoritesAsync(context, allUsers, events, adminUser, logger);
                logger.LogInformation($"Kreirano {favorites.Count} favorita.");

                // 15. Kreiranje ScanLog-ova
                logger.LogInformation("Kreiranje ScanLog-ova...");
                var scanLogs = await CreateScanLogsAsync(context, tickets, orderItems, logger);
                logger.LogInformation($"Kreirano {scanLogs.Count} ScanLog-ova.");

                // 16. Kreiranje EventScannerAssignment-ova
                logger.LogInformation("Kreiranje EventScannerAssignment-ova...");
                var scanners = users.Where(u => userManager.IsInRoleAsync(u, "Scanner").Result).ToList();
                var assignments = await CreateEventScannerAssignmentsAsync(context, events, scanners, logger);
                logger.LogInformation($"Kreirano {assignments.Count} EventScannerAssignment-ova.");

                await context.SaveChangesAsync();
                logger.LogInformation("Seed-ovanje podataka uspješno završeno!");
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Greška pri seed-ovanju podataka");
                throw;
            }
        }

        private static async Task<List<Category>> CreateCategoriesAsync(
            ApplicationDbContext context,
            ILogger<SeedDataService> logger)
        {
            var categories = new List<Category>
            {
                new Category
                {
                    Id = Guid.NewGuid(),
                    Name = "Muzika",
                    Slug = "muzika",
                    Description = "Koncerti, festivali i muzički događaji",
                    DisplayOrder = 1,
                    IsActive = true,
                    CreatedAt = DateTime.UtcNow
                },
                new Category
                {
                    Id = Guid.NewGuid(),
                    Name = "Sport",
                    Slug = "sport",
                    Description = "Sportski događaji i utakmice",
                    DisplayOrder = 2,
                    IsActive = true,
                    CreatedAt = DateTime.UtcNow
                },
                new Category
                {
                    Id = Guid.NewGuid(),
                    Name = "Kultura",
                    Slug = "kultura",
                    Description = "Kazalište, izložbe i kulturni događaji",
                    DisplayOrder = 3,
                    IsActive = true,
                    CreatedAt = DateTime.UtcNow
                },
                new Category
                {
                    Id = Guid.NewGuid(),
                    Name = "Tehnologija",
                    Slug = "tehnologija",
                    Description = "Tech konferencije i hackathoni",
                    DisplayOrder = 4,
                    IsActive = true,
                    CreatedAt = DateTime.UtcNow
                },
                new Category
                {
                    Id = Guid.NewGuid(),
                    Name = "Edukacija",
                    Slug = "edukacija",
                    Description = "Radionice, seminari i predavanja",
                    DisplayOrder = 5,
                    IsActive = true,
                    CreatedAt = DateTime.UtcNow
                },
                new Category
                {
                    Id = Guid.NewGuid(),
                    Name = "Zabava",
                    Slug = "zabava",
                    Description = "Stand-up, zabavni programi",
                    DisplayOrder = 6,
                    IsActive = true,
                    CreatedAt = DateTime.UtcNow
                }
            };

            context.Categories.AddRange(categories);
            await context.SaveChangesAsync();
            return categories;
        }

        private static async Task<List<Venue>> CreateVenuesAsync(
            ApplicationDbContext context,
            List<ApplicationUser> organizers,
            ILogger<SeedDataService> logger)
        {
            var defaultOrganizer = organizers.FirstOrDefault()?.Id ?? "";
            var venues = new List<Venue>
            {
                new Venue
                {
                    Id = Guid.NewGuid(),
                    Name = "BKC Sarajevo",
                    Address = "Maršala Tita 56",
                    City = "Sarajevo",
                    Country = "Bosna i Hercegovina",
                    Capacity = 2000,
                    Latitude = 43.8563,
                    Longitude = 18.4131,
                    CreatedBy = defaultOrganizer,
                    CreatedAt = DateTime.UtcNow
                },
                new Venue
                {
                    Id = Guid.NewGuid(),
                    Name = "Dom Mladih",
                    Address = "Kulina Bana 6",
                    City = "Sarajevo",
                    Country = "Bosna i Hercegovina",
                    Capacity = 1500,
                    Latitude = 43.8580,
                    Longitude = 18.4247,
                    CreatedBy = defaultOrganizer,
                    CreatedAt = DateTime.UtcNow
                },
                new Venue
                {
                    Id = Guid.NewGuid(),
                    Name = "Skenderija",
                    Address = "Terezije bb",
                    City = "Sarajevo",
                    Country = "Bosna i Hercegovina",
                    Capacity = 3000,
                    Latitude = 43.8519,
                    Longitude = 18.4176,
                    CreatedBy = defaultOrganizer,
                    CreatedAt = DateTime.UtcNow
                },
                new Venue
                {
                    Id = Guid.NewGuid(),
                    Name = "Arena Banja Luka",
                    Address = "Bulevar vojvode Petra Bojovića 1A",
                    City = "Banja Luka",
                    Country = "Bosna i Hercegovina",
                    Capacity = 5000,
                    Latitude = 44.7722,
                    Longitude = 17.1910,
                    CreatedBy = defaultOrganizer,
                    CreatedAt = DateTime.UtcNow
                },
                new Venue
                {
                    Id = Guid.NewGuid(),
                    Name = "Centar za Kulturu",
                    Address = "Trg hrvatskih velikana bb",
                    City = "Mostar",
                    Country = "Bosna i Hercegovina",
                    Capacity = 800,
                    Latitude = 43.3438,
                    Longitude = 17.8078,
                    CreatedBy = defaultOrganizer,
                    CreatedAt = DateTime.UtcNow
                },
                new Venue
                {
                    Id = Guid.NewGuid(),
                    Name = "Dom Armije",
                    Address = "Trg Slobode 1",
                    City = "Tuzla",
                    Country = "Bosna i Hercegovina",
                    Capacity = 1200,
                    Latitude = 44.5384,
                    Longitude = 18.6763,
                    CreatedBy = defaultOrganizer,
                    CreatedAt = DateTime.UtcNow
                },
                new Venue
                {
                    Id = Guid.NewGuid(),
                    Name = "Arena Zenica",
                    Address = "Stadion Bilino polje",
                    City = "Zenica",
                    Country = "Bosna i Hercegovina",
                    Capacity = 4000,
                    Latitude = 44.2017,
                    Longitude = 17.9077,
                    CreatedBy = defaultOrganizer,
                    CreatedAt = DateTime.UtcNow
                },
                new Venue
                {
                    Id = Guid.NewGuid(),
                    Name = "Hotel Neum",
                    Address = "Obala kralja Tvrtka bb",
                    City = "Neum",
                    Country = "Bosna i Hercegovina",
                    Capacity = 500,
                    Latitude = 42.9225,
                    Longitude = 17.6159,
                    CreatedBy = defaultOrganizer,
                    CreatedAt = DateTime.UtcNow
                }
            };

            context.Venues.AddRange(venues);
            await context.SaveChangesAsync();
            return venues;
        }

        private static async Task<List<ApplicationUser>> CreateTestUsersAsync(
            UserManager<ApplicationUser> userManager,
            RoleManager<ApplicationRole> roleManager,
            ILogger<SeedDataService> logger)
        {
            var users = new List<ApplicationUser>();
            var password = "Password123!";

            // Create test users with adil@edu.fit.ba email pattern
            // User (regular user)
            var existingTestUser = await userManager.FindByEmailAsync("adil@edu.fit.ba");
            if (existingTestUser == null)
            {
                var testUser = new ApplicationUser
                {
                    UserName = "adil@edu.fit.ba",
                    Email = "adil@edu.fit.ba",
                    EmailConfirmed = true,
                    FirstName = "Adil",
                    LastName = "Joldic",
                    CreatedAt = DateTime.UtcNow.AddDays(-5)
                };
                var userResult = await userManager.CreateAsync(testUser, password);
                if (userResult.Succeeded)
                {
                    await userManager.AddToRoleAsync(testUser, "User");
                    users.Add(testUser);
                    logger.LogInformation($"Kreiran test korisnik: {testUser.Email}");
                }
                else
                {
                    logger.LogWarning($"Nije moguće kreirati test korisnika {testUser.Email}: {string.Join(", ", userResult.Errors.Select(e => e.Description))}");
                }
            }
            else
            {
                users.Add(existingTestUser);
                logger.LogInformation($"Test korisnik {existingTestUser.Email} već postoji.");
            }

            // Organizer
            var existingOrganizer = await userManager.FindByEmailAsync("adil+1@edu.fit.ba");
            if (existingOrganizer == null)
            {
                var testOrganizer = new ApplicationUser
                {
                    UserName = "adil+1@edu.fit.ba",
                    Email = "adil+1@edu.fit.ba",
                    EmailConfirmed = true,
                    FirstName = "Adil",
                    LastName = "Joldic",
                    CreatedAt = DateTime.UtcNow.AddDays(-4),
                    IsOrganizerVerified = true
                };
                var organizerResult = await userManager.CreateAsync(testOrganizer, password);
                if (organizerResult.Succeeded)
                {
                    await userManager.AddToRoleAsync(testOrganizer, "Organizer");
                    users.Add(testOrganizer);
                    logger.LogInformation($"Kreiran test organizator: {testOrganizer.Email}");
                }
                else
                {
                    logger.LogWarning($"Nije moguće kreirati test organizatora {testOrganizer.Email}: {string.Join(", ", organizerResult.Errors.Select(e => e.Description))}");
                }
            }
            else
            {
                users.Add(existingOrganizer);
                logger.LogInformation($"Test organizator {existingOrganizer.Email} već postoji.");
            }

            // Scanner
            var existingScanner = await userManager.FindByEmailAsync("adil+2@edu.fit.ba");
            if (existingScanner == null)
            {
                var testScanner = new ApplicationUser
                {
                    UserName = "adil+2@edu.fit.ba",
                    Email = "adil+2@edu.fit.ba",
                    EmailConfirmed = true,
                    FirstName = "Adil",
                    LastName = "Joldic",
                    CreatedAt = DateTime.UtcNow.AddDays(-3)
                };
                var scannerResult = await userManager.CreateAsync(testScanner, password);
                if (scannerResult.Succeeded)
                {
                    await userManager.AddToRoleAsync(testScanner, "Scanner");
                    users.Add(testScanner);
                    logger.LogInformation($"Kreiran test scanner: {testScanner.Email}");
                }
                else
                {
                    logger.LogWarning($"Nije moguće kreirati test scannera {testScanner.Email}: {string.Join(", ", scannerResult.Errors.Select(e => e.Description))}");
                }
            }
            else
            {
                users.Add(existingScanner);
                logger.LogInformation($"Test scanner {existingScanner.Email} već postoji.");
            }

            return users;
        }

        private static async Task<List<ApplicationUser>> CreateUsersAsync(
            UserManager<ApplicationUser> userManager,
            RoleManager<ApplicationRole> roleManager,
            ILogger<SeedDataService> logger)
        {
            var users = new List<ApplicationUser>();
            var password = "Password123!";

            // Original seed data
            for (int i = 1; i <= 4; i++)
            {
                var user = new ApplicationUser
                {
                    UserName = $"organizer{i}@karta.ba",
                    Email = $"organizer{i}@karta.ba",
                    EmailConfirmed = true,
                    FirstName = $"Organizator{i}",
                    LastName = "Test",
                    CreatedAt = DateTime.UtcNow.AddDays(-i * 10),
                    IsOrganizerVerified = i <= 2
                };
                var result = await userManager.CreateAsync(user, password);
                if (result.Succeeded)
                {
                    await userManager.AddToRoleAsync(user, "Organizer");
                    users.Add(user);
                    logger.LogInformation($"Kreiran organizator: {user.Email}");
                }
            }
            for (int i = 1; i <= 3; i++)
            {
                var user = new ApplicationUser
                {
                    UserName = $"scanner{i}@karta.ba",
                    Email = $"scanner{i}@karta.ba",
                    EmailConfirmed = true,
                    FirstName = $"Scanner{i}",
                    LastName = "Test",
                    CreatedAt = DateTime.UtcNow.AddDays(-i * 5)
                };
                var result = await userManager.CreateAsync(user, password);
                if (result.Succeeded)
                {
                    await userManager.AddToRoleAsync(user, "Scanner");
                    users.Add(user);
                    logger.LogInformation($"Kreiran scanner: {user.Email}");
                }
            }
            for (int i = 1; i <= 10; i++)
            {
                var user = new ApplicationUser
                {
                    UserName = $"user{i}@karta.ba",
                    Email = $"user{i}@karta.ba",
                    EmailConfirmed = true,
                    FirstName = $"User{i}",
                    LastName = "Test",
                    CreatedAt = DateTime.UtcNow.AddDays(-i * 3)
                };
                var result = await userManager.CreateAsync(user, password);
                if (result.Succeeded)
                {
                    await userManager.AddToRoleAsync(user, "User");
                    users.Add(user);
                    logger.LogInformation($"Kreiran korisnik: {user.Email}");
                }
            }
            return users;
        }

        private static async Task<List<Event>> CreateEventsAsync(
            ApplicationDbContext context,
            List<ApplicationUser> organizers,
            List<Category> categories,
            List<Venue> venues,
            ILogger<SeedDataService> logger)
        {
            var events = new List<Event>();
            var statuses = new[] { "Published", "Draft", "Archived", "Cancelled" };

            // Event data with category and venue mappings
            var eventData = new[]
            {
                // Music events (Category: Muzika)
                new { Title = "Rock Koncert 2024", CategoryIndex = 0, VenueIndex = 2, Description = "Najveći rock koncert godine! Nastupaju domaće i regionalne rock zvijezde." },
                new { Title = "Jazz Festival Sarajevo", CategoryIndex = 0, VenueIndex = 0, Description = "Tradicionalni jazz festival sa svjetskim izvođačima i lokalnim talentima." },
                new { Title = "Koncert Narodne Muzike", CategoryIndex = 0, VenueIndex = 3, Description = "Večer posvećena tradicionalnoj bosanskoj muzici s najboljim izvođačima." },
                new { Title = "Elektronska Muzika Party", CategoryIndex = 0, VenueIndex = 1, Description = "Noć elektronske muzike s vrhunskim DJ-evima iz regije." },
                new { Title = "Operski Gala Koncert", CategoryIndex = 0, VenueIndex = 0, Description = "Svečani operski koncert s najboljim glasovima BiH." },

                // Sports events (Category: Sport)
                new { Title = "Fudbalska Utakmica FK Sarajevo", CategoryIndex = 1, VenueIndex = 2, Description = "Derbi susret FK Sarajevo protiv glavnog rivala. Ne propustite!" },
                new { Title = "Basketball Turnir Gradski", CategoryIndex = 1, VenueIndex = 6, Description = "Gradski košarkaški turnir za amaterske ekipe." },
                new { Title = "Gaming Tournament ESL", CategoryIndex = 1, VenueIndex = 3, Description = "Najveći esport turnir u BiH. Counter-Strike, Dota 2 i League of Legends." },

                // Culture events (Category: Kultura)
                new { Title = "Kazališna Predstava - Derviš i Smrt", CategoryIndex = 2, VenueIndex = 0, Description = "Klasična predstava po djelu Meše Selimovića." },
                new { Title = "Film Festival Sarajevo", CategoryIndex = 2, VenueIndex = 1, Description = "Međunarodni filmski festival s premijerama i gostima." },
                new { Title = "Festival Folklora BiH", CategoryIndex = 2, VenueIndex = 4, Description = "Smotra folklornih ansambala iz cijele Bosne i Hercegovine." },
                new { Title = "Književni Večer", CategoryIndex = 2, VenueIndex = 5, Description = "Promocija knjiga i susret s poznatim piscima." },

                // Technology events (Category: Tehnologija)
                new { Title = "Tech Conference BiH 2024", CategoryIndex = 3, VenueIndex = 2, Description = "Godišnja tech konferencija s predavanjima o AI, blockchain i cloud tehnologijama." },
                new { Title = "AI Workshop za Početnike", CategoryIndex = 3, VenueIndex = 1, Description = "Praktična radionica o umjetnoj inteligenciji za sve nivoe znanja." },
                new { Title = "Startup Pitch Event", CategoryIndex = 3, VenueIndex = 0, Description = "Predstavljanje startup ideja pred investitorima i mentorima." },

                // Education events (Category: Edukacija)
                new { Title = "Marketing Masterclass", CategoryIndex = 4, VenueIndex = 5, Description = "Dvodnevna radionica digitalnog marketinga s praktičnim vježbama." },
                new { Title = "Wine & Dine Experience", CategoryIndex = 4, VenueIndex = 7, Description = "Edukativna degustacija vina s gastro uparivanjem." },

                // Entertainment events (Category: Zabava)
                new { Title = "Stand-up Comedy Night", CategoryIndex = 5, VenueIndex = 1, Description = "Večer smijeha s najboljim komičarima iz regije." },
                new { Title = "Kulinarski Festival", CategoryIndex = 5, VenueIndex = 7, Description = "Festival hrane s degustacijama, radionicama i natjecanjima." },
                new { Title = "New Year's Eve Celebration", CategoryIndex = 5, VenueIndex = 3, Description = "Najveća novogodišnja zabava u gradu! Muzika, vatromet i zabava do zore." }
            };

            for (int i = 0; i < eventData.Length; i++)
            {
                var data = eventData[i];
                var organizer = organizers[i % organizers.Count];
                var category = categories[data.CategoryIndex];
                var venue = venues[data.VenueIndex];
                var startsAt = DateTimeOffset.UtcNow.AddDays(15 + i * 5);
                var endsAt = startsAt.AddHours(3 + (i % 3));

                var eventEntity = new Event
                {
                    Id = Guid.NewGuid(),
                    Title = data.Title,
                    Slug = GenerateSlug(data.Title, i),
                    Description = data.Description,
                    Venue = venue.Name,
                    City = venue.City,
                    Country = "Bosna i Hercegovina",
                    StartsAt = startsAt,
                    EndsAt = endsAt,
                    Category = category.Name,
                    CategoryId = category.Id,
                    VenueId = venue.Id,
                    Tags = $"{category.Name}, {venue.City}, 2024",
                    Status = i < 15 ? "Published" : (i < 18 ? "Draft" : statuses[i % statuses.Length]),
                    CoverImageUrl = $"/images/event{(i % 5) + 1}.jpg",
                    CreatedAt = DateTime.UtcNow.AddDays(-(20 - i)),
                    CreatedBy = organizer.Id
                };
                events.Add(eventEntity);
            }

            context.Events.AddRange(events);
            await context.SaveChangesAsync();
            return events;
        }

        private static string GenerateSlug(string title, int index)
        {
            var slug = title.ToLower()
                .Replace(" ", "-")
                .Replace("č", "c")
                .Replace("ć", "c")
                .Replace("đ", "d")
                .Replace("š", "s")
                .Replace("ž", "z")
                .Replace("'", "");
            return $"{slug}-{index + 1}";
        }

        private static async Task<List<Order>> CreateAdminUserOrdersAsync(
            ApplicationDbContext context,
            ApplicationUser? adminUser,
            List<Event> events,
            List<PriceTier> priceTiers,
            ILogger<SeedDataService> logger)
        {
            var orders = new List<Order>();
            if (adminUser == null)
            {
                logger.LogWarning("Admin user not found, skipping admin orders creation.");
                return orders;
            }

            // Create 3 orders for admin user with paid status
            var publishedEvents = events.Where(e => e.Status == "Published").Take(6).ToList();

            for (int i = 0; i < 3; i++)
            {
                var order = new Order
                {
                    Id = Guid.NewGuid(),
                    UserId = adminUser.Id,
                    TotalAmount = 0m,
                    Currency = "BAM",
                    Status = "Paid",
                    StripePaymentIntentId = $"pi_admin_{i + 1}",
                    CreatedAt = DateTime.UtcNow.AddDays(-(30 - i * 10))
                };

                // Add 1-2 events per order
                var eventCount = i == 0 ? 2 : (i == 1 ? 2 : 1);
                for (int j = 0; j < eventCount && (i * 2 + j) < publishedEvents.Count; j++)
                {
                    var eventEntity = publishedEvents[i * 2 + j];
                    var eventPriceTiers = priceTiers.Where(pt => pt.EventId == eventEntity.Id).ToList();
                    if (!eventPriceTiers.Any()) continue;

                    var priceTier = eventPriceTiers.First();
                    var qty = 2;

                    var orderItem = new OrderItem
                    {
                        Id = Guid.NewGuid(),
                        OrderId = order.Id,
                        EventId = eventEntity.Id,
                        PriceTierId = priceTier.Id,
                        Qty = qty,
                        UnitPrice = priceTier.Price
                    };

                    order.TotalAmount += priceTier.Price * qty;
                    priceTier.Sold += qty;

                    context.OrderItems.Add(orderItem);

                    // Create tickets for admin orders (some used, some valid)
                    for (int k = 0; k < qty; k++)
                    {
                        var isUsed = i == 0; // First order has used tickets
                        var ticket = new Ticket
                        {
                            Id = Guid.NewGuid(),
                            OrderItemId = orderItem.Id,
                            TicketCode = Guid.NewGuid().ToString("N")[..32],
                            QRNonce = Guid.NewGuid().ToString("N")[..32],
                            Status = isUsed ? "Used" : "Valid",
                            IssuedAt = order.CreatedAt,
                            UsedAt = isUsed ? order.CreatedAt.AddDays(1) : null
                        };
                        context.Tickets.Add(ticket);
                    }
                }

                orders.Add(order);
            }

            context.Orders.AddRange(orders);
            await context.SaveChangesAsync();
            return orders;
        }

        private static async Task<List<Review>> CreateReviewsAsync(
            ApplicationDbContext context,
            List<ApplicationUser> users,
            List<Event> events,
            ApplicationUser? adminUser,
            ILogger<SeedDataService> logger)
        {
            var reviews = new List<Review>();
            var publishedEvents = events.Where(e => e.Status == "Published").ToList();
            var regularUsers = users.Where(u => u.Email != null && !u.Email.Contains("scanner") && !u.Email.Contains("organizer")).ToList();

            // Review templates
            var reviewTemplates = new[]
            {
                new { Rating = 5, Title = "Odlično!", Content = "Fantastičan događaj, sve je bilo na najvišem nivou. Preporučujem svima!" },
                new { Rating = 5, Title = "Nezaboravno iskustvo", Content = "Organizacija na najvišem nivou, definitivno dolazim opet." },
                new { Rating = 4, Title = "Vrlo dobro", Content = "Uglavnom sve u redu, nekoliko sitnih propusta ali generalno odlično." },
                new { Rating = 5, Title = "Vrhunski!", Content = "Najbolji događaj na kojem sam bio/la ove godine. Bravo za organizatore!" },
                new { Rating = 4, Title = "Preporučujem", Content = "Dobra atmosfera, kvalitetna organizacija. Vrijedilo je svake pare." },
                new { Rating = 5, Title = "Savršeno!", Content = "Sve je bilo savršeno organizirano. Hvala organizatorima!" },
                new { Rating = 3, Title = "Solidno", Content = "Događaj je bio OK, ali ima prostora za poboljšanje." },
                new { Rating = 5, Title = "Spektakularno!", Content = "Prešli su sva očekivanja! Jedva čekam sljedeći put." },
                new { Rating = 4, Title = "Dobra zabava", Content = "Proveli smo se odlično, atmosfera je bila super." },
                new { Rating = 5, Title = "Top!", Content = "Sve pohvale za organizaciju i izvođače. 10/10!" }
            };

            // Create admin user review for Jazz Festival (index 1)
            if (adminUser != null && publishedEvents.Count > 1)
            {
                var jazzFestival = publishedEvents.FirstOrDefault(e => e.Title.Contains("Jazz"));
                if (jazzFestival != null)
                {
                    var adminReview = new Review
                    {
                        Id = Guid.NewGuid(),
                        UserId = adminUser.Id,
                        EventId = jazzFestival.Id,
                        Rating = 5,
                        Title = "Fantastičan festival!",
                        Content = "Odlična atmosfera, vrhunski izvođači i savršena organizacija. Preporučujem svima!",
                        CreatedAt = DateTime.UtcNow.AddDays(-5)
                    };
                    reviews.Add(adminReview);
                }
            }

            // Create reviews from regular users (10-15 reviews)
            var random = new Random(42); // Fixed seed for consistency
            for (int i = 0; i < 12 && i < publishedEvents.Count && regularUsers.Count > 0; i++)
            {
                var eventEntity = publishedEvents[i % publishedEvents.Count];
                var user = regularUsers[i % regularUsers.Count];
                var template = reviewTemplates[i % reviewTemplates.Length];

                // Skip if this user already reviewed this event
                if (reviews.Any(r => r.UserId == user.Id && r.EventId == eventEntity.Id))
                    continue;

                var review = new Review
                {
                    Id = Guid.NewGuid(),
                    UserId = user.Id,
                    EventId = eventEntity.Id,
                    Rating = template.Rating,
                    Title = template.Title,
                    Content = template.Content,
                    CreatedAt = DateTime.UtcNow.AddDays(-(15 - i))
                };
                reviews.Add(review);
            }

            context.Reviews.AddRange(reviews);
            await context.SaveChangesAsync();
            return reviews;
        }

        private static async Task<List<UserFavorite>> CreateUserFavoritesAsync(
            ApplicationDbContext context,
            List<ApplicationUser> users,
            List<Event> events,
            ApplicationUser? adminUser,
            ILogger<SeedDataService> logger)
        {
            var favorites = new List<UserFavorite>();
            var publishedEvents = events.Where(e => e.Status == "Published").ToList();
            var usedCombinations = new HashSet<(string UserId, Guid EventId)>();

            // Admin user favorites (3-4 events)
            if (adminUser != null)
            {
                for (int i = 0; i < 4 && i < publishedEvents.Count; i++)
                {
                    var combination = (adminUser.Id, publishedEvents[i].Id);
                    if (!usedCombinations.Contains(combination))
                    {
                        var favorite = new UserFavorite
                        {
                            Id = Guid.NewGuid(),
                            UserId = adminUser.Id,
                            EventId = publishedEvents[i].Id,
                            CreatedAt = DateTime.UtcNow.AddDays(-(10 - i))
                        };
                        favorites.Add(favorite);
                        usedCombinations.Add(combination);
                    }
                }
            }

            // Other users favorites (distribute 15-20 favorites)
            var regularUsers = users.Where(u => u.Email != null && u.Email.Contains("user")).ToList();
            var random = new Random(123); // Fixed seed for consistency

            for (int i = 0; i < 16 && regularUsers.Count > 0; i++)
            {
                var user = regularUsers[i % regularUsers.Count];
                var eventEntity = publishedEvents[random.Next(publishedEvents.Count)];
                var combination = (user.Id, eventEntity.Id);

                if (!usedCombinations.Contains(combination))
                {
                    var favorite = new UserFavorite
                    {
                        Id = Guid.NewGuid(),
                        UserId = user.Id,
                        EventId = eventEntity.Id,
                        CreatedAt = DateTime.UtcNow.AddDays(-(20 - i))
                    };
                    favorites.Add(favorite);
                    usedCombinations.Add(combination);
                }
            }

            context.UserFavorites.AddRange(favorites);
            await context.SaveChangesAsync();
            return favorites;
        }

        private static async Task<List<PriceTier>> CreatePriceTiersAsync(
            ApplicationDbContext context,
            List<Event> events,
            ILogger<SeedDataService> logger)
        {
            var priceTiers = new List<PriceTier>();
            var tierNames = new[] { "Regular", "VIP", "Premium", "Early Bird" };
            foreach (var eventEntity in events)
            {
                var tierCount = 2 + (eventEntity.Id.GetHashCode() % 2);
                for (int i = 0; i < tierCount; i++)
                {
                    var capacity = 100 + (i * 50);
                    var price = 20.00m + (i * 15.00m);
                    var priceTier = new PriceTier
                    {
                        Id = Guid.NewGuid(),
                        EventId = eventEntity.Id,
                        Name = tierNames[i % tierNames.Length],
                        Price = price,
                        Currency = "BAM",
                        Capacity = capacity,
                        Sold = 0
                    };
                    priceTiers.Add(priceTier);
                }
            }
            context.PriceTiers.AddRange(priceTiers);
            await context.SaveChangesAsync();
            return priceTiers;
        }

        private static async Task<List<Order>> CreateOrdersAsync(
            ApplicationDbContext context,
            List<ApplicationUser> users,
            List<Event> events,
            List<PriceTier> priceTiers,
            ILogger<SeedDataService> logger)
        {
            var orders = new List<Order>();
            var statuses = new[] { "Paid", "Pending", "Failed", "Expired", "Cancelled" };
            for (int i = 0; i < 10; i++)
            {
                var user = users[i % users.Count];
                var status = i < 7 ? "Paid" : statuses[i % statuses.Length];
                var totalAmount = 0m;
                var order = new Order
                {
                    Id = Guid.NewGuid(),
                    UserId = user.Id,
                    TotalAmount = totalAmount,
                    Currency = "BAM",
                    Status = status,
                    StripePaymentIntentId = status == "Paid" ? $"pi_test_{i + 1}" : null,
                    CreatedAt = DateTime.UtcNow.AddDays(-(10 - i))
                };
                orders.Add(order);
            }
            context.Orders.AddRange(orders);
            await context.SaveChangesAsync();
            return orders;
        }

        private static async Task<List<OrderItem>> CreateOrderItemsAsync(
            ApplicationDbContext context,
            List<Order> orders,
            List<Event> events,
            List<PriceTier> priceTiers,
            ILogger<SeedDataService> logger)
        {
            var orderItems = new List<OrderItem>();
            var random = new Random();
            foreach (var order in orders)
            {
                var itemCount = 1 + (order.Id.GetHashCode() % 3);
                for (int i = 0; i < itemCount; i++)
                {
                    var eventEntity = events[random.Next(events.Count)];
                    var eventPriceTiers = priceTiers.Where(pt => pt.EventId == eventEntity.Id).ToList();
                    if (!eventPriceTiers.Any()) continue;
                    var priceTier = eventPriceTiers[random.Next(eventPriceTiers.Count)];
                    var qty = 1 + (random.Next(3));
                    var orderItem = new OrderItem
                    {
                        Id = Guid.NewGuid(),
                        OrderId = order.Id,
                        EventId = eventEntity.Id,
                        PriceTierId = priceTier.Id,
                        Qty = qty,
                        UnitPrice = priceTier.Price
                    };
                    orderItems.Add(orderItem);
                    order.TotalAmount += priceTier.Price * qty;
                    priceTier.Sold += qty;
                }
            }
            context.OrderItems.AddRange(orderItems);
            context.Orders.UpdateRange(orders);
            context.PriceTiers.UpdateRange(priceTiers);
            await context.SaveChangesAsync();
            return orderItems;
        }

        private static async Task<List<Ticket>> CreateTicketsAsync(
            ApplicationDbContext context,
            List<OrderItem> orderItems,
            ILogger<SeedDataService> logger)
        {
            var tickets = new List<Ticket>();
            foreach (var orderItem in orderItems)
            {
                for (int i = 0; i < orderItem.Qty; i++)
                {
                    string status;
                    DateTime? usedAt = null;
                    if (orderItem.Order.Status == "Paid")
                    {
                        if (i % 15 == 0)
                            status = "Refunded";
                        else if (i % 10 == 0)
                        {
                            status = "Used";
                            usedAt = orderItem.Order.CreatedAt.AddDays(1);
                        }
                        else
                            status = "Valid";
                    }
                    else if (orderItem.Order.Status == "Cancelled")
                    {
                        status = "Refunded";
                    }
                    else
                    {
                        status = "Valid";
                    }
                    var ticket = new Ticket
                    {
                        Id = Guid.NewGuid(),
                        OrderItemId = orderItem.Id,
                        TicketCode = Guid.NewGuid().ToString("N")[..32],
                        QRNonce = Guid.NewGuid().ToString("N")[..32],
                        Status = status,
                        IssuedAt = orderItem.Order.CreatedAt,
                        UsedAt = usedAt
                    };
                    tickets.Add(ticket);
                }
            }
            context.Tickets.AddRange(tickets);
            await context.SaveChangesAsync();
            return tickets;
        }

        private static async Task<List<ScanLog>> CreateScanLogsAsync(
            ApplicationDbContext context,
            List<Ticket> tickets,
            List<OrderItem> orderItems,
            ILogger<SeedDataService> logger)
        {
            var scanLogs = new List<ScanLog>();
            var ticketsToScan = tickets.Where(t => t.Status == "Used" || t.Status == "Valid").Take(25).ToList();
            var gates = new[] { "A1", "A2", "B1", "B2", "C1", "C2" };
            var random = new Random();
            var orderItemLookup = orderItems.ToDictionary(oi => oi.Id, oi => oi.Order.Status);
            foreach (var ticket in ticketsToScan)
            {
                string result;
                if (ticket.Status == "Used")
                {
                    result = random.Next(10) < 7 ? "Valid" : "AlreadyUsed";
                }
                else if (ticket.Status == "Valid")
                {
                    if (orderItemLookup.TryGetValue(ticket.OrderItemId, out var orderStatus) && orderStatus == "Paid")
                    {
                        result = "Valid";
                    }
                    else
                    {
                        result = "Unpaid";
                    }
                }
                else
                {
                    result = "Valid";
                }
                var scanLog = new ScanLog
                {
                    Id = Guid.NewGuid(),
                    TicketId = ticket.Id,
                    GateId = gates[random.Next(gates.Length)],
                    ScannedAt = ticket.UsedAt ?? ticket.IssuedAt.AddDays(1),
                    Result = result
                };
                scanLogs.Add(scanLog);
            }
            context.ScanLogs.AddRange(scanLogs);
            await context.SaveChangesAsync();
            return scanLogs;
        }

        private static async Task<List<EventScannerAssignment>> CreateEventScannerAssignmentsAsync(
            ApplicationDbContext context,
            List<Event> events,
            List<ApplicationUser> scanners,
            ILogger<SeedDataService> logger)
        {
            var assignments = new List<EventScannerAssignment>();
            var usedCombinations = new HashSet<(Guid EventId, string ScannerUserId)>();
            for (int i = 0; i < events.Count && assignments.Count < events.Count; i++)
            {
                var eventEntity = events[i];
                var scanner = scanners[i % scanners.Count];
                var combination = (eventEntity.Id, scanner.Id);
                if (!usedCombinations.Contains(combination))
                {
                    var assignment = new EventScannerAssignment
                    {
                        Id = Guid.NewGuid(),
                        EventId = eventEntity.Id,
                        ScannerUserId = scanner.Id,
                        AssignedAt = DateTime.UtcNow.AddDays(-(10 - i))
                    };
                    assignments.Add(assignment);
                    usedCombinations.Add(combination);
                }
            }
            context.EventScannerAssignments.AddRange(assignments);
            await context.SaveChangesAsync();
            return assignments;
        }
    }
}
