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
                
                // Uvijek kreiraj testne korisnike
                logger.LogInformation("Kreiranje testnih korisnika...");
                var testUsers = await CreateTestUsersAsync(userManager, roleManager, logger);
                logger.LogInformation($"Kreirano {testUsers.Count} testnih korisnika.");
                
                if (await context.Events.AnyAsync())
                {
                    logger.LogWarning("Baza već sadrži podatke. Preskačem seed-ovanje ostalih podataka.");
                    return;
                }
                logger.LogInformation("Kreiranje korisnika...");
                var users = await CreateUsersAsync(userManager, roleManager, logger);
                logger.LogInformation($"Kreirano {users.Count} korisnika.");
                logger.LogInformation("Kreiranje događaja...");
                var organizers = users.Where(u => userManager.IsInRoleAsync(u, "Organizer").Result).ToList();
                var events = await CreateEventsAsync(context, organizers, logger);
                logger.LogInformation($"Kreirano {events.Count} događaja.");
                logger.LogInformation("Kreiranje PriceTier-ova...");
                var priceTiers = await CreatePriceTiersAsync(context, events, logger);
                logger.LogInformation($"Kreirano {priceTiers.Count} PriceTier-ova.");
                logger.LogInformation("Kreiranje narudžbi...");
                var regularUsers = users.Where(u => userManager.IsInRoleAsync(u, "User").Result).ToList();
                var orders = await CreateOrdersAsync(context, regularUsers, events, priceTiers, logger);
                logger.LogInformation($"Kreirano {orders.Count} narudžbi.");
                logger.LogInformation("Kreiranje OrderItem-ova...");
                var orderItems = await CreateOrderItemsAsync(context, orders, events, priceTiers, logger);
                logger.LogInformation($"Kreirano {orderItems.Count} OrderItem-ova.");
                logger.LogInformation("Kreiranje Ticket-ova...");
                var tickets = await CreateTicketsAsync(context, orderItems, logger);
                logger.LogInformation($"Kreirano {tickets.Count} Ticket-ova.");
                logger.LogInformation("Kreiranje ScanLog-ova...");
                var scanLogs = await CreateScanLogsAsync(context, tickets, orderItems, logger);
                logger.LogInformation($"Kreirano {scanLogs.Count} ScanLog-ova.");
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
            ILogger<SeedDataService> logger)
        {
            var events = new List<Event>();
            var categories = new[] { "Muzika", "Sport", "Kultura", "Tehnologija", "Edukacija", "Zabava", "Biznis", "Umjetnost" };
            var cities = new[] { "Sarajevo", "Banja Luka", "Mostar", "Tuzla", "Zenica", "Bihać", "Brčko", "Trebinje" };
            var statuses = new[] { "Published", "Draft", "Archived", "Cancelled" };
            var eventTitles = new[]
            {
                "Rock Koncert 2024", "Fudbalska Utakmica", "Jazz Festival", "Tech Conference",
                "Kazališna Predstava", "Koncert Narodne Muzike", "Basketball Turnir", "Film Festival",
                "Kulinarski Festival", "Književni Večer"
            };
            for (int i = 0; i < 10; i++)
            {
                var organizer = organizers[i % organizers.Count];
                var startsAt = DateTimeOffset.UtcNow.AddDays(30 + i * 7);
                var endsAt = startsAt.AddHours(3);
                var eventEntity = new Event
                {
                    Id = Guid.NewGuid(),
                    Title = eventTitles[i],
                    Slug = GenerateSlug(eventTitles[i], i),
                    Description = $"Opis događaja {i + 1}. Ovo je detaljan opis događaja koji se održava u {cities[i % cities.Length]}.",
                    Venue = $"Dvorana {i + 1}",
                    City = cities[i % cities.Length],
                    Country = "Bosna i Hercegovina",
                    StartsAt = startsAt,
                    EndsAt = endsAt,
                    Category = categories[i % categories.Length],
                    Tags = $"{categories[i % categories.Length]}, {cities[i % cities.Length]}",
                    Status = i < 6 ? "Published" : (i < 8 ? "Draft" : statuses[i % statuses.Length]),
                    CoverImageUrl = $"/images/event{(i % 2) + 1}.jpg",
                    CreatedAt = DateTime.UtcNow.AddDays(-(10 - i)),
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
                .Replace("ž", "z");
            return $"{slug}-{index + 1}";
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